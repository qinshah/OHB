import { DataStatus } from '../common/state/DataState';
import { Route } from '../framework/Route';
import { FormatUtils } from '../common/utils/FormatUtils';
import { HistoryItem } from '../models/HistoryModels';
import { HistoryViewModel } from '../viewmodel/HistoryViewModel';
import { EmptyView, ErrorView, LoadingView } from '../common/components/StateViews';
import { AppColors } from '../theme/AppTheme';

/**
 * 历史记录页（P2 Task 16）：游标分页、删除、清空。
 */
@Component
export struct HistoryPage {
  @State vm: HistoryViewModel = new HistoryViewModel();

  aboutToAppear(): void {
    this.vm.loadFirst();
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
        Text('历史记录')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY)
          .layoutWeight(1)
        Text('清空')
          .fontSize(13)
          .fontColor(AppColors.TEXT_SECONDARY)
          .onClick(() => {
            this.vm.clearAll();
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
      } else if (this.vm.state.status === DataStatus.Error && this.vm.items.length === 0) {
        ErrorView({
          message: this.vm.errorMessage,
          retryable: true,
          onRetry: () => {
            this.vm.loadFirst();
          }
        })
          .layoutWeight(1)
      } else if (this.vm.state.status === DataStatus.Empty) {
        EmptyView({ tip: '暂无观看记录' })
          .layoutWeight(1)
      } else {
        List({ space: 8 }) {
          ForEach(this.vm.items, (item: HistoryItem) => {
            ListItem() {
              this.HistoryRow(item)
            }
          }, (item: HistoryItem) => item.kid)
        }
        .padding(8)
        .onReachEnd(() => {
          this.vm.loadMore();
        })
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.PAGE_BG)
  }

  @Builder
  HistoryRow(item: HistoryItem) {
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
        Text(`${item.ownerName} · ${FormatUtils.relativeTime(item.viewAt)}`)
          .fontSize(11)
          .fontColor(AppColors.TEXT_SECONDARY)
          .maxLines(1)
        if (item.progressText.length > 0) {
          Text(item.progressText)
            .fontSize(11)
            .fontColor(AppColors.BRAND)
            .maxLines(1)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text('删除')
        .fontSize(12)
        .fontColor(AppColors.TEXT_SECONDARY)
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .borderRadius(10)
        .border({ width: 1, color: AppColors.DIVIDER })
        .onClick(() => {
          this.vm.deleteItem(item);
        })
    }
    .width('100%')
    .padding(8)
    .backgroundColor(AppColors.CARD_BG)
    .borderRadius(10)
    .onClick(() => {
      Route.push(Route.video, item.bvid);
    })
  }
}
