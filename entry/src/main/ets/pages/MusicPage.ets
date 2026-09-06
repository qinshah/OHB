import { DataStatus } from '../common/state/DataState';
import { Route } from '../framework/Route';
import { VideoCard } from '../models/VideoCard';
import { MusicViewModel } from '../viewmodel/MusicViewModel';
import { VideoCardView } from '../common/components/VideoCardView';
import { EmptyView, ErrorView, LoadingView } from '../common/components/StateViews';
import { AppColors } from '../theme/AppTheme';

/**
 * 音乐页（P2 Task 20）：音乐分区排行，点击进入视频播放（MediaSession 由播放器统一提供）。
 *
 * 拆分为两个组件：
 * - MusicTabContent：内容主体（音乐视频瀑布流），可嵌入首页 Tabs
 * - MusicPage：NavDestination 包装（独立路由跳转用，带返回标题栏）
 */
@Component
export struct MusicTabContent {
  @State vm: MusicViewModel = new MusicViewModel();
  /** 滚动回调（转发给宿主页面，驱动搜索排收起/底部栏显隐） */
  onScrollAction?: (offset: number, state: ScrollState) => void;

  aboutToAppear(): void {
    this.vm.load();
  }

  build() {
    Column() {
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
                  Route.push(Route.video, bvid);
                }
              })
            }
          }, (item: VideoCard) => item.bvid)
        }
        .columnsTemplate('1fr 1fr')
        .columnsGap(8)
        .rowsGap(8)
        .padding(8)
        .scrollBar(BarState.Off)
        .onDidScroll((offset: number, state: ScrollState) => {
          this.onScrollAction?.(offset, state);
        })
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.PAGE_BG)
  }
}

/** 独立路由页包装（带返回标题栏） */
@Component
export struct MusicPage {
  build() {
    NavDestination() {
      Column() {
        // 标题栏
        Row() {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(20)
            .fontColor([AppColors.TEXT_PRIMARY])
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

        // 内容主体
        MusicTabContent()
          .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
  }
}
