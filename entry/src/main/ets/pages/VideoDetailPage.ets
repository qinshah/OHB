// [API 23+] 视频详情页
import { DataStatus } from '../common/state/DataState';
import { NavService } from '../common/navigation/NavService';
import { FormatUtils } from '../common/utils/FormatUtils';
import { VideoDetailViewModel } from '../viewmodel/VideoDetailViewModel';
import { PlayerControllerHolder } from '../player/PlayerControllerHolder';
import { EmptyView, ErrorView, LoadingView } from '../common/components/StateViews';
import { AppColors } from '../theme/AppTheme';
import { PlayerControlView } from './components/PlayerControlView';
import { RouteNames } from './RouteNames';

/**
 * 视频详情页（Task 9 重构）：播放器 + 标题 + UP主 + 简介（V1 基础布局）。
 *
 * 重构要点：
 * - 视频宽高比：XComponent 按控制器上报的视频尺寸渲染（aspectRatio）
 *   未就绪时回退 16:9
 * - 播放器实例由 VideoDetailViewModel 持有；全屏页经 PlayerControllerHolder 访问同一实例
 * - 全屏改为路由页：全屏期间本页条件渲染不挂载 XComponent（不渲染视频）
 * - 全屏状态通过 200ms 轮询驱动（不依赖 @Observed / onPageShow / onPageHide，
 *   这两者在本项目实测不可靠）；退出全屏后延迟重建 XComponent——
 *   换全新 XComponentController 强制生成新 surface，onLoad 重建播放器绑定并恢复进度
 * - 返回按钮使用 SDK SymbolGlyph 图标，不用 unicode ‹
 */
@Component
export struct VideoDetailPage {
  @Prop bvid: string = '';
  @State vm: VideoDetailViewModel = new VideoDetailViewModel();
  @State descExpanded: boolean = false;
  /** XComponent 挂载开关：全屏期间 false（不渲染视频），退出全屏后延迟置 true */
  @State xcReady: boolean = true;
  /** XComponent 重建代次：递增触发 build 重跑，读取全新 controller（强制新 surface） */
  @State xcEpoch: number = 0;
  /** isFullscreen 本地镜像（200ms 轮询同步，驱动条件渲染） */
  @State fsMirror: boolean = false;
  /**
   * XComponent 控制器（普通字段，build 时读取）：
   * 重建 surface 时更换全新实例，强制生成新节点与新 surface id
   * （复用旧 controller 会拿到失效 id → 黑屏）
   */
  private xcController: XComponentController = new XComponentController();
  /** 是否经历过全屏（用于退出后重建 surface） */
  private wasInFullscreen: boolean = false;
  /** 全屏状态轮询定时器 */
  private fsPollTimer: number = -1;
  /** 退出全屏后的延迟重建定时器 */
  private remountTimer: number = -1;
  /** surface id 就绪轮询（onLoad 未触发时的兜底重绑） */
  private sidPollTimer: number = -1;
  /** 本次挂载是否已完成 surface 重绑（防止 onLoad 与轮询重复重建） */
  private rebindDone: boolean = false;

  aboutToAppear(): void {
    this.vm.controller.attachUIContext(this.getUIContext());
    // 全屏按钮 → 跳转全屏路由页（共享 controller）
    this.vm.controller.setFullscreenToggle(() => {
      PlayerControllerHolder.setShared(this.vm.controller);
      NavService.push(RouteNames.VIDEO_FULLSCREEN);
    });
    // 轮询全屏状态：进入全屏卸载本页 XComponent，退出全屏延迟重建
    this.startFsPoll();
    if (this.bvid.length > 0) {
      this.vm.load(this.bvid);
    }
  }

  aboutToDisappear(): void {
    this.vm.controller.setFullscreenToggle(null);
    this.vm.controller.setAspectRatioReady(null);
    this.vm.controller.setSystemVolumeChange(null);
    this.cancelRemount();
    if (this.fsPollTimer >= 0) {
      clearInterval(this.fsPollTimer);
      this.fsPollTimer = -1;
    }
    if (this.sidPollTimer >= 0) {
      clearInterval(this.sidPollTimer);
      this.sidPollTimer = -1;
    }
    this.vm.release();
  }

  /**
   * 200ms 轮询 isFullscreen（普通字段直读，不依赖 @Observed 观察与页面生命周期回调）：
   * - 进入全屏 → 卸载本页 XComponent（全屏期间不渲染视频）
   * - 退出全屏 → 延迟重建 XComponent（全新 controller + 重建播放器绑定新 surface）
   */
  private startFsPoll(): void {
    if (this.fsPollTimer >= 0) {
      return;
    }
    this.fsPollTimer = setInterval(() => {
      this.syncFullscreenState();
    }, 200);
  }

  private syncFullscreenState(): void {
    const fs = this.vm.controller.isFullscreen;
    if (fs === this.fsMirror) {
      return;
    }
    this.fsMirror = fs;
    if (fs) {
      // 进入全屏：本页不再渲染视频（卸载 XComponent）
      this.wasInFullscreen = true;
      this.xcReady = false;
      this.cancelRemount();
    } else if (this.wasInFullscreen) {
      // 退出全屏：延迟到窗口转场/方向还原完成后再重建 surface
      this.wasInFullscreen = false;
      this.cancelRemount();
      this.remountTimer = setTimeout(() => {
        this.remountVideoSurface();
      }, 300);
    }
  }

  /** 重建视频 surface：换全新 controller 强制新节点，挂载后重建播放器绑定 */
  private remountVideoSurface(): void {
    this.xcController = new XComponentController();
    this.xcEpoch++;
    this.rebindDone = false;
    this.xcReady = true;
    // 兜底：若 onLoad 未触发（节点被复用），轮询 surface id 就绪后重绑
    if (this.sidPollTimer >= 0) {
      clearInterval(this.sidPollTimer);
    }
    let tries = 0;
    this.sidPollTimer = setInterval(() => {
      tries++;
      const sid = this.xcController.getXComponentSurfaceId();
      if (sid.length > 0 && !this.rebindDone) {
        clearInterval(this.sidPollTimer);
        this.sidPollTimer = -1;
        this.doRebind(sid);
      } else if (tries >= 15) {
        clearInterval(this.sidPollTimer);
        this.sidPollTimer = -1;
      }
    }, 100);
  }

  /** 重建播放器并绑定 surface（幂等，onLoad 与轮询兜底只执行一次） */
  private doRebind(surfaceId: string): void {
    if (this.rebindDone || surfaceId.length === 0) {
      return;
    }
    this.rebindDone = true;
    if (this.sidPollTimer >= 0) {
      clearInterval(this.sidPollTimer);
      this.sidPollTimer = -1;
    }
    this.vm.controller.rebindSurface(surfaceId, this.vm.controller.positionMs);
  }

  private cancelRemount(): void {
    if (this.remountTimer >= 0) {
      clearTimeout(this.remountTimer);
      this.remountTimer = -1;
    }
  }

  build() {
    Column() {
      // ===== 播放区 =====
      Stack() {
        // 全屏期间不渲染视频；退出全屏后恢复渲染（onLoad 重建播放器绑定新 surface）
        if (!this.fsMirror && this.xcReady) {
          XComponent({
            type: XComponentType.SURFACE,
            controller: this.xcController
          })
            .onLoad(() => {
              this.doRebind(this.xcController.getXComponentSurfaceId());
            })
            .width('100%')
            .height('100%')
            .backgroundColor(Color.Black)
        }

        // 控制层
        PlayerControlView({ controller: this.vm.controller })
          .width('100%')
          .height('100%')

        // 播放地址错误覆盖层
        if (this.vm.playError.length > 0) {
          Column({ space: 10 }) {
            Text(this.vm.playError)
              .fontSize(13)
              .fontColor(Color.White)
            Button('重试')
              .backgroundColor(AppColors.BRAND)
              .fontColor(Color.White)
              .onClick(() => {
                this.vm.retryPlayUrl();
              })
          }
          .width('100%')
          .height('100%')
          .backgroundColor('#B3000000')
          .justifyContent(FlexAlign.Center)
        }

        // 返回键：SDK SymbolGlyph 图标，不用 ‹
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
        .position({ x: 8, y: 8 })
        .hitTestBehavior(HitTestMode.Block)
        .onClick(() => {
          NavService.pop();
        })
      }
      .width('100%')
      // 视频宽高比未就绪时回退 16:9
      .aspectRatio(this.vm.controller.aspectRatio > 0 ? this.vm.controller.aspectRatio : 16 / 9)
      .backgroundColor(Color.Black)

      // ===== 详情区 =====
      if (this.vm.detailState.status === DataStatus.Loading) {
        LoadingView()
          .layoutWeight(1)
      } else if (this.vm.detailState.status === DataStatus.Error) {
        ErrorView({
          message: this.vm.detailState.error?.message ?? '详情加载失败',
          retryable: true,
          onRetry: () => {
            this.vm.load(this.bvid);
          }
        })
          .layoutWeight(1)
      } else if (this.vm.detail !== null) {
        Scroll() {
          Column({ space: 12 }) {
            // 标题 + 播放数据
            Text(this.vm.detail.title)
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.TEXT_PRIMARY)
              .width('100%')
            Row({ space: 12 }) {
              Text(`${FormatUtils.count(this.vm.detail.view)}播放`)
                .fontSize(12)
                .fontColor(AppColors.TEXT_SECONDARY)
              Text(`${FormatUtils.count(this.vm.detail.danmaku)}弹幕`)
                .fontSize(12)
                .fontColor(AppColors.TEXT_SECONDARY)
              Text(FormatUtils.relativeTime(this.vm.detail.pubdate))
                .fontSize(12)
                .fontColor(AppColors.TEXT_SECONDARY)
              if (this.vm.playUrlInfo !== null) {
                Text(this.vm.playUrlInfo.qualityDesc)
                  .fontSize(12)
                  .fontColor(AppColors.BRAND)
              }
            }
            .width('100%')

            // UP 主行
            Row({ space: 10 }) {
              Image(this.vm.detail.ownerFace)
                .width(40)
                .height(40)
                .borderRadius(20)
                .alt($r('app.media.startIcon'))
              Text(this.vm.detail.ownerName)
                .fontSize(15)
                .fontColor(AppColors.TEXT_PRIMARY)
                .layoutWeight(1)
              Text('+ 关注')
                .fontSize(13)
                .fontColor(Color.White)
                .backgroundColor(AppColors.BRAND)
                .borderRadius(14)
                .padding({ left: 14, right: 14, top: 5, bottom: 5 })
            }
            .width('100%')
            .padding(10)
            .backgroundColor(AppColors.CARD_BG)
            .borderRadius(10)

            // 简介
            Column({ space: 4 }) {
              Text(this.vm.detail.desc.length > 0 ? this.vm.detail.desc : '暂无简介')
                .fontSize(13)
                .fontColor(AppColors.TEXT_SECONDARY)
                .width('100%')
                .maxLines(this.descExpanded ? 100 : 2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .onClick(() => {
                  this.descExpanded = !this.descExpanded;
                })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            // 分P列表
            if (this.vm.detail.pages.length > 1) {
              Text(`分P（${this.vm.detail.pages.length}）`)
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppColors.TEXT_PRIMARY)
                .width('100%')
              ForEach(this.vm.detail.pages, (p: VideoPageItem) => {
                Row() {
                  Text(`P${p.page}`)
                    .fontSize(13)
                    .fontColor(AppColors.BRAND)
                    .width(36)
                  Text(p.part)
                    .fontSize(13)
                    .fontColor(AppColors.TEXT_PRIMARY)
                    .layoutWeight(1)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(FormatUtils.duration(p.duration))
                    .fontSize(12)
                    .fontColor(AppColors.TEXT_SECONDARY)
                }
                .width('100%')
                .padding({ top: 6, bottom: 6 })
              }, (p: VideoPageItem) => `${p.page}`)
            }

            // 占位（V1 不做弹幕/三连/评论/相关）
            EmptyView({ tip: '弹幕 / 三连 / 评论 / 相关推荐 将在后续版本开放' })
              .height(120)
          }
          .width('100%')
          .padding(12)
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.PAGE_BG)
  }
}

/** 分P展示项（与 VideoDetail.pages 元素同构） */
interface VideoPageItem {
  cid: number;
  part: string;
  page: number;
  duration: number;
}
