import { window } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { KEY_WIN_HEIGHT_VP, KEY_WIN_WIDTH_VP } from '../../common/window/WindowLayout';

export let winUtils: WinUtil

export class WinUtil {
  static init(winStage: window.WindowStage) {
    if (winUtils == undefined) {
      winUtils = new WinUtil(winStage)
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
    // 统一沉浸式布局：窗口尺寸由系统或用户控制，应用不再自行最大化；
    // 桌面 Dock 等遮挡通过 avoidAreaChange 暴露的底部安全区高度以内边距避让
    this.mainWindow.setWindowLayoutFullScreen(true).catch((e: Error) => {
      hilog.error(0, TAG, 'setWindowLayoutFullScreen fail: %{public}s', e.message);
    });
    hilog.info(0, TAG, 'deviceType=%{public}s', deviceInfo.deviceType);
    this.uIContext = this.mainWindow.getUIContext()
    const px2vp = (value: number): number => {
      return this.uIContext.px2vp(value);
    }
    // 单一窗口尺寸源：主窗口尺寸变化时写入 AppStorage，页面只读这份数据
    const rect = this.mainWindow.getWindowProperties().windowRect
    this.publishSize(rect.width, rect.height)
    this.mainWindow.on('windowSizeChange', (size: window.Size) => {
      this.publishSize(size.width, size.height)
    })
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
  /** 把主窗口尺寸（px）换算为 vp 后写入 AppStorage */
  private publishSize(widthPx: number, heightPx: number): void {
    const widthVp = this.uIContext.px2vp(widthPx)
    const heightVp = this.uIContext.px2vp(heightPx)
    AppStorage.setOrCreate(KEY_WIN_WIDTH_VP, widthVp)
    AppStorage.setOrCreate(KEY_WIN_HEIGHT_VP, heightVp)
    hilog.info(0, TAG, `windowSize变化：${widthPx}x${heightPx}px -> ${widthVp}x${heightVp}vp`);
  }
}

const TAG = WinUtil.name