// [API 23+] 应用窗口全屏与方向管理工具
import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Route } from '../../framework/Route';
import { WindowLayout } from '../window/WindowLayout';

/**
 * DisplayHelper
 *
 * 单独的工具，负责应用窗口全屏 + 显示方向切换。
 * 路由感知：NavService 在路由变化时调用 onRouteChanged，
 * DisplayHelper 根据目标页面决定是否启用应用窗口全屏和方向锁定。
 *
 * 设计原则：
 * - 布局与方向只由窗口尺寸决定，不按设备类型或折叠态分支
 * - 视频全屏页（VIDEO_FULLSCREEN）按视频宽高比决定是否锁横屏（> 1.2 视为横向视频），
 *   其余情况不锁方向，由 VideoFullscreenPage 加载视频后主动调用 applyFullscreenForVideo(aspect)
 * - 其它页面（VIDEO_DETAIL / LOGIN / SEARCH_RESULT / Tab 根页）一律退出全屏并恢复不锁定方向
 * - 非页面级路由变化（isPage=false）不做处理
 *
 * 注意：本工具只管应用窗口（Window）层面；XComponent 的尺寸/aspectRatio 由页面层维护。
 */
export class DisplayHelper {
  private static win: window.Window | null = null;
  private static _fullscreen: boolean = false;
  private static pLandscape: boolean = false;
  /** 本次全屏是否由视频页发起（退出时需还原浮窗尺寸） */
  private static videoFullscreen: boolean = false;
  /** 最近一次向系统请求的方向锁定（'landscape' / 'none'）；
   *  与 isLandscape 区分：后者反映系统是否真的接受了旋转 */
  private static pLockRequest: string = 'none';
  /** 是否已显式调用过 enter/exit，避免初始页面误触发恢复 */
  private static pInitialized: boolean = false;

  /** 在 EntryAbility onWindowStageCreate 后调用，缓存主窗口实例 */
  static async init(ctx: common.Context): Promise<void> {
    try {
      DisplayHelper.win = await window.getLastWindow(ctx);
      DisplayHelper.pInitialized = true;
    } catch (e) {
      hilog.error(0, TAG, 'init fail: %{public}s', JSON.stringify(e));
    }
  }

  static get fullscreen(): boolean {
    return DisplayHelper._fullscreen;
  }

  static get isLandscape(): boolean {
    return DisplayHelper.pLandscape;
  }

  /** 应用请求的方向锁定决策（PC 等不支持旋转的设备上系统可能拒绝，但决策仍可断言） */
  static get lockRequest(): string {
    return DisplayHelper.pLockRequest;
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
   * - 否则仅应用窗口全屏，不锁方向（窗口尺寸继续作为布局依据）
   */
  static async applyFullscreenForVideo(aspectRatio: number): Promise<void> {
    try {
      // 记录本次全屏由视频页发起：退出时需要把窗口还原成进入前的浮窗尺寸
      DisplayHelper.videoFullscreen = true;
      await DisplayHelper.enterAppFullscreen();
      const landscape: boolean = WindowLayout.isLandscapeVideo(aspectRatio);
      DisplayHelper.pLockRequest = landscape ? 'landscape' : 'none';
      hilog.info(0, TAG, 'fullscreen aspect=%{public}s lockLandscape=%{public}s',
        aspectRatio.toFixed(3), `${landscape}`);
      if (landscape) {
        await DisplayHelper.setLandscape();
      }
    } catch (e) {
      hilog.error(0, TAG, 'applyFullscreenForVideo fail: %{public}s', JSON.stringify(e));
    }
  }

  /** 进入应用窗口全屏：沉浸式 + 隐藏系统栏 */
  static async enterAppFullscreen(): Promise<void> {
    if (DisplayHelper.win === null) {
      return;
    }
    const win = DisplayHelper.win;
    try {
      await win.setWindowLayoutFullScreen(true);
    } catch (e) {
      hilog.error(0, TAG, 'enterAppFullscreen layout fail: %{public}s', JSON.stringify(e));
    }
    try {
      await win.setWindowSystemBarEnable([]);
    } catch (e) {
      hilog.error(0, TAG, 'enterAppFullscreen hideBars fail: %{public}s', JSON.stringify(e));
    }
  }

  /**
   * 退出应用窗口全屏：恢复系统栏 + 解除方向锁定；视频发起的全屏额外还原浮窗尺寸。
   * 每个系统调用独立容错——PC 上部分调用会被拒（如 setPreferredOrientation），
   * 若串在一个 try 里会连带跳过后面的复位与 recover，把窗口卡在全屏态。
   */
  static async exitAppFullscreen(): Promise<void> {
    if (DisplayHelper.win === null) {
      return;
    }
    const win = DisplayHelper.win;
    const wasVideoFullscreen = DisplayHelper.videoFullscreen;
    DisplayHelper.videoFullscreen = false;
    DisplayHelper.pLandscape = false;
    DisplayHelper.pLockRequest = 'none';
    try {
      await win.setPreferredOrientation(window.Orientation.UNSPECIFIED);
    } catch (e) {
      hilog.error(0, TAG, 'exitAppFullscreen unlock fail: %{public}s', JSON.stringify(e));
    }
    try {
      await win.setWindowSystemBarEnable(['status', 'navigation']);
    } catch (e) {
      hilog.error(0, TAG, 'exitAppFullscreen restore bars fail: %{public}s', JSON.stringify(e));
    }
    if (wasVideoFullscreen) {
      // PC / 平板上进入全屏会把窗口切成最大化，不 recover 会把用户原来的窗口尺寸丢掉
      try {
        await win.recover();
      } catch (e) {
        hilog.error(0, TAG, 'exitAppFullscreen recover fail: %{public}s', JSON.stringify(e));
      }
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
      hilog.error(0, TAG, 'setLandscape fail: %{public}s', JSON.stringify(e));
    }
  }
}

const TAG = DisplayHelper.name;
