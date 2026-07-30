import { DataStatus } from '../common/state/DataState';
import { NavService } from '../common/navigation/NavService';
import { VideoCard } from '../models/VideoCard';
import { HomeViewModel } from '../viewmodel/HomeViewModel';
import { VideoCardView } from '../common/components/VideoCardView';
import { EmptyView, ErrorView, LoadingView } from '../common/components/StateViews';
import { AppColors, gridColumns } from '../theme/AppTheme';
import { RouteNames } from './RouteNames';

/**
 * 首页（Task 6）：推荐视频流，下拉刷新/上拉分页，卡片点击跳视频页。
 */
@Component
export struct HomePage {
  @State vm: HomeViewModel = new HomeViewModel();
  @State refreshing: boolean = false;
  @State areaWidth: number = 360;

  aboutToAppear(): void {
    const ctx = this.getUIContext().getHostContext();
    if (ctx !== undefined) {
      this.vm.init(ctx);
    }
    if (this.vm.feedState.status === DataStatus.Idle) {
      this.vm.loadFirst();
    }
  }

  build() {
    Column() {
      // 顶部栏
      Row() {
        Text('推荐')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY)
        Blank()
        Text(this.vm.mode === 'recommend' ? '推荐流' : '热门榜')
          .fontSize(13)
          .fontColor(AppColors.BRAND)
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .borderRadius(12)
          .border({ width: 1, color: AppColors.BRAND })
          .onClick(() => {
            this.vm.mode = this.vm.mode === 'recommend' ? 'popular' : 'recommend';
            this.vm.loadFirst();
          })
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })

      // 内容区
      if (this.vm.feedState.status === DataStatus.Loading) {
        LoadingView()
          .layoutWeight(1)
      } else if (this.vm.feedState.status === DataStatus.Error && this.vm.items.length === 0) {
        ErrorView({
          message: this.vm.feedState.error?.message ?? '加载失败',
          retryable: this.vm.feedState.error?.retryable ?? true,
          onRetry: () => {
            this.vm.loadFirst();
          }
        })
          .layoutWeight(1)
      } else if (this.vm.feedState.status === DataStatus.Empty) {
        EmptyView({ tip: '没有推荐内容' })
          .layoutWeight(1)
      } else {
        Refresh({ refreshing: $$this.refreshing }) {
          WaterFlow() {
            ForEach(this.vm.items, (item: VideoCard, index: number) => {
              FlowItem() {
                VideoCardView({
                  card: item,
                  onCardClick: (bvid: string) => {
                    NavService.push(RouteNames.VIDEO_DETAIL, bvid);
                  }
                })
              }
            }, (item: VideoCard, index: number) => `${item.bvid}_${index}`)
          }
          .columnsTemplate(this.columnsTemplate())
          .columnsGap(8)
          .rowsGap(8)
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
    .onAreaChange((_old: Area, area: Area) => {
      this.areaWidth = Number(area.width) / 1;
    })
  }

  /** 响应式列数（手机2/折叠3/平板4，AP-6） */
  private columnsTemplate(): string {
    // area.width 单位为 vp（ArkUI Area 返回 vp）
    const cols = gridColumns(this.areaWidth);
    if (cols === 4) {
      return '1fr 1fr 1fr 1fr';
    }
    if (cols === 3) {
      return '1fr 1fr 1fr';
    }
    return '1fr 1fr';
  }
}
