import { DataStatus } from '../common/state/DataState';
import { NavService } from '../common/navigation/NavService';
import { FormatUtils } from '../common/utils/FormatUtils';
import { SearchRow, SearchRowKind, SearchType } from '../models/SearchModels';
import { VideoCard } from '../models/VideoCard';
import { SearchViewModel } from '../viewmodel/SearchViewModel';
import { VideoCardView } from '../common/components/VideoCardView';
import { EmptyView, ErrorView, LoadingView } from '../common/components/StateViews';
import { AppColors } from '../theme/AppTheme';
import { RouteNames } from './RouteNames';
import { BangumiDetailParam, LiveRoomParam, UserSpaceParam } from './RouteParams';

/** 排序选项 */
class OrderOption {
  label: string = '';
  value: string = '';
}

const ORDER_OPTIONS: OrderOption[] = [
  { label: '综合排序', value: '' },
  { label: '最多播放', value: 'click' },
  { label: '最新发布', value: 'pubdate' },
  { label: '最多弹幕', value: 'dm' }
];

/** 时长筛选 */
class DurationOption {
  label: string = '';
  value: number = 0;
}

const DURATION_OPTIONS: DurationOption[] = [
  { label: '全部时长', value: 0 },
  { label: '10分钟以下', value: 1 },
  { label: '10-30分钟', value: 2 },
  { label: '30-60分钟', value: 3 },
  { label: '60分钟以上', value: 4 }
];

/** 分区筛选（常用分区 tid） */
class TidOption {
  label: string = '';
  value: number = 0;
}

const TID_OPTIONS: TidOption[] = [
  { label: '全部分区', value: 0 },
  { label: '动画', value: 1 },
  { label: '音乐', value: 3 },
  { label: '游戏', value: 4 },
  { label: '科技', value: 36 },
  { label: '生活', value: 160 }
];

interface TabDef {
  label: string;
  type: SearchType;
}

const SEARCH_TABS: TabDef[] = [
  { label: '视频', type: SearchType.Video },
  { label: '直播', type: SearchType.Live },
  { label: '用户', type: SearchType.User },
  { label: '番剧', type: SearchType.Bangumi },
  { label: '文章', type: SearchType.Article }
];

/**
 * 搜索结果页（Task 7）：分类 Tab + 高级筛选 + 分页，视频项跳视频页。
 */
@Component
export struct SearchResultPage {
  @Prop keyword: string = '';
  @State vm: SearchViewModel = new SearchViewModel();
  @State currentTabIdx: number = 0;
  @State orderIndex: number = 0;
  @State durationIndex: number = 0;
  @State tidIndex: number = 0;

  aboutToAppear(): void {
    const ctx = this.getUIContext().getHostContext();
    if (ctx !== undefined) {
      this.vm.init(ctx);
    }
    this.vm.doSearch(SearchType.Video, this.keyword);
  }

  build() {
    Column() {
      // 标题栏
      Row({ space: 8 }) {
        Text('‹')
          .fontSize(24)
          .fontColor(AppColors.TEXT_PRIMARY)
          .width(32)
          .onClick(() => {
            NavService.pop();
          })
        Text(`"${this.keyword}" 的搜索结果`)
          .fontSize(17)
          .fontColor(AppColors.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 8, right: 12, top: 8, bottom: 4 })

      // 分类 Tab
      Tabs({ index: $$this.currentTabIdx }) {
        ForEach(SEARCH_TABS, (tab: TabDef) => {
          TabContent() {
            this.ResultList()
          }
          .tabBar(tab.label)
        }, (tab: TabDef) => tab.label)
      }
      .barHeight(40)
      .layoutWeight(1)
      .onChange((idx: number) => {
        this.currentTabIdx = idx;
        this.vm.doSearch(SEARCH_TABS[idx].type, this.keyword);
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.PAGE_BG)
  }

  @Builder
  ResultList() {
    Column() {
      // 高级筛选（仅视频类展示）
      if (SEARCH_TABS[this.currentTabIdx].type === SearchType.Video) {
        Row({ space: 8 }) {
          this.FilterSelect('排序', ORDER_OPTIONS.map((o: OrderOption) => o.label), this.orderIndex, (idx: number) => {
            this.orderIndex = idx;
            this.vm.order = ORDER_OPTIONS[idx].value;
            this.vm.doSearch(this.vm.searchType, this.keyword);
          })
          this.FilterSelect('时长', DURATION_OPTIONS.map((o: DurationOption) => o.label), this.durationIndex,
            (idx: number) => {
              this.durationIndex = idx;
              this.vm.duration = DURATION_OPTIONS[idx].value;
              this.vm.doSearch(this.vm.searchType, this.keyword);
            })
          this.FilterSelect('分区', TID_OPTIONS.map((o: TidOption) => o.label), this.tidIndex, (idx: number) => {
            this.tidIndex = idx;
            this.vm.tids = TID_OPTIONS[idx].value;
            this.vm.doSearch(this.vm.searchType, this.keyword);
          })
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 4, bottom: 4 })
      }

      if (this.vm.resultState.status === DataStatus.Loading) {
        LoadingView()
          .layoutWeight(1)
      } else if (this.vm.resultState.status === DataStatus.Error && this.vm.resultPage === null) {
        ErrorView({
          message: this.vm.resultState.error?.message ?? '搜索失败',
          retryable: true,
          onRetry: () => {
            this.vm.doSearch(this.vm.searchType, this.keyword);
          }
        })
          .layoutWeight(1)
      } else if (this.vm.resultState.status === DataStatus.Empty) {
        EmptyView({ tip: '没有找到相关内容' })
          .layoutWeight(1)
      } else {
        WaterFlow() {
          ForEach(this.vm.resultPage?.rows ?? [], (row: SearchRow, index: number) => {
            FlowItem() {
              this.RowCard(row)
            }
          }, (row: SearchRow, index: number) => `${row.kind}_${row.bvid}_${row.mid}_${row.roomid}_${row.mediaId}_${row.articleId}_${index}`)
        }
        .columnsTemplate('1fr 1fr')
        .columnsGap(8)
        .rowsGap(8)
        .padding(8)
        .onReachEnd(() => {
          this.vm.loadMoreResult();
        })
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  FilterSelect(label: string, options: string[], selected: number, onPick: (idx: number) => void) {
    Text(`${label}: ${options[selected]}`)
      .fontSize(12)
      .fontColor(AppColors.TEXT_SECONDARY)
      .backgroundColor(AppColors.CARD_BG)
      .borderRadius(10)
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .bindMenu(options.map((opt: string, idx: number) => {
        const item: MenuElement = {
          value: opt,
          action: () => {
            onPick(idx);
          }
        };
        return item;
      }))
  }

  @Builder
  RowCard(row: SearchRow) {
    if (row.kind === SearchRowKind.Video) {
      VideoCardView({
        card: SearchResultPage.rowToVideoCard(row),
        onCardClick: (bvid: string) => {
          NavService.push(RouteNames.VIDEO_DETAIL, bvid);
        }
      })
    } else if (row.kind === SearchRowKind.User) {
      Column({ space: 6 }) {
        Image(row.face)
          .width(64)
          .height(64)
          .borderRadius(32)
          .alt($r('app.media.startIcon'))
        Text(row.title)
          .fontSize(14)
          .fontColor(AppColors.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`粉丝 ${FormatUtils.count(row.fans)} · 视频 ${row.videos}`)
          .fontSize(11)
          .fontColor(AppColors.TEXT_SECONDARY)
      }
      .width('100%')
      .padding(12)
      .backgroundColor(AppColors.CARD_BG)
      .borderRadius(8)
      .onClick(() => {
        const p: UserSpaceParam = { mid: row.mid };
        NavService.push(RouteNames.USER_SPACE, p);
      })
    } else if (row.kind === SearchRowKind.Live) {
      Column({ space: 4 }) {
        Stack({ alignContent: Alignment.BottomEnd }) {
          Image(row.cover)
            .width('100%')
            .aspectRatio(16 / 10)
            .objectFit(ImageFit.Cover)
            .borderRadius(8)
            .alt($r('app.media.startIcon'))
          Text(`${FormatUtils.count(row.online)}观看`)
            .fontSize(10)
            .fontColor(Color.White)
            .backgroundColor('#99000000')
            .borderRadius(4)
            .padding({ left: 4, right: 4, top: 1, bottom: 1 })
            .margin({ right: 6, bottom: 6 })
        }
        Text(row.title)
          .fontSize(13)
          .fontColor(AppColors.TEXT_PRIMARY)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(`${row.author} · ${row.area}`)
          .fontSize(11)
          .fontColor(AppColors.TEXT_SECONDARY)
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(4)
      .onClick(() => {
        const p: LiveRoomParam = { roomId: row.roomid, title: row.title };
        NavService.push(RouteNames.LIVE_ROOM, p);
      })
    } else {
      Column({ space: 4 }) {
        if (row.cover.length > 0) {
          Image(row.cover)
            .width('100%')
            .aspectRatio(16 / 10)
            .objectFit(ImageFit.Cover)
            .borderRadius(8)
            .alt($r('app.media.startIcon'))
        }
        Text(row.title)
          .fontSize(13)
          .fontColor(AppColors.TEXT_PRIMARY)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        if (row.desc.length > 0) {
          Text(row.desc)
            .fontSize(11)
            .fontColor(AppColors.TEXT_SECONDARY)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
        Text(row.kind === SearchRowKind.Bangumi ? `${row.areas} · ${row.styles}` : '专栏文章')
          .fontSize(11)
          .fontColor(AppColors.TEXT_SECONDARY)
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(4)
      .onClick(() => {
        if (row.kind === SearchRowKind.Bangumi && row.mediaId > 0) {
          const p: BangumiDetailParam = { seasonId: row.mediaId };
          NavService.push(RouteNames.BANGUMI_DETAIL, p);
        }
      })
    }
  }

  private static rowToVideoCard(row: SearchRow): VideoCard {
    const c = new VideoCard();
    c.bvid = row.bvid;
    c.aid = row.aid;
    c.title = row.title;
    c.cover = row.cover;
    c.duration = row.duration;
    c.playCount = row.playCount;
    c.danmakuCount = row.danmakuCount;
    c.ownerMid = row.mid;
    c.ownerName = row.author;
    c.pubdate = row.pubdate;
    return c;
  }
}
