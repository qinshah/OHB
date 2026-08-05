import { DataStatus } from '../common/state/DataState';
import { NavService } from '../common/navigation/NavService';
import { BangumiItem } from '../models/BangumiModels';
import { BangumiViewModel } from '../viewmodel/BangumiViewModel';
import { EmptyView, ErrorView, LoadingView } from '../common/components/StateViews';
import { AppColors } from '../theme/AppTheme';
import { RouteNames } from './RouteNames';
import { BangumiDetailParam } from './RouteParams';

/** 排序选项 */
const ORDER_OPTIONS: BangumiOrderOption[] = [
  { label: '综合排序', value: 0 },
  { label: '最新', value: 1 },
  { label: '最多追番', value: 2 },
  { label: '最高评分', value: 3 }
];

class BangumiOrderOption {
  label: string = '';
  value: number = 0;
}

/**
 * 番剧页（P2 Task 20）：排行榜 / 索引。
 */
@Component
export struct BangumiPage {
  @State vm: BangumiViewModel = new BangumiViewModel();
  @State currentTabIdx: number = 0;
  @State orderIndex: number = 0;

  aboutToAppear(): void {
    this.vm.loadRank(1, 3);
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
        Text('番剧')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY)
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 8, right: 12, top: 8, bottom: 4 })

      Tabs({ index: $$this.currentTabIdx }) {
        TabContent() {
          this.RankList()
        }
        .tabBar('排行榜')

        TabContent() {
          this.IndexList()
        }
        .tabBar('索引')
      }
      .barHeight(40)
      .layoutWeight(1)
      .onChange((idx: number) => {
        this.currentTabIdx = idx;
        if (idx === 0) {
          this.vm.loadRank(1, 3);
        } else {
          this.vm.loadIndexFirst(1, ORDER_OPTIONS[this.orderIndex].value, 0);
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.PAGE_BG)
  }

  @Builder
  RankList() {
    Column() {
      if (this.vm.rankState.status === DataStatus.Loading) {
        LoadingView()
          .layoutWeight(1)
      } else if (this.vm.rankState.status === DataStatus.Error) {
        ErrorView({
          message: this.vm.errorMessage,
          retryable: true,
          onRetry: () => {
            this.vm.loadRank(1, 3);
          }
        })
          .layoutWeight(1)
      } else if (this.vm.rankState.status === DataStatus.Empty) {
        EmptyView({ tip: '暂无排行数据' })
          .layoutWeight(1)
      } else {
        List({ space: 8 }) {
          ForEach(this.vm.rankItems, (item: BangumiItem, index: number) => {
            ListItem() {
              this.BangumiRow(item, index)
            }
          }, (item: BangumiItem, index: number) => `${item.seasonId}_${index}`)
        }
        .padding(8)
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  IndexList() {
    Column() {
      // 排序筛选
      Row({ space: 8 }) {
        ForEach(ORDER_OPTIONS, (opt: BangumiOrderOption, idx: number) => {
          Text(opt.label)
            .fontSize(12)
            .fontColor(this.orderIndex === idx ? Color.White : AppColors.TEXT_SECONDARY)
            .backgroundColor(this.orderIndex === idx ? AppColors.BRAND : AppColors.CARD_BG)
            .borderRadius(12)
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .onClick(() => {
              this.orderIndex = idx;
              this.vm.loadIndexFirst(1, opt.value, 0);
            })
        }, (opt: BangumiOrderOption) => opt.label)
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 4, bottom: 4 })

      if (this.vm.indexState.status === DataStatus.Loading) {
        LoadingView()
          .layoutWeight(1)
      } else if (this.vm.indexState.status === DataStatus.Error && this.vm.indexItems.length === 0) {
        ErrorView({
          message: this.vm.errorMessage,
          retryable: true,
          onRetry: () => {
            this.vm.loadIndexFirst(1, ORDER_OPTIONS[this.orderIndex].value, 0);
          }
        })
          .layoutWeight(1)
      } else if (this.vm.indexState.status === DataStatus.Empty) {
        EmptyView({ tip: '暂无番剧' })
          .layoutWeight(1)
      } else {
        List({ space: 8 }) {
          ForEach(this.vm.indexItems, (item: BangumiItem, index: number) => {
            ListItem() {
              this.BangumiRow(item, index)
            }
          }, (item: BangumiItem, index: number) => `${item.seasonId}_${index}`)
        }
        .padding(8)
        .onReachEnd(() => {
          this.vm.loadMoreIndex();
        })
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  BangumiRow(item: BangumiItem, index: number) {
    Row({ space: 10 }) {
      Text(`${index + 1}`)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(index < 3 ? AppColors.BRAND : AppColors.TEXT_SECONDARY)
        .width(24)
      Image(item.cover)
        .width(96)
        .height(128)
        .borderRadius(6)
        .objectFit(ImageFit.Cover)
        .alt($r('app.media.startIcon'))
      Column({ space: 5 }) {
        Text(item.title)
          .fontSize(15)
          .fontColor(AppColors.TEXT_PRIMARY)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (item.score > 0) {
          Text(`评分 ${item.score.toFixed(1)}`)
            .fontSize(12)
            .fontColor(AppColors.BRAND)
        }
        if (item.indexShow.length > 0) {
          Text(item.indexShow)
            .fontSize(12)
            .fontColor(AppColors.TEXT_SECONDARY)
        }
        Text(item.typeName)
          .fontSize(11)
          .fontColor(AppColors.TEXT_SECONDARY)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding(8)
    .backgroundColor(AppColors.CARD_BG)
    .borderRadius(10)
    .onClick(() => {
      const p: BangumiDetailParam = { seasonId: item.seasonId };
      NavService.push(RouteNames.BANGUMI_DETAIL, p);
    })
  }
}
