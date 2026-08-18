// [API 23+] 应用窗口全屏与方向管理工具
import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { Logger } from './Logger';
import { Route } from '../../framework/Route';

/**
 * DisplayHelper
 *
 * 单独的工具，负责应用窗口全屏 + 显示方向切换。
 * 路由感知：NavService 在路由变化时调用 onRouteChanged，
 * DisplayHelper 根据目标页面决定是否启用应用窗口全屏和方向锁定。
 *
 * 设计原则：
 * - 视频全屏页（VIDEO_FULLSCREEN）按视频宽高比决定方向（宽高比 > 1.2 视为横向视频）
 *   由 VideoFullscreenPage 加载视频后主动调用 applyFullscreenForVideo(aspect)
 * - 其它页面（VIDEO_DETAIL / LOGIN / SEARCH_RESULT / Tab 根页）一律退出全屏并恢复竖屏
 * - 非页面级路由变化（isPage=false）不做处理
 *
 * 注意：本工具只管应用窗口（Window）层面；XComponent 的尺寸/aspectRatio 由页面层维护。
 */
export class DisplayHelper {
  private static win: window.Window | null = null;
  private static _fullscreen: boolean = false;
  private static pLandscape: boolean = false;
  /** 是否已显式调用过 enter/exit，避免初始页面误触发恢复 */
  private static pInitialized: boolean = false;

  /** 在 EntryAbility onWindowStageCreate 后调用，缓存主窗口实例 */
  static async init(ctx: common.Context): Promise<void> {
    try {
      DisplayHelper.win = await window.getLastWindow(ctx);
      DisplayHelper.pInitialized = true;
    } catch (e) {
      Logger.error('Display', `init fail: ${JSON.stringify(e)}`);
    }
  }

  static get fullscreen(): boolean {
    return DisplayHelper._fullscreen;
  }

  static get isLandscape(): boolean {
    return DisplayHelper.pLandscape;
  }

  /**
   * 路由变化入口（由 NavService 路由拦截器调用）。
   * @param name    目标路由名（NavDestination name），undefined 表示根页
   * @param isPage  是否为页面级路由变化。非页面级变化（弹窗/对话框）不处理
   */
  static async onRouteChanged(name: string | undefined, isPage: boolean): Promise<void> {
    if (!isPage) {
      return;
    }
    if (DisplayHelper.win === null || !DisplayHelper.pInitialized) {
      return;
    }
    DisplayHelper._fullscreen = name === Route.videoFullscreen.name
    // 其它任何页面：退出全屏并恢复竖屏
    if (!DisplayHelper._fullscreen) {
      await DisplayHelper.exitAppFullscreen();
    }
  }

  /**
   * 视频全屏页加载视频后调用：
   * - 宽高比 > 1.2 视为横向视频 → 应用窗口全屏 + 横向锁定
   * - 否则视为竖屏视频 → 仅应用窗口全屏，保持竖屏
   */
  static async applyFullscreenForVideo(aspectRatio: number): Promise<void> {
    try {
      await DisplayHelper.enterAppFullscreen();
      if (aspectRatio > 1.2) {
        await DisplayHelper.setLandscape();
      } else {
        await DisplayHelper.setPortrait();
      }
    } catch (e) {
      Logger.error('Display', `applyFullscreenForVideo fail: ${JSON.stringify(e)}`);
    }
  }

  /** 进入应用窗口全屏：沉浸式 + 隐藏系统栏 */
  static async enterAppFullscreen(): Promise<void> {
    if (DisplayHelper.win === null) {
      return;
    }
    try {
      await DisplayHelper.win.setWindowLayoutFullScreen(true);
      await DisplayHelper.win.setWindowSystemBarEnable([]);
    } catch (e) {
      Logger.error('Display', `enterAppFullscreen fail: ${JSON.stringify(e)}`);
    }
  }

  /** 退出应用窗口全屏：恢复系统栏 + 恢复竖屏方向 */
  static async exitAppFullscreen(): Promise<void> {
    if (DisplayHelper.win === null) {
      return;
    }
    try {
      await DisplayHelper.win.setPreferredOrientation(window.Orientation.UNSPECIFIED);
      // await DisplayHelper.win.setWindowLayoutFullScreen(false);
      await DisplayHelper.win.setWindowSystemBarEnable(['status', 'navigation']);
      DisplayHelper.pLandscape = false;
    } catch (e) {
      Logger.error('Display', `exitAppFullscreen fail: ${JSON.stringify(e)}`);
    }
  }

  /** 锁定横向 */
  static async setLandscape(): Promise<void> {
    if (DisplayHelper.win === null) {
      return;
    }
    try {
      await DisplayHelper.win.setPreferredOrientation(window.Orientation.AUTO_ROTATION_LANDSCAPE);
      DisplayHelper.pLandscape = true;
    } catch (e) {
      Logger.error('Display', `setLandscape fail: ${JSON.stringify(e)}`);
    }
  }

  /** 锁定竖屏 */
  static async setPortrait(): Promise<void> {
    if (DisplayHelper.win === null) {
      return;
    }
    try {
      await DisplayHelper.win.setPreferredOrientation(window.Orientation.PORTRAIT);
      DisplayHelper.pLandscape = false;
    } catch (e) {
      Logger.error('Display', `setPortrait fail: ${JSON.stringify(e)}`);
    }
  }
}
