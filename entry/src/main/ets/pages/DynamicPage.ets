import { DataStatus } from '../common/state/DataState';
import { NavService } from '../common/navigation/NavService';
import { FormatUtils } from '../common/utils/FormatUtils';
import { DynamicItem, DynamicKind } from '../models/DynamicItem';
import { DynamicViewModel } from '../viewmodel/DynamicViewModel';
import { EmptyView, ErrorView, LoadingView } from '../common/components/StateViews';
import { AppColors } from '../theme/AppTheme';
import { RouteNames } from './RouteNames';
import { DynamicDetailParam, UserSpaceParam } from './RouteParams';

/**
 * 动态页（Task 8）：关注动态流，下拉刷新/分页，视频动态跳视频页。
 */
@Component
export struct DynamicPage {
  @State vm: DynamicViewModel = new DynamicViewModel();
  @State refreshing: boolean = false;

  aboutToAppear(): void {
    if (this.vm.feedState.status === DataStatus.Idle) {
      this.vm.loadFirst();
    }
  }

  build() {
    Column() {
      Row() {
        Text('动态')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY)
        Blank()
        Text('话题')
          .fontSize(13)
          .fontColor(AppColors.TEXT_SECONDARY)
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .borderRadius(12)
          .border({ width: 1, color: AppColors.DIVIDER })
          .onClick(() => {
            NavService.push(RouteNames.TOPIC);
          })
        Text('发布')
          .fontSize(13)
          .fontColor(Color.White)
          .backgroundColor(AppColors.BRAND)
          .borderRadius(12)
          .padding({ left: 12, right: 12, top: 4, bottom: 4 })
          .margin({ left: 8 })
          .onClick(() => {
            NavService.push(RouteNames.PUBLISH_DYNAMIC);
          })
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })

      if (this.vm.feedState.status === DataStatus.Loading) {
        LoadingView()
          .layoutWeight(1)
      } else if (this.vm.feedState.isUnauthorized) {
        Column({ space: 12 }) {
          Text('登录后查看关注动态')
            .fontSize(15)
            .fontColor(AppColors.TEXT_PRIMARY)
          Button('去登录')
            .backgroundColor(AppColors.BRAND)
            .fontColor(Color.White)
            .onClick(() => {
              NavService.push(RouteNames.LOGIN);
            })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.vm.feedState.status === DataStatus.Error && this.vm.items.length === 0) {
        ErrorView({
          message: this.vm.feedState.error?.message ?? '加载失败',
          retryable: true,
          onRetry: () => {
            this.vm.loadFirst();
          }
        })
          .layoutWeight(1)
      } else if (this.vm.feedState.status === DataStatus.Empty) {
        EmptyView({ tip: '暂无动态' })
          .layoutWeight(1)
      } else {
        Refresh({ refreshing: $$this.refreshing }) {
          List({ space: 8 }) {
            ForEach(this.vm.items, (item: DynamicItem) => {
              ListItem() {
                this.DynamicCard(item)
              }
            }, (item: DynamicItem) => item.idStr)
          }
          .padding(8)
          .onReachEnd(() => {
            this.vm.loadMore();
          })
        }
        .onRefreshing(() => {
          this.refreshing = true;
          this.vm.refresh().finally(() => {
            this.refreshing = false;
          });
        })
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.PAGE_BG)
  }

  @Builder
  DynamicCard(item: DynamicItem) {
    Column({ space: 8 }) {
      // UP 主信息行
      Row({ space: 8 }) {
        Image(item.upFace)
          .width(36)
          .height(36)
          .borderRadius(18)
          .alt($r('app.media.startIcon'))
          .onClick(() => {
            const p: UserSpaceParam = { mid: item.upMid };
            NavService.push(RouteNames.USER_SPACE, p);
          })
        Column({ space: 2 }) {
          Text(item.upName)
            .fontSize(14)
            .fontColor(AppColors.TEXT_PRIMARY)
            .fontWeight(FontWeight.Medium)
          Text(FormatUtils.relativeTime(item.pubTs))
            .fontSize(11)
            .fontColor(AppColors.TEXT_SECONDARY)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .onClick(() => {
        const p: DynamicDetailParam = { id: item.idStr };
        NavService.push(RouteNames.DYNAMIC_DETAIL, p);
      })

      // 文本内容
      if (item.text.length > 0) {
        Text(item.text)
          .fontSize(14)
          .fontColor(AppColors.TEXT_PRIMARY)
          .width('100%')
          .maxLines(4)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }

      // 视频动态卡片
      if (item.kind === DynamicKind.Video && item.videoBvid.length > 0) {
        Column({ space: 6 }) {
          Stack({ alignContent: Alignment.BottomEnd }) {
            Image(item.videoCover)
              .width('100%')
              .aspectRatio(16 / 10)
              .objectFit(ImageFit.Cover)
              .borderRadius(8)
              .alt($r('app.media.startIcon'))
            if (item.videoDuration > 0) {
              Text(FormatUtils.duration(item.videoDuration))
                .fontSize(10)
                .fontColor(Color.White)
                .backgroundColor('#99000000')
                .borderRadius(4)
                .padding({ left: 4, right: 4, top: 1, bottom: 1 })
                .margin({ right: 6, bottom: 6 })
            }
          }
          Text(item.videoTitle)
            .fontSize(13)
            .fontColor(AppColors.TEXT_PRIMARY)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
          Text(`${FormatUtils.count(item.videoPlayCount)}播放 · ${FormatUtils.count(item.videoDanmakuCount)}弹幕`)
            .fontSize(11)
            .fontColor(AppColors.TEXT_SECONDARY)
            .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .onClick(() => {
          NavService.push(RouteNames.VIDEO_DETAIL, item.videoBvid);
        })
      }

      // 图文动态图片
      if (item.kind === DynamicKind.Article && item.images.length > 0) {
        Grid() {
          ForEach(item.images.slice(0, 9), (img: string) => {
            GridItem() {
              Image(img)
                .width('100%')
                .aspectRatio(1)
                .objectFit(ImageFit.Cover)
                .borderRadius(6)
            }
          }, (img: string) => img)
        }
        .columnsTemplate('1fr 1fr 1fr')
        .columnsGap(4)
        .rowsGap(4)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(AppColors.CARD_BG)
    .borderRadius(10)
    .padding(10)
  }
}
