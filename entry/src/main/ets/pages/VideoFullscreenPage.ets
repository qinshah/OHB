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
 *   PlayerRepository.get(id) 获取（在 aboutToAppear 中获取，保证 @Prop 已同步，
 *   修复初始化时序导致拿到空实例 → 方向回调失效、Surface 绑不上）
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
  /** 共享播放器实例（aboutToAppear 中获取；非响应式，本页 build 不直接绑定其状态） */
  private playerVM: Player | null = null;
  /** 视频渲染节点控制器：与详情页共享同一节点（Surface 不销毁，播放零中断） */
  private nodeController: VideoNodeController | null = null;
  /** 折叠屏状态监听回调（aboutToDisappear 时反注册） */
  private foldCallback: Callback<display.FoldStatus> | null = null;

  aboutToAppear(): void {
    // @Prop 此时必定已同步：按 playerId 获取共享实例与节点控制器
    this.playerVM = PlayerRepository.get(this.playerId) ?? PlayerRepository.create(this.playerId);
    this.nodeController = VideoNodeController.get(this.playerId);
    Logger.info('Fullscreen', `aboutToAppear playerId=${this.playerId}, playerVM.id=${this.playerVM.id}`);
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
    if (this.playerVM !== null) {
      this.playerVM.markFullscreen(false);
      this.playerVM.setAspectRatioReady(null);
    }
    // 节点归还：对齐官方最佳实践——退出全屏时不做任何主动节点操作！
    // 此处若主动 restoreToHost（rebuild），全屏页容器还存活会参与 makeNode 竞争、
    // 把节点抢回，随后随页面销毁被连带销毁 → 详情页黑屏。
    // 正确时序：全屏页容器销毁时框架自动触发 rebuild，详情页容器此时才
    // makeNode 拿回节点（官方 LandscapePlay 退出时同样不碰 nodeController）。
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
        if (status === display.FoldStatus.FOLD_STATUS_FOLDED &&
          this.playerVM !== null && this.playerVM.fullscreen) {
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
        if (this.nodeController !== null) {
          NodeContainer(this.nodeController)
            .width('100%')
            .height('100%')
        }

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
    // 页面完全销毁后归还节点（晚于容器销毁，此时无垂死容器竞争 makeNode）。
    // 实测在容器销毁回调（NodeController.aboutToDisappear）里 rebuild 会被
    // 垂死容器抢先响应抢走节点，详情页拿不到 → 黑屏；onDisAppear 是安全时机。
    .onDisAppear(() => {
      if (this.nodeController !== null) {
        this.nodeController.requestRestore();
      }
    })
  }
}
