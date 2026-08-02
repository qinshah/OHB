// [API 23+] 视频详情页
import { DataStatus } from '../common/state/DataState';
import { NavService } from '../common/navigation/NavService';
import { FormatUtils } from '../common/utils/FormatUtils';
import { VideoDetailViewModel } from '../viewmodel/VideoDetailViewModel';
import { PlayerController } from '../player/PlayerController';
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
 * - 全屏改为路由页：点击全屏按钮跳转 VideoFullscreenPage（共享 PlayerController）
 * - 返回按钮使用 SDK SymbolGlyph 图标，不用 unicode ‹
 * - onPageShow 时重新绑定 surface（从全屏页 pop 回来后恢复渲染）
 */
@Component
export struct VideoDetailPage {
  @Prop bvid: string = '';
  @State vm: VideoDetailViewModel = new VideoDetailViewModel();
  @State controller: PlayerController = new PlayerController();
  @State descExpanded: boolean = false;
  /** XComponent 挂载开关：从全屏返回时置 false 再置 true，强制重建以获取全新有效 surface */
  @State xcMounted: boolean = true;
  /** 是否进入过全屏页（返回时需要重建视频 surface，修复全屏返回黑屏） */
  private returningFromFullscreen: boolean = false;
  private xcController: XComponentController = new XComponentController();

  aboutToAppear(): void {
    this.controller.attachUIContext(this.getUIContext());
    this.vm.bindPlayer(this.controller);
    // 全屏按钮 → 跳转全屏路由页（共享 controller）
    this.controller.setFullscreenToggle(() => {
      this.returningFromFullscreen = true;
      PlayerControllerHolder.setShared(this.controller);
      NavService.push(RouteNames.VIDEO_FULLSCREEN);
    });
    if (this.bvid.length > 0) {
      this.vm.load(this.bvid);
    }
  }

  aboutToDisappear(): void {
    this.controller.setFullscreenToggle(null);
    this.controller.setAspectRatioReady(null);
    this.controller.setSystemVolumeChange(null);
    this.vm.release();
  }

  onPageShow(): void {
    // 从全屏页 pop 回来：旧 XComponent 的 surface 在全屏覆盖期间可能已失效，
    // 直接重绑旧 id 会黑屏（有声音无画面）。先卸载再重建，onLoad 会用全新 id 重绑。
    if (this.returningFromFullscreen || !this.xcMounted) {
      this.returningFromFullscreen = false;
      this.xcMounted = false;
      setTimeout(() => {
        this.xcMounted = true;
      }, 100);
    }
  }

  onPageHide(): void {
    // 页面被覆盖（进入全屏页等）：卸载 XComponent 释放 surface，避免持有失效 surface
    this.xcMounted = false;
  }

  build() {
    Column() {
      // ===== 播放区 =====
      Stack() {
        if (this.xcMounted) {
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
        }

        // 控制层
        PlayerControlView({ controller: this.controller })
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
      .aspectRatio(this.controller.aspectRatio > 0 ? this.controller.aspectRatio : 16 / 9)
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
