// [API 23+] 视频全屏页（独立路由）
import { Player } from '../player/Player';
import { PlayerRepository } from '../repository/PlayerRepository';
import { DisplayHelper } from '../common/utils/DisplayHelper';
import { Route } from '../framework/Route';
import { PlayerControlView } from '../components/PlayerControlView';
import { VideoNodeController } from '../player/VideoNodeController';
import { display } from '@kit.ArkUI';
import { Logger } from '../common/utils/Logger';

/**
 * 视频全屏页（独立路由，节点迁移方案）
 *
 * 设计要点：
 * - 与 VideoDetailPage 共享同一个 Player 实例：全屏页通过 playerId（bvid）经
 *   PlayerRepository.get(id) 获取，不通过 @Prop/路由参数直接传递 Player 对象
 *   （@Prop 会对对象做深拷贝，导致 Player 内部状态丢失）
 * - 渲染节点迁移：与详情页共享同一个 XComponent 节点（VideoNodeController），
 *   Surface 在全屏切换全程不销毁，播放器无需换绑/重建，播放零中断
 * - 加载后按视频宽高比调用 DisplayHelper：
 *     aspect > 1.2 → 应用窗口全屏 + 横向（折叠屏展开态除外）
 *     aspect <= 1.2 → 仅应用窗口全屏，保持竖屏
 * - 生命周期职责：
 *     aboutToAppear   → markFullscreen(true)，维护 Player 全屏状态标记
 *     aboutToDisappear → markFullscreen(false) + restoreToHost 归还节点给详情页
 * - 折叠屏适配：监听 foldStatusChange，设备折叠时自动退出全屏回详情页
 *
 * 注意：本页不释放 Player（释放由 VideoDetailPage 经 PlayerRepository.remove 负责）
 */
@Component
export struct VideoFullscreenPage {
  /** 播放器业务 id（bvid），经 PlayerRepository.get(id) 获取共享的 Player 实例 */
  @Prop playerId: string = ''
  @State playerVM: Player =
    PlayerRepository.get(this.playerId) ?? PlayerRepository.create(this.playerId)
  /** 视频渲染节点控制器：与详情页共享同一节点（Surface 不销毁，播放零中断） */
  @State nodeController: VideoNodeController = VideoNodeController.get(this.playerId);
  /** 折叠屏状态监听回调（aboutToDisappear 时反注册） */
  private foldCallback: Callback<display.FoldStatus> | null = null;

  aboutToAppear(): void {
    this.playerVM.attachUIContext(this.getUIContext());
    // 维护 Player 全屏状态标记（修复：此前该状态从未被设置）
    this.playerVM.markFullscreen(true);
    // 视频宽高比就绪 → 通知 DisplayHelper 按方向应用全屏
    // 若 aspectRatio 已就绪（>0），回调会立即同步触发
    this.playerVM.setAspectRatioReady((aspect: number) => {
      DisplayHelper.applyFullscreenForVideo(aspect).catch((e: Object) => {
        Logger.error('Fullscreen', `applyFullscreenForVideo fail: ${JSON.stringify(e)}`);
      });
    });
    this.watchFoldStatus();
  }

  aboutToDisappear(): void {
    this.playerVM.markFullscreen(false);
    this.playerVM.setAspectRatioReady(null);
    // 节点迁移第二步：归还视频节点给详情页
    // （rebuild 触发详情页 NodeContainer 重新 makeNode 取回节点）
    this.nodeController.restoreToHost();
    // 反注册折叠屏监听
    if (this.foldCallback !== null) {
      try {
        display.off('foldStatusChange', this.foldCallback);
      } catch (e) {
        Logger.error('Fullscreen', `off foldStatusChange fail: ${JSON.stringify(e)}`);
      }
      this.foldCallback = null;
    }
  }

  /**
   * 折叠屏适配（参考官方横竖屏最佳实践）：
   * - 展开/半展开 → 折叠：折叠态外屏较窄，自动退出全屏回详情页继续播放
   * - 折叠 → 展开：DisplayHelper 在 applyFullscreenForVideo 中会按折叠状态重算方向
   */
  private watchFoldStatus(): void {
    try {
      this.foldCallback = (status: display.FoldStatus): void => {
        if (status === display.FoldStatus.FOLD_STATUS_FOLDED && this.playerVM.fullscreen) {
          Route.pop();
        }
      };
      display.on('foldStatusChange', this.foldCallback);
    } catch (e) {
      Logger.error('Fullscreen', `watchFoldStatus fail: ${JSON.stringify(e)}`);
    }
  }

  build() {
    NavDestination() {
      Stack() {
        // 渲染节点容器：makeNode 返回与详情页共享的 XComponent 节点（自动迁移挂载）
        NodeContainer(this.nodeController)
          .width('100%')
          .height('100%')

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
          Route.pop();
        })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Black)
    }
    .hideTitleBar(true)
  }
}
