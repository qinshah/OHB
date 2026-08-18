import { DataStatus } from '../common/state/DataState';
import { Route } from '../framework/Route';
import { VideoCard } from '../models/VideoCard';
import { MusicViewModel } from '../viewmodel/MusicViewModel';
import { VideoCardView } from '../common/components/VideoCardView';
import { EmptyView, ErrorView, LoadingView } from '../common/components/StateViews';
import { AppColors } from '../theme/AppTheme';

/**
 * 音乐页（P2 Task 20）：音乐分区排行，点击进入视频播放（MediaSession 由播放器统一提供）。
 */
@Component
export struct MusicPage {
  @State vm: MusicViewModel = new MusicViewModel();

  aboutToAppear(): void {
    this.vm.load();
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
        Text('音乐')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY)
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 8, right: 12, top: 8, bottom: 4 })

      if (this.vm.state.status === DataStatus.Loading) {
        LoadingView()
          .layoutWeight(1)
      } else if (this.vm.state.status === DataStatus.Error) {
        ErrorView({
          message: this.vm.errorMessage,
          retryable: true,
          onRetry: () => {
            this.vm.load();
          }
        })
          .layoutWeight(1)
      } else if (this.vm.state.status === DataStatus.Empty) {
        EmptyView({ tip: '暂无音乐内容' })
          .layoutWeight(1)
      } else {
        WaterFlow() {
          ForEach(this.vm.items, (item: VideoCard) => {
            FlowItem() {
              VideoCardView({
                card: item,
                onCardClick: (bvid: string) => {
                  Route.push(Route.videoDetail, bvid);
                }
              })
            }
          }, (item: VideoCard) => item.bvid)
        }
        .columnsTemplate('1fr 1fr')
        .columnsGap(8)
        .rowsGap(8)
        .padding(8)
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.PAGE_BG)
  }
}
