import { DataStatus } from '../common/state/DataState';
import { NavService } from '../common/navigation/NavService';
import { FormatUtils } from '../common/utils/FormatUtils';
import { FavoriteMedia } from '../models/FavoriteModels';
import { FavoriteViewModel } from '../viewmodel/FavoriteViewModel';
import { EmptyView, ErrorView, LoadingView } from '../common/components/StateViews';
import { AppColors } from '../theme/AppTheme';
import { RouteNames } from './RouteNames';

/**
 * 收藏夹详情（P2 Task 16）：收藏内视频分页、移除、跳转视频页。
 */
@Component
export struct FavoriteDetailPage {
  @Prop mediaId: number = 0;
  @Prop title: string = '';
  @State vm: FavoriteViewModel = new FavoriteViewModel();

  aboutToAppear(): void {
    this.vm.loadMediaFirst(this.mediaId);
  }

  build() {
    Column() {
      Row() {
        Text('‹')
          .fontSize(24)
          .fontColor(AppColors.TEXT_PRIMARY)
          .width(32)
          .onClick(() => {
            NavService.pop();
          })
        Text(this.title)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 8, right: 12, top: 8, bottom: 4 })

      if (this.vm.tipText.length > 0) {
        Text(this.vm.tipText)
          .fontSize(12)
          .fontColor(AppColors.BRAND)
          .width('100%')
          .padding({ left: 12, right: 12 })
      }

      if (this.vm.mediaState.status === DataStatus.Loading) {
        LoadingView()
          .layoutWeight(1)
      } else if (this.vm.mediaState.status === DataStatus.Error && this.vm.medias.length === 0) {
        ErrorView({
          message: this.vm.errorMessage,
          retryable: true,
          onRetry: () => {
            this.vm.loadMediaFirst(this.mediaId);
          }
        })
          .layoutWeight(1)
      } else if (this.vm.mediaState.status === DataStatus.Empty) {
        EmptyView({ tip: '收藏夹是空的' })
          .layoutWeight(1)
      } else {
        List({ space: 8 }) {
          ForEach(this.vm.medias, (media: FavoriteMedia) => {
            ListItem() {
              this.MediaRow(media)
            }
          }, (media: FavoriteMedia) => `${media.id}`)
        }
        .padding(8)
        .onReachEnd(() => {
          this.vm.loadMoreMedia();
        })
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.PAGE_BG)
  }

  @Builder
  MediaRow(media: FavoriteMedia) {
    Row({ space: 10 }) {
      Stack({ alignContent: Alignment.BottomEnd }) {
        Image(media.cover)
          .width(140)
          .height(84)
          .borderRadius(8)
          .objectFit(ImageFit.Cover)
          .alt($r('app.media.startIcon'))
        if (media.duration > 0) {
          Text(FormatUtils.duration(media.duration))
            .fontSize(10)
            .fontColor(Color.White)
            .backgroundColor('#99000000')
            .borderRadius(4)
            .padding({ left: 4, right: 4, top: 1, bottom: 1 })
            .margin(4)
        }
      }
      .width(140)
      .height(84)

      Column({ space: 4 }) {
        Text(media.title)
          .fontSize(14)
          .fontColor(AppColors.TEXT_PRIMARY)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${FormatUtils.count(media.playCount)}播放 · ${media.ownerName}`)
          .fontSize(11)
          .fontColor(AppColors.TEXT_SECONDARY)
          .maxLines(1)
        Text(FormatUtils.relativeTime(media.favTime))
          .fontSize(11)
          .fontColor(AppColors.TEXT_SECONDARY)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text('移除')
        .fontSize(12)
        .fontColor(AppColors.TEXT_SECONDARY)
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .borderRadius(10)
        .border({ width: 1, color: AppColors.DIVIDER })
        .onClick(() => {
          this.vm.removeMedia(media);
        })
    }
    .width('100%')
    .padding(8)
    .backgroundColor(AppColors.CARD_BG)
    .borderRadius(10)
    .onClick(() => {
      NavService.push(RouteNames.VIDEO_DETAIL, media.bvid);
    })
  }
}
