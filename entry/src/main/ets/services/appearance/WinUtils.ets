import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

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
    this.mainWindow.setWindowLayoutFullScreen(true); // 沉浸式
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