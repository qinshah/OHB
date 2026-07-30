import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { IPlayerEngine } from './IPlayerEngine';
import { AvPlayerEngine } from './AvPlayerEngine';
import { PlaybackState } from './PlayerTypes';
import { Logger } from '../common/utils/Logger';
import { AppConstants } from '../common/constants/AppConstants';

/**
 * 统一播放控制器（AP-3 / Task 5）
 * - 持有当前 IPlayerEngine（默认 AvPlayerEngine，可替换 mpv/mdk）
 * - 向上暴露可观察状态流（@Observed，UI 直接绑定）
 * - 向下转发操作；设置项（默认清晰度/音量）在此注入
 */
@Observed
export class PlayerController {
  /** 播放状态 */
  state: PlaybackState = PlaybackState.Idle;
  positionMs: number = 0;
  durationMs: number = 0;
  bufferedMs: number = 0;
  /** 音量 0~1（应用内） */
  volume: number = 1.0;
  /** 屏幕亮度 0~1 */
  brightness: number = -1;
  /** 倍速 */
  speed: number = 1.0;
  /** 是否全屏 */
  isFullscreen: boolean = false;
  /** 是否缓冲中 */
  isPreparing: boolean = false;
  /** 错误信息（空串表示无错误） */
  errorMessage: string = '';
  /** 播放完成 */
  isCompleted: boolean = false;

  private engine: IPlayerEngine;
  private uiContext: UIContext | null = null;

  constructor(engine: IPlayerEngine | null = null) {
    this.engine = engine ?? new AvPlayerEngine();
    this.bindEngine(this.engine);
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
  }

  /** 绑定渲染 surface（XComponent onLoad 后调用） */
  bindSurface(surfaceId: string): void {
    this.engine.setSurface(surfaceId);
  }

  /** 加载并播放 */
  async load(url: string, headers: Record<string, string>): Promise<void> {
    this.errorMessage = '';
    this.isCompleted = false;
    this.positionMs = 0;
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

  async setVolume(volume: number): Promise<void> {
    this.volume = Math.max(0, Math.min(1, volume));
    await this.engine.setVolume(this.volume);
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

  /** 全屏切换：横屏 + 沉浸式 */
  async enterFullscreen(): Promise<void> {
    if (this.uiContext === null) {
      return;
    }
    try {
      const win = await window.getLastWindow(this.uiContext.getHostContext() as common.Context);
      await win.setPreferredOrientation(window.Orientation.LANDSCAPE);
      await win.setWindowLayoutFullScreen(true);
      await win.setWindowSystemBarEnable([]);
      this.isFullscreen = true;
    } catch (e) {
      Logger.error('Player', `enterFullscreen fail: ${JSON.stringify(e)}`);
    }
  }

  async exitFullscreen(): Promise<void> {
    if (this.uiContext === null) {
      return;
    }
    try {
      const win = await window.getLastWindow(this.uiContext.getHostContext() as common.Context);
      await win.setPreferredOrientation(window.Orientation.PORTRAIT);
      await win.setWindowLayoutFullScreen(false);
      await win.setWindowSystemBarEnable(['status', 'navigation']);
      this.isFullscreen = false;
    } catch (e) {
      Logger.error('Player', `exitFullscreen fail: ${JSON.stringify(e)}`);
    }
  }

  toggleFullscreen(): void {
    if (this.isFullscreen) {
      this.exitFullscreen();
    } else {
      this.enterFullscreen();
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
    await this.engine.release();
    this.state = PlaybackState.Released;
  }
}
