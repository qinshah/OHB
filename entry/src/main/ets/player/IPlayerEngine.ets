import { PlaybackState } from './PlayerTypes';

/**
 * 播放器内核抽象（AP-3）
 * 所有内核（AVPlayer / mpv / mdk）实现同一接口，PlayerController 持有并转发，
 * UI 层对内核切换无感（AC-A-1）。
 */
export interface IPlayerEngine {
  /** 准备播放源。surfaceId 未就绪时可先调用，待 setSurface 后再 prepare */
  setSource(url: string, headers: Record<string, string>): Promise<void>;
  /** 绑定渲染 surface */
  setSurface(surfaceId: string): void;
  /**
   * 重建播放器并切换到新 surface（全屏/退出全屏切换专用）。
   * AVPlayer 在播放中直接改 surfaceId 时，若旧 surface 正在销毁或新 surface 未稳定，
   * 会进入不可恢复的黑屏状态；重建播放器从同一源重新绑定新 surface 可彻底规避。
   */
  rebindSurface(surfaceId: string): Promise<void>;
  play(): Promise<void>;
  pause(): Promise<void>;
  /** 跳转（毫秒） */
  seekTo(positionMs: number): Promise<void>;
  /** 应用内音量 0.0 ~ 1.0 */
  setVolume(volume: number): Promise<void>;
  /** 倍速 0.5 ~ 4.0 */
  setSpeed(speed: number): Promise<void>;
  /** 释放内核资源 */
  release(): Promise<void>;

  /** 当前播放状态 */
  getState(): PlaybackState;
  getPosition(): number;
  getDuration(): number;

  /** 状态变更回调（由 PlayerController 注册） */
  onStateChange(cb: (state: PlaybackState) => void): void;
  onProgress(cb: (positionMs: number, durationMs: number, bufferedMs: number) => void): void;
  onError(cb: (code: number, message: string) => void): void;
  onCompletion(cb: () => void): void;
  /**
   * 视频尺寸变化回调：内核在 prepared / videoSizeChanged 时上报。
   * UI 层据此按宽高比渲染、决定全屏方向。
   */
  onVideoSizeChange(cb: (width: number, height: number) => void): void;
}
