// [API 23+] 视频全屏页（独立路由）
import { Player } from '../player/Player';
import { PlayerRepository } from '../repository/PlayerRepository';
import { DisplayHelper } from '../common/utils/DisplayHelper';
import { NavService } from '../common/navigation/NavService';
import { PlayerControlView } from '../components/PlayerControlView';
import { Logger } from '../common/utils/Logger';

/**
 * 视频全屏页（独立路由）
 *
 * 设计要点：
 * - 与 VideoDetailPage 共享同一个 Player 实例：全屏页通过 playerId（bvid）经
 *   PlayerRepository.get(id) 获取，不再通过 @Prop/路由参数直接传递 Player 对象
 *   （@Prop 会对对象做深拷贝，导致 Player 内部状态丢失）
 * - 加载后按视频宽高比调用 DisplayHelper：
 *     aspect > 1.2 → 应用窗口全屏 + 横向
 *     aspect <= 1.2 → 仅应用窗口全屏，保持竖屏
 * - 退出时（aboutToDisappear）由 NavService 路由拦截器自动触发 DisplayHelper.exitAppFullscreen
 * - 进入全屏使用轻量 bindSurface（目标 surface 全新有效，实测可用，无重建卡顿）；
 *   退出全屏回详情页时才走重建播放器路径（详情页 surface 在全屏期间失效，必须重建）
 *
 * 注意：本页不释放 Player（释放由 VideoDetailPage 经 PlayerRepository.remove 负责）
 */
@Component
export struct VideoFullscreenPage {
  /** 播放器业务 id（bvid），经 PlayerRepository.get(id) 获取共享的 Player 实例 */
  @Prop playerId: string = ''
  @State playerVM: Player =
    PlayerRepository.get(this.playerId) ?? PlayerRepository.create(this.playerId)
  private xcController: XComponentController = new XComponentController();

  aboutToAppear(): void {
    this.playerVM.attachUIContext(this.getUIContext());
    // 视频宽高比就绪 → 通知 DisplayHelper 按方向应用全屏
    // 若 aspectRatio 已就绪（>0），回调会立即同步触发
    this.playerVM.setAspectRatioReady((aspect: number) => {
      DisplayHelper.applyFullscreenForVideo(aspect).catch((e: Object) => {
        Logger.error('Fullscreen', `applyFullscreenForVideo fail: ${JSON.stringify(e)}`);
      });
    });
  }

  aboutToDisappear(): void {
    this.playerVM.setAspectRatioReady(null);
  }

  build() {
    Stack() {
      XComponent({
        type: XComponentType.SURFACE,
        controller: this.xcController
      })
        .onLoad(() => {
          this.playerVM.bindSurface(this.xcController.getXComponentSurfaceId())
        })
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Black)

      // 控制层（含全屏按钮 → 退出全屏页）
      PlayerControlView({ playerId: this.playerId })
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
