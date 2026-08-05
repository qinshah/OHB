import { DataStatus } from '../common/state/DataState';
import { NavService } from '../common/navigation/NavService';
import { HistoryItem } from '../models/HistoryModels';
import { WatchLaterViewModel } from '../viewmodel/WatchLaterViewModel';
import { EmptyView, ErrorView, LoadingView } from '../common/components/StateViews';
import { AppColors } from '../theme/AppTheme';
import { RouteNames } from './RouteNames';

/**
 * 稍后再看页（P2 Task 16）：列表、移除、清空。
 */
@Component
export struct WatchLaterPage {
  @State vm: WatchLaterViewModel = new WatchLaterViewModel();

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
            NavService.pop();
          })
        Text('稍后再看')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY)
          .layoutWeight(1)
        Text('清空')
          .fontSize(13)
          .fontColor(AppColors.TEXT_SECONDARY)
          .onClick(() => {
            this.vm.clear();
          })
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
        EmptyView({ tip: '暂无稍后再看内容' })
          .layoutWeight(1)
      } else {
        List({ space: 8 }) {
          ForEach(this.vm.items, (item: HistoryItem) => {
            ListItem() {
              Row({ space: 10 }) {
                Image(item.cover)
                  .width(140)
                  .height(84)
                  .borderRadius(8)
                  .objectFit(ImageFit.Cover)
                  .alt($r('app.media.startIcon'))
                Column({ space: 4 }) {
                  Text(item.title)
                    .fontSize(14)
                    .fontColor(AppColors.TEXT_PRIMARY)
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(item.ownerName)
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
                    this.vm.remove(item);
                  })
              }
              .width('100%')
              .padding(8)
              .backgroundColor(AppColors.CARD_BG)
              .borderRadius(10)
              .onClick(() => {
                NavService.push(RouteNames.VIDEO_DETAIL, item.bvid);
              })
            }
          }, (item: HistoryItem) => `${item.aid}`)
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
