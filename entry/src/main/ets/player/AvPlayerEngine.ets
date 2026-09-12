import { media } from '@kit.MediaKit';
import { BusinessError, deviceInfo } from '@kit.BasicServicesKit';
import { IPlayerEngine } from './IPlayerEngine';
import { PlaybackState, PlaySource } from './PlayerTypes';
import { hilog } from '@kit.PerformanceAnalysisKit';

/**
 * 默认内核：基于 @ohos.multimedia.avplayer（AP-3）
 * 通过状态机驱动：idle → initialized → prepared → playing/paused → completed
 *
 * ── DASH 双流（B 站 720P 以上画质必需）──
 * B 站已下线 720P 以上的单文件 MP4，1080P/1080P60/4K/HDR/8K 只有 DASH 形态：
 * 视频轨与音频轨是两个独立的 fMP4 地址，而 AVPlayer 一个实例只能吃一个地址。
 * 因此这里在 dash 模式下再起一路「音频轨播放器」：
 * - 视频轨播放器：绑 surface，只出画面（音量置 0）
 * - 音频轨播放器：不绑 surface，只出声音
 * - 音画同步：以视频轨时钟为基准，音频轨漂移超过阈值时 seek 对齐
 * - 任一路报错 → 通过 PlaySource.fallbackProvider 惰性取单文件地址并自动回退，
 *   保证「高画质播不了时也不会黑屏无声」
 */
export class AvPlayerEngine implements IPlayerEngine {
  /** 音频轨漂移阈值（ms）：超过则回拉对齐，低于阈值不干预避免频繁 seek */
  private static readonly SYNC_TOLERANCE_MS: number = 600;
  /** 主动 seek 后的音画同步静默窗口（ms）：两路 seek 完成有先后，
   *  窗口内比对位置会读到旧值，导致「刚对齐又被拉回」的反复 seek */
  private static readonly SYNC_SKIP_AFTER_SEEK_MS: number = 1500;

  private player: media.AVPlayer | null = null;
  /** DASH 音频轨播放器（仅 dash 模式存在） */
  private audioPlayer: media.AVPlayer | null = null;
  private state: PlaybackState = PlaybackState.Idle;
  private surfaceId: string = '';
  private source: PlaySource = new PlaySource();
  /** 兜底是否已触发（防止回退后再次回退造成死循环） */
  private fallbackUsed: boolean = false;
  /** 换源后需要恢复到的进度（ms），prepared 时消费（换源必然从 0 开始，此处回拉续播） */
  private pendingResumeMs: number = 0;
  /** 最近一次主动 seek 的时间戳（ms），用于音画同步静默窗口（见 syncAudioTrack） */
  private lastSeekAt: number = 0;
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

  async bindSurface(surfaceId: string): Promise<void> {
    this.surfaceId = surfaceId
  }

  /** 是否处于 DASH 双流模式（以播放源为准：source 在 setSource 起始处同步赋值，
   *  避免用「音频播放器实例」判断时、视频轨 prepared 早于音频轨创建而漏判静音、导致双声道叠音） */
  private get dashMode(): boolean {
    return this.source.audioUrl.length > 0;
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
      hilog.info(0x0000, TAG, `stateChange -> ${st}`);
      switch (st) {
        case 'initialized':
          if (this.surfaceId.length > 0) {
            p.surfaceId = this.surfaceId;
          }
          // 注意：videoScaleType 只能在 prepared 及之后状态设置，
          // initialized 阶段设置会报 5400102（prepared 分支已统一设置）
          p.prepare();
          break;
        case 'prepared':
          this.durationMs = p.duration > 0 ? p.duration : this.durationMs;
          // 显式设置视频缩放类型，确保 x86 设备渲染管线正确输出画面
          p.videoScaleType = media.VideoScaleType.VIDEO_SCALE_TYPE_FIT;
          hilog.info(0x0000, TAG, `prepared: ${p.width}x${p.height}, dur=${this.durationMs}ms, dash=${this.dashMode}`);
          // 上报视频尺寸，UI 层按宽高比渲染、决定全屏方向
          this.notifyVideoSize(p.width, p.height);
          // DASH 模式画面无声：声音由音频轨播放器负责
          p.setVolume(this.dashMode ? 0 : this.volume);
          p.setSpeed(AvPlayerEngine.toAvSpeed(this.speed));
          // 换源（画质切换 / 兜底回退）后回拉到原进度续播
          if (this.pendingResumeMs > 0) {
            const t = this.pendingResumeMs;
            this.pendingResumeMs = 0;
            hilog.info(0x0000, TAG, `resume after switch source at ${t}ms`);
            this.lastSeekAt = Date.now();
            p.seek(t);
          }
          this.setState(PlaybackState.Prepared);
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
      hilog.error(0x0000, TAG, `error ${err.code}: ${err.message}`);
      this.setState(PlaybackState.Error);
      // DASH 双流失败（如设备不支持该 fMP4 编码）→ 自动回退单文件，避免黑屏
      if (this.tryFallback()) {
        return;
      }
      if (this.errorCb !== null) {
        this.errorCb(err.code, err.message);
      }
    });

    p.on('timeUpdate', (time: number) => {
      this.positionMs = time;
      if (this.durationMs <= 0 && p.duration > 0) {
        this.durationMs = p.duration;
      }
      this.syncAudioTrack(time);
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
      hilog.info(0x0000, TAG, `videoSizeChange -> ${width}x${height}`);
      this.notifyVideoSize(width, height);
    });
  }

  // ---------- DASH 音频轨 ----------

  /** 音频轨播放器事件（与视频轨同构，但不绑 surface、不上报尺寸） */
  private bindAudioEvents(p: media.AVPlayer): void {
    p.on('stateChange', (st: media.AVPlayerState) => {
      hilog.info(0x0000, TAG, `audio stateChange -> ${st}`);
      if (st === 'initialized') {
        p.prepare();
      } else if (st === 'prepared') {
        p.setVolume(this.volume);
        p.setSpeed(AvPlayerEngine.toAvSpeed(this.speed));
        // 视频轨已起播时音频轨立即跟上（两者都由各自媒体时钟驱动，天然对齐）
        if (this.state === PlaybackState.Playing) {
          p.play();
          p.seek(this.positionMs);
        }
      } else if (st === 'error') {
        hilog.error(0x0000, TAG, 'audio track error');
        if (this.tryFallback()) {
          return;
        }
      }
    });
    p.on('error', (err: BusinessError) => {
      hilog.error(0x0000, TAG, `audio error ${err.code}: ${err.message}`);
      if (this.tryFallback()) {
        return;
      }
      if (this.errorCb !== null) {
        this.errorCb(err.code, `音频轨失败: ${err.message}`);
      }
    });
  }

  /**
   * 音画同步：以视频轨进度为基准，音频轨漂移超过阈值时 seek 对齐。
   * 两路各自解码、时钟独立，正常情况几乎无漂移，仅作兜底。
   */
  private syncAudioTrack(videoPosMs: number): void {
    const a = this.audioPlayer;
    if (a === null || a.state !== 'playing' || this.source.audioUrl.length === 0) {
      return;
    }
    // 主动 seek 后两路位置更新有先后，静默窗口内不比对，避免「刚对齐又被拉回」
    if (Date.now() - this.lastSeekAt < AvPlayerEngine.SYNC_SKIP_AFTER_SEEK_MS) {
      return;
    }
    try {
      const diff = videoPosMs - a.currentTime;
      if (diff > AvPlayerEngine.SYNC_TOLERANCE_MS || diff < -AvPlayerEngine.SYNC_TOLERANCE_MS) {
        hilog.info(0x0000, TAG, `sync audio from ${a.currentTime} to ${videoPosMs}`);
        a.seek(videoPosMs);
      }
    } catch (e) {
      hilog.error(0x0000, TAG, `sync audio fail: ${JSON.stringify(e)}`);
    }
  }

  private async setupAudioPlayer(url: string): Promise<void> {
    await this.releaseAudioPlayer();
    const a = await media.createAVPlayer();
    this.bindAudioEvents(a);
    this.audioPlayer = a;
    const hasHeaders = Object.keys(this.source.headers).length > 0;
    const headers = hasHeaders ? this.source.headers : undefined;
    const src = headers !== undefined
      ? media.createMediaSourceWithUrl(url, headers)
      : media.createMediaSourceWithUrl(url);
    a.setMediaSource(src, AvPlayerEngine.buildStrategy());
  }

  private async releaseAudioPlayer(): Promise<void> {
    const a = this.audioPlayer;
    if (a === null) {
      return;
    }
    this.audioPlayer = null;
    try {
      await a.release();
    } catch (e) {
      hilog.error(0x0000, TAG, `audio release fail: ${JSON.stringify(e)}`);
    }
  }

  /**
   * DASH 双流失败 → 惰性取单文件地址回退（只回退一次）。
   * @returns true 表示已接管错误（不再向上抛）
   */
  private tryFallback(): boolean {
    if (this.fallbackUsed || this.source.fallbackProvider === null || this.source.url.length === 0) {
      return false;
    }
    const provider = this.source.fallbackProvider;
    this.fallbackUsed = true;
    const resume = this.positionMs;
    hilog.warn(0x0000, TAG, `dash playback failed, fallback to single file at ${resume}ms`);
    provider().then(async (url: string) => {
      if (url.length === 0) {
        if (this.errorCb !== null) {
          this.errorCb(-1, '高画质不可用，且兜底地址获取失败');
        }
        return;
      }
      const fb = new PlaySource();
      fb.url = url;
      fb.headers = this.source.headers;
      fb.fallbackProvider = null;
      await this.setSource(fb);
      if (resume > 0) {
        this.positionMs = resume;
      }
    }).catch((e: Object) => {
      hilog.error(0x0000, TAG, `fallback provider fail: ${JSON.stringify(e)}`);
      if (this.errorCb !== null) {
        this.errorCb(-1, '兜底地址获取失败');
      }
    });
    return true;
  }

  private notifyVideoSize(width: number, height: number): void {
    if (width > 0 && height > 0 && this.videoSizeCb !== null) {
      this.videoSizeCb(width, height);
    }
  }

  /** 换源入口（resumeMs=0：从头播放） */
  async setSource(source: PlaySource): Promise<void> {
    return this.setSourceInternal(source, 0);
  }

  /**
   * 换源实现。
   * @param resumeMs 换源后要恢复到的进度（画质切换续播、DASH 兜底回退用；
   *                 AVPlayer 换源必然回到 0，故在 prepared 时统一 seek 回拉）
   */
  private async setSourceInternal(source: PlaySource, resumeMs: number): Promise<void> {
    this.source = source;
    this.fallbackUsed = false;
    this.pendingResumeMs = Math.max(0, resumeMs);
    this.setState(PlaybackState.Preparing);
    const p = await this.ensurePlayer();
    if (this.state === PlaybackState.Released) {
      return;
    }
    // 画质切换等场景：播放器已处于 prepared/playing 等高状态，
    // 直接 setMediaSource 非法（AVPlayer 状态机要求 idle/initialized），
    // 必须先 reset() 回 idle 再换源（reset 后 initialized→prepare 流程照常走）
    if (p.state !== 'idle' && p.state !== 'initialized') {
      hilog.info(0x0000, TAG, `reset before switch source (state=${p.state})`);
      await p.reset();
      await this.releaseAudioPlayer();
      // reset 回 idle：清空旧进度/时长，等待 initialized→prepare 流程
      this.positionMs = 0;
      this.durationMs = 0;
      this.bufferedMs = 0;
    }
    const strategy: media.PlaybackStrategy = AvPlayerEngine.buildStrategy();
    const hasHeaders = Object.keys(source.headers).length > 0;
    const src = hasHeaders
      ? media.createMediaSourceWithUrl(source.url, source.headers)
      : media.createMediaSourceWithUrl(source.url);
    p.setMediaSource(src, strategy);
    // DASH：并行拉起音频轨（视频轨 prepared 时通常音频轨也快就绪）
    if (source.audioUrl.length > 0) {
      await this.setupAudioPlayer(source.audioUrl);
    } else {
      await this.releaseAudioPlayer();
    }
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
        hilog.error(0x0000, TAG, `late bind surface fail: ${JSON.stringify(e)}`);
      }
    }
  }

  async play(): Promise<void> {
    if (this.player === null) {
      return;
    }
    try {
      await this.player.play();
      const a = this.audioPlayer;
      if (a !== null && a.state !== 'playing' && a.state !== 'idle' && a.state !== 'initialized') {
        await a.play();
      }
    } catch (e) {
      hilog.error(0x0000, TAG, `play fail: ${JSON.stringify(e)}`);
    }
  }

  async pause(): Promise<void> {
    if (this.player === null) {
      return;
    }
    try {
      await this.player.pause();
      const a = this.audioPlayer;
      if (a !== null && a.state === 'playing') {
        await a.pause();
      }
    } catch (e) {
      hilog.error(0x0000, TAG, `pause fail: ${JSON.stringify(e)}`);
    }
  }

  async seekTo(positionMs: number): Promise<void> {
    if (this.player === null) {
      return;
    }
    this.lastSeekAt = Date.now();
    try {
      await this.player.seek(positionMs);
      const a = this.audioPlayer;
      if (a !== null) {
        await a.seek(positionMs);
      }
    } catch (e) {
      hilog.error(0x0000, TAG, `seek fail: ${JSON.stringify(e)}`);
    }
  }

  async setVolume(volume: number): Promise<void> {
    this.volume = Math.max(0, Math.min(1, volume));
    if (this.player !== null) {
      try {
        // DASH 模式下画面无声：音量只施加在音频轨
        await this.player.setVolume(this.dashMode ? 0 : this.volume);
      } catch (e) {
        hilog.error(0x0000, TAG, `setVolume fail: ${JSON.stringify(e)}`);
      }
    }
    const a = this.audioPlayer;
    if (a !== null) {
      try {
        await a.setVolume(this.volume);
      } catch (e) {
        hilog.error(0x0000, TAG, `audio setVolume fail: ${JSON.stringify(e)}`);
      }
    }
  }

  async setSpeed(speed: number): Promise<void> {
    this.speed = speed;
    if (this.player !== null) {
      try {
        this.player.setSpeed(AvPlayerEngine.toAvSpeed(speed));
      } catch (e) {
        hilog.error(0x0000, TAG, `setSpeed fail: ${JSON.stringify(e)}`);
      }
    }
    const a = this.audioPlayer;
    if (a !== null) {
      try {
        a.setSpeed(AvPlayerEngine.toAvSpeed(speed));
      } catch (e) {
        hilog.error(0x0000, TAG, `audio setSpeed fail: ${JSON.stringify(e)}`);
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
    await this.releaseAudioPlayer();
    if (this.player !== null) {
      try {
        await this.player.release();
      } catch (e) {
        hilog.error(0x0000, TAG, `release fail: ${JSON.stringify(e)}`);
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
        hilog.error(0x0000, TAG, `getPosition fail: ${JSON.stringify(e)}`);
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

// 日志 TAG（规范：统一定义在文件最下方）
const TAG = AvPlayerEngine.name ?? 'AvPlayerEngine';
