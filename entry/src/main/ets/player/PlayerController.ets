// [API 23+] 统一播放控制器
import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { IPlayerEngine } from './IPlayerEngine';
import { AvPlayerEngine } from './AvPlayerEngine';
import { PlaybackState } from './PlayerTypes';
import { Logger } from '../common/utils/Logger';
import { AppConstants } from '../common/constants/AppConstants';
import { SystemAudioHelper } from '../common/utils/SystemAudioHelper';

/**
 * 统一播放控制器（AP-3 / Task 5）
 * - 持有当前 IPlayerEngine（默认 AvPlayerEngine，可替换 mpv/mdk）
 * - 向上暴露可观察状态流（@Observed，UI 直接绑定）
 * - 向下转发操作；设置项（默认清晰度/音量）在此注入
 *
 * 重构要点（播放优化）：
 * - 视频宽高比：通过 onVideoSizeChange 上报，UI 据此按比例渲染
 * - 全屏改为路由页：isFullscreen 仅作为状态标记由 VideoFullscreenPage 维护，
 *   全屏切换通过 fullscreenToggleCb 回调由页面决定（push 路由 / pop 路由）
 * - 音量改为系统级：应用不可直接设系统音量，调节动作由 UI 层的 AVVolumePanel 组件完成；
 *   systemVolume 字段由 SystemAudioHelper 监听器维护实际值，UI Hub 显示该值
 * - 亮度保持窗口级；brightness 字段即当前窗口亮度
 */
@Observed
export class PlayerController {
  /** 播放状态 */
  state: PlaybackState = PlaybackState.Idle;
  positionMs: number = 0;
  durationMs: number = 0;
  bufferedMs: number = 0;

  /** 视频尺寸（来自内核 prepared / videoSizeChange） */
  videoWidth: number = 0;
  videoHeight: number = 0;
  /** 视频宽高比 width/height，未就绪时为 0（UI 用此值渲染 XComponent） */
  aspectRatio: number = 0;

  /** 系统音量 0..1（实际监控值，由 SystemAudioHelper 监听器维护；调节由 UI 层 AVVolumePanel 完成） */
  systemVolume: number = 0;
  /** 屏幕亮度 0..1（窗口级，-1 表示未读取） */
  brightness: number = -1;
  /** 倍速 */
  speed: number = 1.0;
  /** 是否处于全屏页（仅由 VideoFullscreenPage 设置 true / 离开时设置 false） */
  isFullscreen: boolean = false;
  /** 是否缓冲中 */
  isPreparing: boolean = false;
  /** 错误信息（空串表示无错误） */
  errorMessage: string = '';
  /** 播放完成 */
  isCompleted: boolean = false;

  private engine: IPlayerEngine;
  private uiContext: UIContext | null = null;
  /** UI 注册的全屏切换回调：VideoDetailPage push 路由 / VideoFullscreenPage pop */
  private fullscreenToggleCb: (() => void) | null = null;
  /** 视频宽高比就绪回调（aspectRatio 首次 > 0 时触发一次，由 VideoFullscreenPage 使用） */
  private aspectReadyCb: ((aspect: number) => void) | null = null;
  /** 系统音量变化回调（由 SystemAudioHelper 监听器驱动，UI 注册用于刷新 Hub） */
  private sysVolumeChangeCb: (() => void) | null = null;
  /** 本控制器注册到 SystemAudioHelper 的监听（release 时反注册，避免泄漏） */
  private volumeListenerCb: (() => void) | null = null;

  constructor(engine: IPlayerEngine | null = null) {
    this.engine = engine ?? new AvPlayerEngine();
    this.bindEngine(this.engine);
    // 初始化系统音量监听：Hub 显示真实监控值（多监听者模式，Controller 仅负责回写字段）
    this.systemVolume = SystemAudioHelper.normalizedVolume;
    this.volumeListenerCb = (): void => {
      this.systemVolume = SystemAudioHelper.normalizedVolume;
      if (this.sysVolumeChangeCb !== null) {
        this.sysVolumeChangeCb();
      }
    };
    SystemAudioHelper.addVolumeListener(this.volumeListenerCb);
  }

  /** 替换内核（AC-A-1：UI 与 Controller 无需改动，仅替换实例） */
  switchEngine(engine: IPlayerEngine): void {
    const old = this.engine;
    old.release();
    this.engine = engine;
    this.bindEngine(engine);
    this.state = PlaybackState.Idle;
  }

  get currentEngine(): IPlayerEngine {
    return this.engine;
  }

  attachUIContext(ctx: UIContext): void {
    this.uiContext = ctx;
  }

  /** UI 注册全屏切换回调 */
  setFullscreenToggle(cb: (() => void) | null): void {
    this.fullscreenToggleCb = cb;
  }

  /**
   * UI 注册视频宽高比就绪回调。
   * 当 aspectRatio 首次变为 > 0 时触发一次（用于 VideoFullscreenPage 决定全屏方向）。
   * 若注册时 aspectRatio 已就绪，则立即触发。
   */
  setAspectRatioReady(cb: ((aspect: number) => void) | null): void {
    this.aspectReadyCb = cb;
    if (cb !== null && this.aspectRatio > 0) {
      cb(this.aspectRatio);
      this.aspectReadyCb = null;
    }
  }

  /** UI 注册系统音量变化回调（用于 Hub 显示硬件音量键变化的实际值） */
  setSystemVolumeChange(cb: (() => void) | null): void {
    this.sysVolumeChangeCb = cb;
  }

  private bindEngine(engine: IPlayerEngine): void {
    engine.onStateChange((s: PlaybackState) => {
      this.state = s;
      this.isPreparing = s === PlaybackState.Preparing;
      this.isCompleted = s === PlaybackState.Completed;
      if (s === PlaybackState.Prepared) {
        // 准备完成自动起播
        engine.play();
        this.durationMs = engine.getDuration();
      }
    });
    engine.onProgress((pos: number, dur: number, buffered: number) => {
      this.positionMs = pos;
      this.durationMs = dur;
      this.bufferedMs = buffered;
    });
    engine.onError((code: number, message: string) => {
      this.errorMessage = `播放失败(${code}): ${message}`;
    });
    engine.onCompletion(() => {
      this.isCompleted = true;
    });
    engine.onVideoSizeChange((width: number, height: number) => {
      this.videoWidth = width;
      this.videoHeight = height;
      this.aspectRatio = height > 0 ? width / height : 0;
      Logger.info('Player', `videoSize ${width}x${height}, aspect=${this.aspectRatio.toFixed(2)}`);
      // 触发一次性就绪回调
      if (this.aspectRatio > 0 && this.aspectReadyCb !== null) {
        const cb = this.aspectReadyCb;
        this.aspectReadyCb = null;
        cb(this.aspectRatio);
      }
    });
  }

  /** 绑定渲染 surface（XComponent onLoad 后调用；页面切换时可重复调用） */
  bindSurface(surfaceId: string): void {
    this.engine.setSurface(surfaceId);
  }

  /** 加载并播放 */
  async load(url: string, headers: Record<string, string>): Promise<void> {
    this.errorMessage = '';
    this.isCompleted = false;
    this.positionMs = 0;
    this.aspectRatio = 0;
    this.videoWidth = 0;
    this.videoHeight = 0;
    await this.engine.setSource(url, headers);
  }

  togglePlay(): void {
    if (this.state === PlaybackState.Playing) {
      this.engine.pause();
    } else if (this.state === PlaybackState.Paused || this.state === PlaybackState.Prepared) {
      this.engine.play();
    } else if (this.state === PlaybackState.Completed) {
      this.engine.seekTo(0);
      this.engine.play();
    }
  }

  seekTo(positionMs: number): void {
    this.engine.seekTo(positionMs);
  }

  /** 主动从系统同步一次音量（页面显示/手势开始前调用，确保基准值与 Hub 初始值真实） */
  syncSystemVolume(): void {
    SystemAudioHelper.syncFromSystem();
    this.systemVolume = SystemAudioHelper.normalizedVolume;
  }

  /**
   * 从内核同步一次播放进度（UI 定时器兜底，保证进度条/时间文本实时刷新，
   * 参考 PiliPlus 连续进度流；不依赖 timeUpdate 事件密度）。
   */
  syncProgress(): void {
    const pos = this.engine.getPosition();
    if (pos >= 0) {
      let p = pos;
      if (this.durationMs > 0 && p > this.durationMs) {
        p = this.durationMs;
      }
      if (p !== this.positionMs) {
        this.positionMs = p;
      }
    }
    const dur = this.engine.getDuration();
    if (dur > 0 && dur !== this.durationMs) {
      this.durationMs = dur;
    }
  }

  /** 屏幕亮度（window 级，0~1） */
  async setBrightness(brightness: number): Promise<void> {
    const b = Math.max(0, Math.min(1, brightness));
    this.brightness = b;
    try {
      if (this.uiContext !== null) {
        const win = await window.getLastWindow(this.uiContext.getHostContext() as common.Context);
        await win.setWindowBrightness(b);
      }
    } catch (e) {
      Logger.error('Player', `setBrightness fail: ${JSON.stringify(e)}`);
    }
  }

  async getBrightness(): Promise<number> {
    try {
      if (this.uiContext !== null) {
        const win = await window.getLastWindow(this.uiContext.getHostContext() as common.Context);
        const props = win.getWindowProperties();
        if (props.brightness !== undefined && props.brightness >= 0) {
          this.brightness = props.brightness;
          return this.brightness;
        }
      }
    } catch (e) {
      Logger.error('Player', `getBrightness fail: ${JSON.stringify(e)}`);
    }
    this.brightness = 0.5;
    return this.brightness;
  }

  async setSpeed(speed: number): Promise<void> {
    this.speed = speed;
    await this.engine.setSpeed(speed);
  }

  /** UI 触发全屏切换（实际行为由 fullscreenToggleCb 决定） */
  toggleFullscreen(): void {
    if (this.fullscreenToggleCb !== null) {
      this.fullscreenToggleCb();
    }
  }

  /** 播放请求头（B站防盗链） */
  static defaultHeaders(): Record<string, string> {
    const headers: Record<string, string> = {};
    headers['Referer'] = AppConstants.REFERER;
    headers['User-Agent'] = AppConstants.WEB_UA;
    return headers;
  }

  async release(): Promise<void> {
    if (this.volumeListenerCb !== null) {
      SystemAudioHelper.removeVolumeListener(this.volumeListenerCb);
      this.volumeListenerCb = null;
    }
    await this.engine.release();
    this.state = PlaybackState.Released;
  }
}
