import { DataStatus } from '../common/state/DataState';
import { Route } from '../framework/Route';
import { VideoCard } from '../models/VideoCard';
import { HomeViewModel } from '../viewmodel/HomeViewModel';
import { VideoCardView } from '../common/components/VideoCardView';
import { EmptyView, ErrorView, LoadingView } from '../common/components/StateViews';
import { AppColors } from '../theme/AppTheme';
import { IndexViewModel } from '../viewmodel/IndexViewModel';
import { hilog } from '@kit.PerformanceAnalysisKit';

/** 搜索排默认高度（vp） */
const SEARCH_BAR_HEIGHT = 44;
/** 滚动触发阈值（vp）：超过视为有效上滑/回拉 */
const SCROLL_EPSILON = 2;

/** 首页分区 tab 定义 */
interface HomeTabItem {
  /** tab 标识 */
  key: string;
  /** 显示文案资源 */
  label: Resource;
  /** 点击行为：推荐/热门为内嵌 feed 切换，其余跳转对应页面 */
  onTap: () => void;
}

/**
 * 首页（Task 6）：分区 tabs + 推荐视频流。
 *
 * 布局参考 B 站原版首页：
 * - 顶部搜索排（点击跳搜索页）；下滑收起、上滑恢复（与底部导航栏显隐联动）
 * - 分区 tabs：直播 / 推荐 / 热门 / 番剧 / 音乐
 *   （推荐、热门为内嵌 feed 切换；直播/番剧/音乐跳转对应页面）
 * - 内容区：下拉刷新 / 上拉分页
 */
@Component
export struct HomePage {
  @State vm: HomeViewModel = new HomeViewModel();
  @Consume(IndexViewModel.name) indexVm: IndexViewModel;
  @State refreshing: boolean = false;
  /** 搜索排是否展开（下滑收起、上滑恢复） */
  @State searchBarExpanded: boolean = true;
  /** 当前选中 feed tab（recommend / popular），非 feed tab 点击后不驻留选中态 */
  @State activeFeed: string = 'recommend';

  aboutToAppear(): void {
    const ctx = this.getUIContext().getHostContext();
    if (ctx !== undefined) {
      this.vm.init(ctx);
    }
    if (this.vm.feedState.status === DataStatus.Idle) {
      this.vm.loadFirst();
    }
  }

  /** 分区 tabs（直播跳转放首位，对齐 B 站原版顺序） */
  private tabs(): HomeTabItem[] {
    return [
      {
        key: 'live',
        label: $r('app.string.home_tab_live'),
        onTap: () => {
          Route.push(Route.live);
        }
      },
      {
        key: 'recommend',
        label: $r('app.string.home_tab_recommend'),
        onTap: () => {
          this.switchFeed('recommend');
        }
      },
      {
        key: 'popular',
        label: $r('app.string.home_tab_popular'),
        onTap: () => {
          this.switchFeed('popular');
        }
      },
      {
        key: 'bangumi',
        label: $r('app.string.home_tab_bangumi'),
        onTap: () => {
          Route.push(Route.bangumi);
        }
      },
      {
        key: 'music',
        label: $r('app.string.home_tab_music'),
        onTap: () => {
          Route.push(Route.music);
        }
      }
    ];
  }

  /** 切换内嵌 feed（推荐/热门）：mode 变化时重载第一页 */
  private switchFeed(feed: string): void {
    if (this.activeFeed === feed) {
      return;
    }
    this.activeFeed = feed;
    this.vm.mode = feed === 'popular' ? 'popular' : 'recommend';
    this.vm.loadFirst();
    hilog.info(0x0000, TAG, 'switch feed to %{public}s', feed);
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

  build() {
    NavDestination() {
      Column() {
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

        // 分区 tabs：横向可滚动，选中项品牌色 + 底部指示条
        Scroll() {
          Row({ space: 4 }) {
            ForEach(this.tabs(), (tab: HomeTabItem) => {
              Column({ space: 2 }) {
                Text(tab.label)
                  .fontSize(15)
                  .fontWeight(this.activeFeed === tab.key ? FontWeight.Bold : FontWeight.Normal)
                  .fontColor(this.activeFeed === tab.key ? AppColors.TEXT_PRIMARY : AppColors.TEXT_SECONDARY)
                // 选中指示条
                Text('')
                  .width(this.activeFeed === tab.key ? 18 : 0)
                  .height(3)
                  .borderRadius(2)
                  .backgroundColor(AppColors.BRAND)
              }
              .padding({ left: 10, right: 10, top: 6, bottom: 4 })
              .onClick(() => {
                tab.onTap();
              })
            }, (tab: HomeTabItem) => tab.key)
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')

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
              this.handleScroll(offset, state);
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
      .backgroundColor(AppColors.PAGE_BG)
    }
    .hideTitleBar(true)
  }
}

// 日志 TAG（规范：统一定义在文件最下方）
const TAG = HomePage.name ?? 'HomePage';
