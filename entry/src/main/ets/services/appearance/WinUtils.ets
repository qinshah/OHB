import { window } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

export let winUtils: WinUtil

export class WinUtil {
  static init(winStage: window.WindowStage) {
    if (winUtils == undefined) {
      winUtils = new WinUtil(winStage)
    }
  }

  /** 桌面形态（PC / 2in1），其 Dock 会覆盖窗口底部 */
  private static isDesktop(): boolean {
    try {
      const type = deviceInfo.deviceType;
      return type === 'pc' || type === '2in1';
    } catch (e) {
      return false;
    }
  }

  readonly topRectHeight = 'topRectHeight';
  readonly bottomRectHeight = 'bottomRectHeight';
  private winStage: window.WindowStage
  private mainWindow: window.Window
  private uIContext: UIContext

  private constructor(winStage: window.WindowStage) {
    this.winStage = winStage
    this.mainWindow = this.winStage.getMainWindowSync()
    // PC 的 Dock 是位于窗口之上的不透明悬浮层，全屏布局会把底部导航压到 Dock 下面；
    // 桌面形态改为最大化（自动避开 Dock），手机/平板继续全屏布局实现沉浸式
    if (WinUtil.isDesktop()) {
      this.mainWindow.maximize().catch((e: Error) => {
        hilog.error(0, TAG, 'maximize fail: %{public}s', e.message);
      });
    } else {
      this.mainWindow.setWindowLayoutFullScreen(true); // 沉浸式
    }
    hilog.info(0, TAG, 'deviceType=%{public}s, desktop=%{public}s', deviceInfo.deviceType,
      String(WinUtil.isDesktop()));
    this.uIContext = this.mainWindow.getUIContext()
    const px2vp = (value: number): number => {
      return this.uIContext.px2vp(value);
    }
    this.mainWindow.on('avoidAreaChange', (data) => { // 监听安全区变化
      if (data.type === window.AvoidAreaType.TYPE_SYSTEM) {
        const topRectHeight = px2vp(data.area.topRect.height);
        hilog.info(0, TAG, `topRectHeight变化：${topRectHeight}`);
        AppStorage.setOrCreate(this.topRectHeight, topRectHeight);
      } else if (data.type == window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
        const bottomRectHeight = px2vp(data.area.bottomRect.height);
        hilog.info(0, TAG, `bottomRectHeight变化：${bottomRectHeight}`);
        AppStorage.setOrCreate(this.bottomRectHeight, bottomRectHeight);
      }
    });
  }
}

const TAG = WinUtil.name