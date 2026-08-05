import { DataStatus } from '../common/state/DataState';
import { NavService } from '../common/navigation/NavService';
import { TopicItem } from '../models/TopicModels';
import { TopicViewModel } from '../viewmodel/TopicViewModel';
import { EmptyView, ErrorView, LoadingView } from '../common/components/StateViews';
import { AppColors } from '../theme/AppTheme';
import { RouteNames } from './RouteNames';
import { TopicFeedParam } from './RouteParams';

/**
 * 话题广场（P2 Task 18）：推荐话题列表，点击进入话题动态流。
 */
@Component
export struct TopicPage {
  @State vm: TopicViewModel = new TopicViewModel();

  aboutToAppear(): void {
    this.vm.loadTopics();
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
        Text('话题广场')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY)
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 8, right: 12, top: 8, bottom: 4 })

      if (this.vm.topicState.status === DataStatus.Loading) {
        LoadingView()
          .layoutWeight(1)
      } else if (this.vm.topicState.status === DataStatus.Error) {
        ErrorView({
          message: this.vm.errorMessage,
          retryable: true,
          onRetry: () => {
            this.vm.loadTopics();
          }
        })
          .layoutWeight(1)
      } else if (this.vm.topicState.status === DataStatus.Empty) {
        EmptyView({ tip: '暂无话题' })
          .layoutWeight(1)
      } else {
        List({ space: 10 }) {
          ForEach(this.vm.topics, (topic: TopicItem) => {
            ListItem() {
              Column({ space: 6 }) {
                Row({ space: 10 }) {
                  if (topic.cover.length > 0) {
                    Image(topic.cover)
                      .width(48)
                      .height(48)
                      .borderRadius(24)
                      .objectFit(ImageFit.Cover)
                      .alt($r('app.media.startIcon'))
                  }
                  Column({ space: 3 }) {
                    Text(`# ${topic.topicName}`)
                      .fontSize(15)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(AppColors.TEXT_PRIMARY)
                    if (topic.desc.length > 0) {
                      Text(topic.desc)
                        .fontSize(12)
                        .fontColor(AppColors.TEXT_SECONDARY)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                    }
                    Text(`${topic.discussCount}讨论`)
                      .fontSize(11)
                      .fontColor(AppColors.TEXT_SECONDARY)
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                }
                .width('100%')
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .padding(12)
              .backgroundColor(AppColors.CARD_BG)
              .borderRadius(10)
              .onClick(() => {
                const p: TopicFeedParam = { topicId: topic.topicId, topicName: topic.topicName };
                NavService.push(RouteNames.TOPIC_FEED, p);
              })
            }
          }, (topic: TopicItem) => `${topic.topicId}`)
        }
        .padding(8)
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.PAGE_BG)
  }
}
