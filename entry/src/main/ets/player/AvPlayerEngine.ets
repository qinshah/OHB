import { media } from '@kit.MediaKit';
import { BusinessError, deviceInfo } from '@kit.BasicServicesKit';
import { IPlayerEngine } from './IPlayerEngine';
import { PlaybackState } from './PlayerTypes';
import { Logger } from '../common/utils/Logger';

/**
 * 默认内核：基于 @ohos.multimedia.avplayer（AP-3）
 * 通过状态机驱动：idle → initialized → prepared → playing/paused → completed
 */
export class AvPlayerEngine implements IPlayerEngine {
  private player: media.AVPlayer | null = null;
  private state: PlaybackState = PlaybackState.Idle;
  private surfaceId: string = '';
  private pendingUrl: string = '';
  private pendingHeaders: Record<string, string> = {};
  private positionMs: number = 0;
  private durationMs: number = 0;
  private bufferedMs: number = 0;
  private volume: number = 1.0;
  private speed: number = 1.0;

  private stateCb: ((state: PlaybackState) => void) | null = null;
  private progressCb: ((positionMs: number, durationMs: number, bufferedMs: number) => void) | null = null;
  private errorCb: ((code: number, message: string) => void) | null = null;
  private completionCb: (() => void) | null = null;
  private videoSizeCb: ((width: number, height: number) => void) | null = null;

  private setState(s: PlaybackState): void {
    this.state = s;
    if (this.stateCb !== null) {
      this.stateCb(s);
    }
  }

  private async ensurePlayer(): Promise<media.AVPlayer> {
    if (this.player !== null) {
      return this.player;
    }
    const p = await media.createAVPlayer();
    this.bindEvents(p);
    this.player = p;
    return p;
  }

  private bindEvents(p: media.AVPlayer): void {
    p.on('stateChange', (st: media.AVPlayerState) => {
      Logger.info('AvEngine', `stateChange -> ${st}`);
      switch (st) {
        case 'initialized':
          if (this.surfaceId.length > 0) {
            p.surfaceId = this.surfaceId;
          }
          // 在 prepare 前设置缩放类型，确保首帧即按正确比例渲染
          p.videoScaleType = media.VideoScaleType.VIDEO_SCALE_TYPE_FIT;
          p.prepare();
          break;
        case 'prepared':
          this.durationMs = p.duration > 0 ? p.duration : this.durationMs;
          // 显式设置视频缩放类型，确保 x86 设备渲染管线正确输出画面
          p.videoScaleType = media.VideoScaleType.VIDEO_SCALE_TYPE_FIT;
          Logger.info('AvEngine', `prepared: ${p.width}x${p.height}, dur=${this.durationMs}ms`);
          // 上报视频尺寸，UI 层按宽高比渲染、决定全屏方向
          this.notifyVideoSize(p.width, p.height);
          this.setState(PlaybackState.Prepared);
          // 恢复应用音量与倍速设置
          p.setVolume(this.volume);
          p.setSpeed(AvPlayerEngine.toAvSpeed(this.speed));
          break;
        case 'playing':
          this.setState(PlaybackState.Playing);
          break;
        case 'paused':
          this.setState(PlaybackState.Paused);
          break;
        case 'completed':
          this.setState(PlaybackState.Completed);
          if (this.completionCb !== null) {
            this.completionCb();
          }
          break;
        case 'stopped':
          this.setState(PlaybackState.Stopped);
          break;
        case 'released':
          this.setState(PlaybackState.Released);
          break;
        case 'error':
          this.setState(PlaybackState.Error);
          break;
        default:
          break;
      }
    });

    p.on('error', (err: BusinessError) => {
      Logger.error('AvEngine', `error ${err.code}: ${err.message}`);
      this.setState(PlaybackState.Error);
      if (this.errorCb !== null) {
        this.errorCb(err.code, err.message);
      }
    });

    p.on('timeUpdate', (time: number) => {
      this.positionMs = time;
      if (this.durationMs <= 0 && p.duration > 0) {
        this.durationMs = p.duration;
      }
      if (this.progressCb !== null) {
        this.progressCb(this.positionMs, this.durationMs, this.bufferedMs);
      }
    });

    p.on('durationUpdate', (duration: number) => {
      this.durationMs = duration;
    });

    p.on('bufferingUpdate', (infoType: media.BufferingInfoType, value: number) => {
      if (infoType === media.BufferingInfoType.BUFFERING_PERCENT) {
        this.bufferedMs = this.durationMs > 0 ? Math.floor(this.durationMs * value / 100) : 0;
      }
    });

    p.on('seekDone', (time: number) => {
      this.positionMs = time;
      if (this.progressCb !== null) {
        this.progressCb(this.positionMs, this.durationMs, this.bufferedMs);
      }
    });

    // 视频尺寸变化（清晰度切换 / 首帧解码完成）
    p.on('videoSizeChange', (width: number, height: number) => {
      Logger.info('AvEngine', `videoSizeChange -> ${width}x${height}`);
      this.notifyVideoSize(width, height);
    });
  }

  private notifyVideoSize(width: number, height: number): void {
    if (width > 0 && height > 0 && this.videoSizeCb !== null) {
      this.videoSizeCb(width, height);
    }
  }

  async setSource(url: string, headers: Record<string, string>): Promise<void> {
    this.pendingUrl = url;
    this.pendingHeaders = headers;
    this.setState(PlaybackState.Preparing);
    const p = await this.ensurePlayer();
    if (this.state === PlaybackState.Released) {
      return;
    }
    const strategy: media.PlaybackStrategy = AvPlayerEngine.buildStrategy();
    const hasHeaders = Object.keys(headers).length > 0;
    const src = hasHeaders
      ? media.createMediaSourceWithUrl(url, headers)
      : media.createMediaSourceWithUrl(url);
    p.setMediaSource(src, strategy);
  }

  /** 根据设备架构构建播放策略；x86 设备解码能力弱，需针对性优化 */
  private static buildStrategy(): media.PlaybackStrategy {
    if (AvPlayerEngine.isX86Device()) {
      // x86：减小缓冲总量降低内存压力，提高起播水位线吸收解码抖动，
      // 关闭首帧渲染避免 prepare 阶段因软解卡顿
      return {
        preferredBufferDuration: 15,
        preferredBufferDurationForPlaying: 0.5,
        showFirstFrameOnPrepare: false
      };
    }
    return {
      preferredBufferDuration: 20,
      preferredBufferDurationForPlaying: 0.3,
      showFirstFrameOnPrepare: true
    };
  }

  private static isX86Device(): boolean {
    // HarmonyOS 设备通常为 ARM 架构，x86 设备主要是模拟器
    // 可以通过 deviceInfo.hardwareModel 或其他方式判断
    try {
      const model = deviceInfo.hardwareModel;
      // 检查是否为已知的 x86 设备型号（主要是模拟器）
      return model.includes('x86') || model.includes('emulator');
    } catch (e) {
      return false;
    }
  }

  setSurface(surfaceId: string): void {
    this.surfaceId = surfaceId;
    // surface 晚于 initialized 到达时补绑
    if (this.player !== null && surfaceId.length > 0) {
      try {
        this.player.surfaceId = surfaceId;
      } catch (e) {
        Logger.error('AvEngine', `late bind surface fail: ${JSON.stringify(e)}`);
      }
    }
  }

  /**
   * 重建播放器并绑定新 surface（全屏/退出全屏切换）。
   * 释放旧播放器（解除对旧 surface 的渲染），用最近一次源重建全新实例，
   * 状态机走 initialized → prepared 时自动把 surfaceId 绑定到新实例。
   */
  async rebindSurface(surfaceId: string): Promise<void> {
    this.surfaceId = surfaceId;
    const url = this.pendingUrl;
    const headers = this.pendingHeaders;
    if (this.player === null || url.length === 0) {
      // 尚无播放器/源：仅记录 surfaceId，setSource 时自动绑定
      return;
    }
    await this.release();
    await this.setSource(url, headers);
  }

  async play(): Promise<void> {
    if (this.player === null) {
      return;
    }
    try {
      await this.player.play();
    } catch (e) {
      Logger.error('AvEngine', `play fail: ${JSON.stringify(e)}`);
    }
  }

  async pause(): Promise<void> {
    if (this.player === null) {
      return;
    }
    try {
      await this.player.pause();
    } catch (e) {
      Logger.error('AvEngine', `pause fail: ${JSON.stringify(e)}`);
    }
  }

  async seekTo(positionMs: number): Promise<void> {
    if (this.player === null) {
      return;
    }
    try {
      await this.player.seek(positionMs);
    } catch (e) {
      Logger.error('AvEngine', `seek fail: ${JSON.stringify(e)}`);
    }
  }

  async setVolume(volume: number): Promise<void> {
    this.volume = Math.max(0, Math.min(1, volume));
    if (this.player !== null) {
      try {
        await this.player.setVolume(this.volume);
      } catch (e) {
        Logger.error('AvEngine', `setVolume fail: ${JSON.stringify(e)}`);
      }
    }
  }

  async setSpeed(speed: number): Promise<void> {
    this.speed = speed;
    if (this.player !== null) {
      try {
        this.player.setSpeed(AvPlayerEngine.toAvSpeed(speed));
      } catch (e) {
        Logger.error('AvEngine', `setSpeed fail: ${JSON.stringify(e)}`);
      }
    }
  }

  /** AVPlayer 仅支持离散倍速档位，映射到最近档位 */
  private static toAvSpeed(speed: number): media.PlaybackSpeed {
    if (speed <= 0.75) {
      return media.PlaybackSpeed.SPEED_FORWARD_0_75_X;
    }
    if (speed >= 2.0) {
      return media.PlaybackSpeed.SPEED_FORWARD_2_00_X;
    }
    if (speed >= 1.5) {
      return media.PlaybackSpeed.SPEED_FORWARD_1_50_X;
    }
    if (speed >= 1.25) {
      return media.PlaybackSpeed.SPEED_FORWARD_1_25_X;
    }
    return media.PlaybackSpeed.SPEED_FORWARD_1_00_X;
  }

  async release(): Promise<void> {
    if (this.player !== null) {
      try {
        await this.player.release();
      } catch (e) {
        Logger.error('AvEngine', `release fail: ${JSON.stringify(e)}`);
      }
      this.player = null;
    }
    this.setState(PlaybackState.Released);
  }

  getState(): PlaybackState {
    return this.state;
  }

  getPosition(): number {
    // 优先读取内核实时位置（timeUpdate 事件之外的兜底），失败回退缓存值
    if (this.player !== null) {
      try {
        return this.player.currentTime;
      } catch (e) {
        Logger.error('AvEngine', `getPosition fail: ${JSON.stringify(e)}`);
      }
    }
    return this.positionMs;
  }

  getDuration(): number {
    return this.durationMs;
  }

  onStateChange(cb: (state: PlaybackState) => void): void {
    this.stateCb = cb;
  }

  onProgress(cb: (positionMs: number, durationMs: number, bufferedMs: number) => void): void {
    this.progressCb = cb;
  }

  onError(cb: (code: number, message: string) => void): void {
    this.errorCb = cb;
  }

  onCompletion(cb: () => void): void {
    this.completionCb = cb;
  }

  onVideoSizeChange(cb: (width: number, height: number) => void): void {
    this.videoSizeCb = cb;
  }
}
