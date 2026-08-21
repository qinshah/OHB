import { DataStatus } from '../common/state/DataState';
import { Route } from '../framework/Route';
import { FormatUtils } from '../common/utils/FormatUtils';
import { TopicFeedCard } from '../models/TopicModels';
import { TopicViewModel } from '../viewmodel/TopicViewModel';
import { EmptyView, ErrorView, LoadingView } from '../common/components/StateViews';
import { AppColors } from '../theme/AppTheme';
import { DynamicDetailParam } from './RouteParams';

/**
 * 话题动态流（P2 Task 18）。
 */
@Component
export struct TopicFeedPage {
  @Prop topicId: number = 0;
  @Prop topicName: string = '';
  @State vm: TopicViewModel = new TopicViewModel();

  aboutToAppear(): void {
    this.vm.loadFeedFirst(this.topicId);
  }

  build() {
    Column() {
      Row() {
        Text('‹')
          .fontSize(24)
          .fontColor(AppColors.TEXT_PRIMARY)
          .width(32)
          .onClick(() => {
            Route.pop();
          })
        Text(`# ${this.topicName}`)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 8, right: 12, top: 8, bottom: 4 })

      if (this.vm.feedState.status === DataStatus.Loading) {
        LoadingView()
          .layoutWeight(1)
      } else if (this.vm.feedState.status === DataStatus.Error && this.vm.feedItems.length === 0) {
        ErrorView({
          message: this.vm.errorMessage,
          retryable: true,
          onRetry: () => {
            this.vm.loadFeedFirst(this.topicId);
          }
        })
          .layoutWeight(1)
      } else if (this.vm.feedState.status === DataStatus.Empty) {
        EmptyView({ tip: '话题下暂无动态' })
          .layoutWeight(1)
      } else {
        List({ space: 8 }) {
          ForEach(this.vm.feedItems, (card: TopicFeedCard) => {
            ListItem() {
              this.FeedCard(card)
            }
          }, (card: TopicFeedCard) => card.idStr)
        }
        .padding(8)
        .onReachEnd(() => {
          this.vm.loadMoreFeed();
        })
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.PAGE_BG)
  }

  @Builder
  FeedCard(card: TopicFeedCard) {
    Column({ space: 6 }) {
      Row({ space: 8 }) {
        Image(card.upFace)
          .width(32)
          .height(32)
          .borderRadius(16)
          .alt($r('app.media.startIcon'))
        Column({ space: 2 }) {
          Text(card.upName)
            .fontSize(13)
            .fontColor(AppColors.TEXT_PRIMARY)
            .fontWeight(FontWeight.Medium)
          Text(FormatUtils.relativeTime(card.pubTs))
            .fontSize(11)
            .fontColor(AppColors.TEXT_SECONDARY)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')

      if (card.text.length > 0) {
        Text(card.text)
          .fontSize(14)
          .fontColor(AppColors.TEXT_PRIMARY)
          .width('100%')
          .maxLines(4)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }

      if (card.images.length > 0) {
        Row({ space: 4 }) {
          ForEach(card.images.slice(0, 3), (img: string) => {
            Image(img)
              .width(100)
              .height(100)
              .borderRadius(6)
              .objectFit(ImageFit.Cover)
              .alt($r('app.media.startIcon'))
          }, (img: string) => img)
        }
        .width('100%')
      }

      if (card.videoBvid.length > 0) {
        Row({ space: 8 }) {
          Image(card.videoCover)
            .width(100)
            .height(62)
            .borderRadius(6)
            .objectFit(ImageFit.Cover)
            .alt($r('app.media.startIcon'))
          Text(card.videoTitle)
            .fontSize(13)
            .fontColor(AppColors.TEXT_PRIMARY)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
        .width('100%')
      }

      Text(`${card.likeCount}赞`)
        .fontSize(11)
        .fontColor(AppColors.TEXT_SECONDARY)
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(10)
    .backgroundColor(AppColors.CARD_BG)
    .borderRadius(10)
    .onClick(() => {
      if (card.videoBvid.length > 0) {
        Route.push(Route.video, card.videoBvid);
      } else {
        const p: DynamicDetailParam = { id: card.idStr };
        Route.push(Route.dynamicDetail, p);
      }
    })
  }
}
