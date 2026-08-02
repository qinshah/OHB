// [API 23+] 视频全屏页（独立路由）
import { PlayerController } from '../player/PlayerController';
import { PlayerControllerHolder } from '../player/PlayerControllerHolder';
import { DisplayHelper } from '../common/utils/DisplayHelper';
import { NavService } from '../common/navigation/NavService';
import { PlayerControlView } from './components/PlayerControlView';
import { Logger } from '../common/utils/Logger';

/**
 * 视频全屏页（独立路由）
 *
 * 设计要点：
 * - 与 VideoDetailPage 共享同一个 PlayerController 实例（通过 PlayerControllerHolder 静态暂存）
 *   不使用 @Prop 传递，因为 @Prop 会对对象做深拷贝，导致 PlayerController 内部状态丢失
 * - 加载后按视频宽高比调用 DisplayHelper：
 *     aspect > 1.2 → 应用窗口全屏 + 横向
 *     aspect <= 1.2 → 仅应用窗口全屏，保持竖屏
 * - 退出时（aboutToDisappear）由 NavService 路由拦截器自动触发 DisplayHelper.exitAppFullscreen
 * - 进入全屏使用轻量 bindSurface（目标 surface 全新有效，实测可用，无重建卡顿）；
 *   退出全屏回详情页时才走重建播放器路径（详情页 surface 在全屏期间失效，必须重建）
 *
 * 注意：本页不释放 PlayerController（释放由 VideoDetailPage 负责）
 */
@Component
export struct VideoFullscreenPage {
  // 直接从 Holder 初始化共享控制器，避免 @State 先创建新实例再重新赋值
  // （重新赋值会导致子组件 @ObjectLink 的 aboutToAppear 注册回调到错误实例）
  @State controller: PlayerController = PlayerControllerHolder.getShared() ?? new PlayerController();
  private xcController: XComponentController = new XComponentController();

  aboutToAppear(): void {
    this.controller.attachUIContext(this.getUIContext());
    this.controller.isFullscreen = true;
    // 全屏按钮点击 = 退出全屏页
    this.controller.setFullscreenToggle(() => {
      NavService.pop();
    });
    // 视频宽高比就绪 → 通知 DisplayHelper 按方向应用全屏
    // 若 aspectRatio 已就绪（>0），回调会立即同步触发
    this.controller.setAspectRatioReady((aspect: number) => {
      DisplayHelper.applyFullscreenForVideo(aspect).catch((e: Object) => {
        Logger.error('Fullscreen', `applyFullscreenForVideo fail: ${JSON.stringify(e)}`);
      });
    });
  }

  aboutToDisappear(): void {
    this.controller.isFullscreen = false;
    this.controller.setFullscreenToggle(null);
    this.controller.setAspectRatioReady(null);
    PlayerControllerHolder.clearShared();
    // 路由拦截器会触发 DisplayHelper.exitAppFullscreen，此处无需重复调用
  }

  onPageShow(): void {
    // 从其它页面返回时轻量重绑本页 surface（XComponent onLoad 仅触发一次）
    const sid = this.xcController.getXComponentSurfaceId();
    if (sid.length > 0) {
      this.controller.bindSurface(sid);
    }
  }

  build() {
    Stack() {
      XComponent({
        type: XComponentType.SURFACE,
        controller: this.xcController
      })
        .onLoad(() => {
          this.controller.bindSurface(this.xcController.getXComponentSurfaceId());
        })
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Black)

      // 控制层（含全屏按钮 → 退出全屏页）
      PlayerControlView({ controller: this.controller })
        .width('100%')
        .height('100%')

      // 退出全屏按钮（左上角）：SDK SymbolGlyph 图标，不用 unicode 字符
      Stack() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(22)
          .fontColor([Color.White])
          .padding(8)
      }
      .width(40)
      .height(40)
      .borderRadius(20)
      .backgroundColor('#66000000')
      .position({ x: 12, y: 12 })
      .onClick(() => {
        NavService.pop();
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
  }
}
