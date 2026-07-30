import { DataStatus } from '../common/state/DataState';
import { NavService } from '../common/navigation/NavService';
import { FormatUtils } from '../common/utils/FormatUtils';
import { VideoDetailViewModel } from '../viewmodel/VideoDetailViewModel';
import { PlayerController } from '../player/PlayerController';
import { EmptyView, ErrorView, LoadingView } from '../common/components/StateViews';
import { AppColors } from '../theme/AppTheme';
import { PlayerControlView } from './components/PlayerControlView';

/**
 * 视频详情页（Task 9）：播放器 + 标题 + UP主 + 简介（V1 基础布局）。
 */
@Component
export struct VideoDetailPage {
  @Prop bvid: string = '';
  @State vm: VideoDetailViewModel = new VideoDetailViewModel();
  @State controller: PlayerController = new PlayerController();
  @State descExpanded: boolean = false;
  private xcController: XComponentController = new XComponentController();

  aboutToAppear(): void {
    this.controller.attachUIContext(this.getUIContext());
    this.vm.bindPlayer(this.controller);
    if (this.bvid.length > 0) {
      this.vm.load(this.bvid);
    }
  }

  aboutToDisappear(): void {
    this.vm.release();
  }

  build() {
    Column() {
      // ===== 播放区 =====
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

        // 非全屏返回键
        if (!this.controller.isFullscreen) {
          Text('‹')
            .fontSize(24)
            .fontColor(Color.White)
            .width(40)
            .height(40)
            .textAlign(TextAlign.Center)
            .position({ x: 8, y: 8 })
            .onClick(() => {
              NavService.pop();
            })
        }
      }
      .width('100%')
      .height(this.controller.isFullscreen ? '100%' : undefined)
      .aspectRatio(this.controller.isFullscreen ? undefined : 16 / 9)
      .backgroundColor(Color.Black)

      // ===== 详情区（全屏时隐藏） =====
      if (!this.controller.isFullscreen) {
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
