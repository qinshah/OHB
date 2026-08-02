// [API 23+] 播放控制器共享容器
import { PlayerController } from './PlayerController';

/**
 * PlayerControllerHolder
 *
 * 用于在 VideoDetailPage 与 VideoFullscreenPage 之间共享同一个 PlayerController 实例，
 * 保证全屏切换时视频连续播放（不重启、不丢进度）。
 *
 * 注意：不通过 @Prop 传递（@Prop 会对对象做深拷贝，导致 PlayerController 内部状态丢失），
 * 而是通过静态 setShared/getShared 在路由跳转前暂存引用，目标页 aboutToAppear 时取回。
 */
export class PlayerControllerHolder {
  private static shared: PlayerController | null = null;
  private ctrl: PlayerController;

  constructor(ctrl: PlayerController) {
    this.ctrl = ctrl;
  }

  controller(): PlayerController {
    return this.ctrl;
  }

  /** 路由跳转前暂存共享控制器实例 */
  static setShared(ctrl: PlayerController): void {
    PlayerControllerHolder.shared = ctrl;
  }

  /** 目标页 aboutToAppear 时取回共享控制器实例 */
  static getShared(): PlayerController | null {
    return PlayerControllerHolder.shared;
  }

  /** 目标页离开时清除引用（避免泄漏） */
  static clearShared(): void {
    PlayerControllerHolder.shared = null;
  }
}
