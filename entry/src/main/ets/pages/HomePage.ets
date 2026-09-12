import { DataStatus } from '../common/state/DataState';
import { Route } from '../framework/Route';
import { VideoCard } from '../models/VideoCard';
import { HomeViewModel } from '../viewmodel/HomeViewModel';
import { VideoCardView } from '../common/components/VideoCardView';
import { EmptyView, ErrorView, LoadingView } from '../common/components/StateViews';
import { AppColors } from '../theme/AppTheme';
import { IndexViewModel } from '../viewmodel/IndexViewModel';
import { LiveTabContent } from './LivePage';
import { BangumiIndexContent } from './BangumiPage';
import { MusicTabContent } from './MusicPage';
import { hilog } from '@kit.PerformanceAnalysisKit';

/** 搜索排默认高度（vp） */
const SEARCH_BAR_HEIGHT = 44;
/** 滚动触发阈值（vp）：超过视为有效上滑/回拉 */
const SCROLL_EPSILON = 2;

/**
 * 推荐/热门 feed 内容（每个 tab 独立实例：独立 VM、独立列表与滚动位置）
 */
@Component
struct FeedTab {
  /** feed 模式：recommend 推荐 / popular 热门 */
  mode: 'recommend' | 'popular' = 'recommend';
  /** 滚动回调（转发给宿主页面，驱动搜索排收起/底部栏显隐） */
  onScrollAction?: (offset: number, state: ScrollState) => void;
  @State vm: HomeViewModel = new HomeViewModel();
  @Consume(IndexViewModel.name) indexVm: IndexViewModel;
  @State refreshing: boolean = false;

  aboutToAppear(): void {
    const ctx = this.getUIContext().getHostContext();
    if (ctx !== undefined) {
      this.vm.init(ctx);
    }
    this.vm.mode = this.mode;
    if (this.vm.feedState.status === DataStatus.Idle) {
      this.vm.loadFirst();
    }
  }

  build() {
    Column() {
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
          List({ space: 8, spaceWidth: 8 }) {
            ForEach(this.vm.items, (item: VideoCard, index: number) => {
              ListItem() {
                VideoCardView({
                  card: item,
                  onCardClick: (bvid: string) => {
                    Route.push(Route.video, bvid);
                  }
                })
              }
            }, (item: VideoCard, index: number) => `${item.bvid}_${index}`)
          }
          .scrollBar(BarState.Off)
          .onDidScroll((offset: number, state: ScrollState) => {
            this.onScrollAction?.(offset, state);
          })
          .lanes(this.indexVm.gridColumns())
          .width('100%')
          .height('100%')
          .padding({ left: 8, right: 8 })
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
  }
}

/** 首页分区 tab 项 */
interface HomeTabItem {
  key: string;
  label: Resource;
}

/**
 * 首页（Task 6）：分区 tabs + 视频流。
 *
 * 布局参考 B 站原版首页：
 * - 顶部搜索排（点击跳搜索页）；下滑收起、上滑恢复（与底部导航栏显隐联动）
 * - 分区 tabs：直播 / 推荐 / 热门 / 看番 / 音乐，支持左右滑动切换 + 点击切换，
 *   各分区内容为独立 tab 页（非跳转新页面）
 * - tab 内容懒加载：首次切到该 tab 时才构建并请求数据
 */
@Component
export struct HomePage {
  @Consume(IndexViewModel.name) indexVm: IndexViewModel;
  /** 搜索排是否展开（下滑收起、上滑恢复） */
  @State searchBarExpanded: boolean = true;
  /** 当前选中 tab 下标（默认推荐） */
  @State currentTab: number = 1;
  /** 各 tab 是否已加载（懒加载：首次切到才构建内容） */
  @State loadedTabs: boolean[] = [false, true, false, false, false];

  /** 分区 tabs 定义（直播跳转放首位，对齐 B 站原版顺序） */
  private tabs(): HomeTabItem[] {
    return [
      { key: 'live', label: $r('app.string.home_tab_live') },
      { key: 'recommend', label: $r('app.string.home_tab_recommend') },
      { key: 'popular', label: $r('app.string.home_tab_popular') },
      { key: 'bangumi', label: $r('app.string.home_tab_bangumi') },
      { key: 'music', label: $r('app.string.home_tab_music') }
    ];
  }

  /** 内容滚动：搜索排收起/展开 + 底部导航栏显隐（沿用 IndexViewModel 逻辑） */
  private handleScroll(offset: number, state: ScrollState): void {
    this.indexVm.onScroll(offset, state);
    if (offset > SCROLL_EPSILON && this.searchBarExpanded) {
      this.getUIContext().animateTo({ duration: 200, curve: Curve.EaseOut }, () => {
        this.searchBarExpanded = false;
      });
    } else if (offset < -SCROLL_EPSILON && !this.searchBarExpanded) {
      this.getUIContext().animateTo({ duration: 200, curve: Curve.EaseOut }, () => {
        this.searchBarExpanded = true;
      });
    }
  }

  /** 滚动回调透传（FeedTab / 各内容组件 → handleScroll） */
  private forwardScroll(offset: number, state: ScrollState): void {
    this.handleScroll(offset, state);
  }

  /** 切换 tab：更新选中下标并懒加载目标 tab（含相邻预加载，滑动体验更顺滑） */
  private switchTab(index: number): void {
    this.currentTab = index;
    this.markLoaded(index);
    hilog.info(0x0000, TAG, 'switch home tab to %{public}d', index);
  }

  /** 标记 tab 已加载（懒加载 + 相邻预加载） */
  private markLoaded(index: number): void {
    for (const i of [index - 1, index, index + 1]) {
      if (i >= 0 && i < this.loadedTabs.length && !this.loadedTabs[i]) {
        this.loadedTabs[i] = true;
      }
    }
  }

  build() {
    NavDestination() {
      Column() {
        Blank().height(5)
        // 搜索排：下滑收起（高度/透明度动画），上滑恢复
        Row() {
          Search({
            placeholder: $r('app.string.home_search_hint')
          })
            .focusable(false)
            .onClick(() => {
              Route.push(Route.search);
            })
        }
        .padding({ left: 8, right: 8 })
        .width('100%')
        .height(this.searchBarExpanded ? SEARCH_BAR_HEIGHT : 0)
        .opacity(this.searchBarExpanded ? 1 : 0)
        .clip(true)

        // 分区 tab 栏：横向可滚动，选中项品牌色 + 底部指示条（点击切换）
        Scroll() {
          Row({ space: 4 }) {
            ForEach(this.tabs(), (tab: HomeTabItem, index: number) => {
              Column({ space: 2 }) {
                Text(tab.label)
                  .fontSize(15)
                  .fontWeight(this.currentTab === index ? FontWeight.Bold : FontWeight.Normal)
                  .fontColor(this.currentTab === index ? AppColors.TEXT_PRIMARY : AppColors.TEXT_SECONDARY)
                // 选中指示条
                Text('')
                  .width(this.currentTab === index ? 18 : 0)
                  .height(3)
                  .borderRadius(2)
                  .backgroundColor(AppColors.BRAND)
              }
              .padding({ left: 10, right: 10, top: 6, bottom: 4 })
              .onClick(() => {
                this.switchTab(index);
              })
            }, (tab: HomeTabItem) => tab.key)
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')

        // 分区内容：Tabs 支持左右滑动切换（自带 tabBar 隐藏，用上方自定义 tab 栏）
        Tabs({ index: this.currentTab }) {
          // 直播
          TabContent() {
            if (this.loadedTabs[0]) {
              LiveTabContent({
                onScrollAction: (offset: number, state: ScrollState): void => {
                  this.forwardScroll(offset, state);
                }
              })
            }
          }
          // 推荐
          TabContent() {
            if (this.loadedTabs[1]) {
              FeedTab({
                mode: 'recommend',
                onScrollAction: (offset: number, state: ScrollState): void => {
                  this.forwardScroll(offset, state);
                }
              })
            }
          }
          // 热门
          TabContent() {
            if (this.loadedTabs[2]) {
              FeedTab({
                mode: 'popular',
                onScrollAction: (offset: number, state: ScrollState): void => {
                  this.forwardScroll(offset, state);
                }
              })
            }
          }
          // 看番
          TabContent() {
            if (this.loadedTabs[3]) {
              BangumiIndexContent({
                onScrollAction: (offset: number, state: ScrollState): void => {
                  this.forwardScroll(offset, state);
                }
              })
            }
          }
          // 音乐
          TabContent() {
            if (this.loadedTabs[4]) {
              MusicTabContent({
                onScrollAction: (offset: number, state: ScrollState): void => {
                  this.forwardScroll(offset, state);
                }
              })
            }
          }
        }
        .barHeight(0)
        .scrollable(true)
        .layoutWeight(1)
        .onChange((index: number) => {
          // 滑动切换：同步选中下标 + 懒加载
          this.currentTab = index;
          this.markLoaded(index);
        })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppColors.PAGE_BG)
    }
    .hideTitleBar(true)
  }
}

// 日志 TAG（规范：统一定义在文件最下方）
const TAG = HomePage.name ?? 'HomePage';
