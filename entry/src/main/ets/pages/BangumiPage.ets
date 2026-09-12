import { DataStatus } from '../common/state/DataState';
import { Route } from '../framework/Route';
import { BangumiConditionValue, BangumiEpisode, BangumiItem } from '../models/BangumiModels';
import { BangumiFilterRow, BangumiViewModel } from '../viewmodel/BangumiViewModel';
import { EmptyView, ErrorView, LoadingView } from '../common/components/StateViews';
import { AppColors } from '../theme/AppTheme';
import { BangumiDetailParam, VideoParam } from './RouteParams';
import { BangumiRepository } from '../data/repository/BangumiRepository';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { promptAction } from '@kit.ArkUI';

/** 卡片封面宽高比（3:4，对齐截图与 PiliPlus） */
const COVER_ASPECT: number = 0.75;
/** 卡片圆角 */
const CARD_RADIUS: number = 8;
/** 网格：左右留白 / 列间距 / 行间距（按截图实测换算） */
const GRID_PADDING: number = 13;
const GRID_COLUMN_GAP: number = 9;
const GRID_ROW_GAP: number = 10;
/** 左侧筛选胶囊最小宽度 */
const PILL_MIN_WIDTH: number = 76;
/** 覆盖层渐变（底部半透明黑，保证白字可读） */
const OVERLAY_CLEAR: string = '#00000000';
const OVERLAY_DARK: string = '#B3000000';

/**
 * 选入口剧集：优先索引接口给的 first_ep.ep_id（即 B 站 `ss` 链接的默认入口），
 * 缺失时回退季内第 1 集。只挑可播放的剧集（bvid 非空且 cid 有效）。
 */
function pickEntryEpisode(eps: BangumiEpisode[], firstEpId: number): BangumiEpisode | null {
  let fallback: BangumiEpisode | null = null;
  for (let i = 0; i < eps.length; i++) {
    const ep: BangumiEpisode = eps[i];
    if (ep.bvid.length === 0 || ep.cid <= 0) {
      continue;
    }
    if (firstEpId > 0 && ep.epId === firstEpId) {
      return ep;
    }
    if (fallback === null) {
      fallback = ep;
    }
  }
  return fallback;
}

/**
 * 番剧索引内容（首页「看番」tab / 独立索引页共用）。
 *
 * 版式参照截图：顶部筛选条件区（左「当前选中项」胶囊 + 右候选项横向滚动，
 * 折叠 5 行 + 「更多筛选」），下方三列卡片网格（封面角标 / 更新状态 / 评分 / 标题 / 副标题）。
 * 交互与数据流参照 PiliPlus PgcIndexController。
 */
@Component
export struct BangumiIndexContent {
  @State vm: BangumiViewModel = new BangumiViewModel();
  /** 正在解析入口剧集的季号（0 = 空闲；用于防连点 + 卡片按压反馈） */
  @State openingSeasonId: number = 0;
  /** 滚动回调（转发给宿主页面，驱动搜索排收起/底部栏显隐） */
  onScrollAction?: (offset: number, state: ScrollState) => void;
  private repo: BangumiRepository = new BangumiRepository();

  aboutToAppear(): void {
    this.vm.loadCondition();
  }

  /**
   * 卡片点击 → 直接进视频页播放（不经过番剧详情页）。
   *
   * 索引接口只给 season_id 与 first_ep.ep_id，而视频页需要 bvid，
   * 故先按季取一次详情解析出入口剧集，再带上 seasonId 跳转；
   * 视频页会据此加载整季选集列表，复用其播放器/弹幕/全屏能力。
   * 季详情同时访问同一接口，第二次命中缓存开销可忽略。
   */
  private async playFromCard(item: BangumiItem): Promise<void> {
    if (this.openingSeasonId !== 0) {
      return;
    }
    this.openingSeasonId = item.seasonId;
    const r = await this.repo.getDetail(item.seasonId);
    this.openingSeasonId = 0;
    if (!r.isOk) {
      hilog.error(0x0000, TAG, 'open bangumi failed: %{public}s', r.error.message);
      promptAction.showToast({ message: r.error.message });
      return;
    }
    const target = pickEntryEpisode(r.value.episodes, item.firstEpId);
    if (target === null) {
      hilog.error(0x0000, TAG, 'no playable episode, seasonId=%{public}d', item.seasonId);
      promptAction.showToast({ message: $r('app.string.bangumi_no_episode') });
      return;
    }
    const p: VideoParam = { bvid: target.bvid, seasonId: item.seasonId };
    Route.push(Route.video, p);
  }

  /** 长按卡片 → 打开番剧详情（追番 / 简介 / 其他季） */
  private openDetail(item: BangumiItem): void {
    const p: BangumiDetailParam = { seasonId: item.seasonId };
    Route.push(Route.bangumiDetail, p);
  }

  build() {
    Column() {
      Grid() {
        // 筛选条件区：横跨三列，随列表一起滚动（对齐 PiliPlus CustomScrollView 结构）
        GridItem() {
          this.FilterPanel()
        }
        .columnStart(0)
        .columnEnd(2)

        if (this.vm.indexItems.length === 0) {
          GridItem() {
            this.ListStateView()
          }
          .columnStart(0)
          .columnEnd(2)
        } else {
          ForEach(this.vm.indexItems, (item: BangumiItem, index: number) => {
            GridItem() {
              this.IndexCard(item)
            }
          }, (item: BangumiItem, index: number) => `${item.seasonId}_${index}`)
        }
      }
      .columnsTemplate('1fr 1fr 1fr')
      .columnsGap(GRID_COLUMN_GAP)
      .rowsGap(GRID_ROW_GAP)
      .padding({ left: GRID_PADDING, right: GRID_PADDING, top: 4, bottom: 90 })
      .scrollBar(BarState.Off)
      .layoutWeight(1)
      .onDidScroll((offset: number, state: ScrollState) => {
        this.onScrollAction?.(offset, state);
      })
      .onReachEnd(() => {
        this.vm.loadMoreIndex();
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.PAGE_BG)
  }

  /** 筛选条件区：排序 + 各筛选分组（折叠 5 行 + 更多筛选） */
  @Builder
  FilterPanel() {
    Column() {
      ForEach(this.vm.visibleRows(), (row: BangumiFilterRow) => {
        Row() {
          // 左侧胶囊：该分组当前选中项
          Text(row.pill)
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.bangumi_filter_pill_text'))
            .backgroundColor($r('app.color.bangumi_filter_pill_bg'))
            .borderRadius(16)
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .constraintSize({ minWidth: PILL_MIN_WIDTH })
            .textAlign(TextAlign.Center)
            .maxLines(1)

          // 右侧候选项：横向滚动
          Scroll() {
            Row({ space: 20 }) {
              ForEach(row.values, (v: BangumiConditionValue) => {
                Text(v.name)
                  .fontSize(12)
                  .fontWeight(this.vm.isSelected(row.field, v.keyword) ? FontWeight.Medium : FontWeight.Normal)
                  .fontColor(this.vm.isSelected(row.field, v.keyword)
                    ? $r('app.color.bangumi_filter_pill_text')
                    : $r('app.color.bangumi_filter_option_text'))
                  .maxLines(1)
                  .onClick(() => {
                    this.vm.selectValue(row.field, v.keyword, v.name);
                  })
              }, (v: BangumiConditionValue) => `${row.field}_${v.keyword}`)
            }
            .padding({ left: 12, right: 12 })
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .padding({ top: 5, bottom: 5 })
      }, (row: BangumiFilterRow) => row.key)

      if (this.vm.showToggle()) {
        Row({ space: 2 }) {
          Text(this.vm.expanded
            ? $r('app.string.bangumi_filter_less')
            : $r('app.string.bangumi_filter_more'))
            .fontSize(12)
            .fontColor(AppColors.TEXT_SECONDARY)
          SymbolGlyph(this.vm.expanded ? $r('sys.symbol.chevron_up') : $r('sys.symbol.chevron_down'))
            .fontSize(16)
            .fontColor([AppColors.TEXT_SECONDARY])
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ top: 8, bottom: 4 })
        .onClick(() => {
          this.vm.toggleExpanded();
        })
      }
    }
    .width('100%')
  }

  /** 列表加载 / 错误 / 空态 */
  @Builder
  ListStateView() {
    Column() {
      if (this.vm.indexState.status === DataStatus.Loading) {
        LoadingView()
      } else if (this.vm.indexState.status === DataStatus.Error) {
        ErrorView({
          message: this.vm.errorMessage,
          retryable: true,
          onRetry: () => {
            this.vm.retry();
          }
        })
      } else {
        EmptyView({ tip: $r('app.string.bangumi_empty') })
      }
    }
    .width('100%')
    .height(280)
  }

  /** 索引卡片：封面 + 角标 + 更新状态/评分 + 标题/副标题 */
  @Builder
  IndexCard(item: BangumiItem) {
    Column() {
      Stack({ alignContent: Alignment.TopEnd }) {
        Stack({ alignContent: Alignment.Bottom }) {
          Image(item.cover)
            .width('100%')
            .aspectRatio(COVER_ASPECT)
            .objectFit(ImageFit.Cover)
            .borderRadius(CARD_RADIUS)
            .backgroundColor(AppColors.CARD_BG)
            .alt($r('app.media.startIcon'))
          // 底部渐变信息条：左「更新至…」右「评分」
          Row() {
            Text(item.indexShow)
              .fontSize(11)
              .fontColor(Color.White)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
            if (item.score > 0) {
              Text(item.score.toFixed(1))
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
                .margin({ left: 4 })
            }
          }
          .width('100%')
          .alignItems(VerticalAlign.Bottom)
          .padding({ left: 6, right: 6, top: 18, bottom: 6 })
          .linearGradient({
            angle: 180,
            colors: [[OVERLAY_CLEAR, 0.0], [OVERLAY_CLEAR, 0.4], [OVERLAY_DARK, 1.0]]
          })
          .borderRadius({ bottomLeft: CARD_RADIUS, bottomRight: CARD_RADIUS })
        }
        .width('100%')

        // 角标（出品 / 独家 / 大会员），底色取接口 badge_info.bg_color
        if (item.badge.length > 0) {
          Text(item.badge)
            .fontSize(10)
            .fontColor(Color.White)
            .backgroundColor(this.badgeColor(item))
            .borderRadius({ topRight: CARD_RADIUS, bottomLeft: 6 })
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .margin({ top: 6, right: 6 })
            .maxLines(1)
        }
      }
      .width('100%')

      Text(item.title)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.TEXT_PRIMARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 5 })

      if (item.subTitle.length > 0) {
        Text(item.subTitle)
          .fontSize(11)
          .fontColor(AppColors.TEXT_SECONDARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: 2 })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    // 打开中降低透明度，给出按压反馈（网络往返期间不至于无响应感）
    .opacity(this.openingSeasonId === item.seasonId ? 0.55 : 1)
    .onClick(() => {
      this.playFromCard(item);
    })
    // 长按进详情（SDK 的 CommonMethod 未提供 onLongPress，统一用 LongPressGesture）
    .gesture(LongPressGesture().onAction(() => {
      this.openDetail(item);
    }))
  }

  /** 角标底色：接口未给 bg_color 时回退品牌色 */
  private badgeColor(item: BangumiItem): ResourceColor {
    return item.badgeColor.length > 0 ? item.badgeColor : AppColors.BRAND;
  }
}

/**
 * 番剧排行榜内容（保留原「排行榜」功能）。
 */
@Component
export struct BangumiRankContent {
  @State vm: BangumiViewModel = new BangumiViewModel();
  /** 滚动回调（转发给宿主页面，驱动搜索排收起/底部栏显隐） */
  onScrollAction?: (offset: number, state: ScrollState) => void;

  aboutToAppear(): void {
    this.vm.loadRank(1, 3);
  }

  build() {
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
        EmptyView({ tip: $r('app.string.bangumi_rank_empty') })
          .layoutWeight(1)
      } else {
        List({ space: 8 }) {
          ForEach(this.vm.rankItems, (item: BangumiItem, index: number) => {
            ListItem() {
              this.RankRow(item, index)
            }
          }, (item: BangumiItem, index: number) => `${item.seasonId}_${index}`)
        }
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

  @Builder
  RankRow(item: BangumiItem, index: number) {
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
        if (item.typeName.length > 0) {
          Text(item.typeName)
            .fontSize(11)
            .fontColor(AppColors.TEXT_SECONDARY)
        }
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
      Route.push(Route.bangumiDetail, p);
    })
  }
}

/** 独立路由页：番剧索引（标题栏对齐截图：返回 + 索引 + 搜索） */
@Component
export struct BangumiPage {
  build() {
    NavDestination() {
      Column() {
        Row() {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(20)
            .fontColor([AppColors.TEXT_PRIMARY])
            .width(36)
            .onClick(() => {
              Route.pop();
            })
          Text($r('app.string.bangumi_index_title'))
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.TEXT_PRIMARY)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
          SymbolGlyph($r('sys.symbol.magnifyingglass'))
            .fontSize(20)
            .fontColor([AppColors.TEXT_PRIMARY])
            .width(36)
            .onClick(() => {
              Route.push(Route.search);
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .padding({ left: 4, right: 12, top: 8, bottom: 4 })

        BangumiIndexContent()
          .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppColors.PAGE_BG)
    }
    .hideTitleBar(true)
    .onShown(() => {
      hilog.info(0x0000, TAG, 'bangumi index page shown');
    })
  }
}

/** 独立路由页：番剧排行榜（保留原功能入口） */
@Component
export struct BangumiRankPage {
  build() {
    NavDestination() {
      Column() {
        Row() {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(20)
            .fontColor([AppColors.TEXT_PRIMARY])
            .width(36)
            .onClick(() => {
              Route.pop();
            })
          Text($r('app.string.bangumi_rank_title'))
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.TEXT_PRIMARY)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
          Blank().width(36)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .padding({ left: 4, right: 12, top: 8, bottom: 4 })

        BangumiRankContent()
          .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppColors.PAGE_BG)
    }
    .hideTitleBar(true)
  }
}

// 日志 TAG（规范：统一定义在文件最下方）
const TAG = BangumiIndexContent.name ?? 'BangumiIndexContent';
