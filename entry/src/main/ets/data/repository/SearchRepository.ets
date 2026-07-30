import { Result } from '../../common/result/Result';
import { BiliApi } from '../../network/BiliApi';
import { VideoCard } from '../../models/VideoCard';
import { HotSearchItem, SearchPage, SearchRow, SearchRowKind, SearchType, SuggestResult } from '../../models/SearchModels';
import { PrefsStorage } from '../../services/storage/PrefsStorage';
import { common } from '@kit.AbilityKit';

interface RawSuggestTag {
  value?: string;
}

interface RawSuggestResult {
  tag?: RawSuggestTag[];
}

interface RawSuggestBody {
  result?: RawSuggestResult;
}

interface RawTrendingItem {
  keyword?: string;
  show_name?: string;
  icon?: string;
}

interface RawTrendingData {
  list?: RawTrendingItem[];
}

/** 分类搜索各行原始 JSON（按 type 区分字段） */
interface RawSearchItem {
  type?: string;
  // video
  bvid?: string;
  aid?: number;
  duration?: string;
  play?: number;
  video_review?: number;
  danmaku?: number;
  author?: string;
  pic?: string;
  // 通用
  title?: string;
  cover?: string;
  mid?: number;
  pubdate?: number;
  desc?: string;
  // user
  uname?: string;
  uface?: string;
  fans?: number;
  videos?: number;
  usign?: string;
  // live
  roomid?: number;
  online?: number;
  area?: string;
  // bangumi
  media_id?: number;
  styles?: string;
  areas?: string;
  // article
  id?: number;
  image_urls?: string[];
}

interface RawSearchData {
  page?: number;
  pagesize?: number;
  numResults?: number;
  result?: RawSearchItem[];
}

/**
 * 搜索仓库（Task 7）：建议/热搜/分类搜索/历史持久化。
 */
export class SearchRepository {
  private static readonly HISTORY_KEY: string = 'search_history';
  private static readonly HISTORY_MAX: number = 20;

  private api: BiliApi = new BiliApi();
  private prefs: PrefsStorage | null = null;

  init(context: common.Context): void {
    this.prefs = new PrefsStorage(context, 'ohb_search');
  }

  async suggest(term: string): Promise<Result<SuggestResult>> {
    const r = await this.api.searchSuggest(term);
    if (!r.isOk) {
      return Result.err<SuggestResult>(r.error);
    }
    const body = r.value as RawSuggestBody;
    const tags = body.result?.tag ?? [];
    const res = new SuggestResult();
    res.terms = tags.map((t: RawSuggestTag) => t.value ?? '').filter((s: string) => s.length > 0);
    return Result.ok<SuggestResult>(res);
  }

  async trending(): Promise<Result<HotSearchItem[]>> {
    const r = await this.api.searchTrending();
    if (!r.isOk) {
      return Result.err<HotSearchItem[]>(r.error);
    }
    const data = r.value as RawTrendingData;
    const items = (data.list ?? []).map((it: RawTrendingItem) => {
      const h = new HotSearchItem();
      h.keyword = it.keyword ?? '';
      h.showName = it.show_name ?? it.keyword ?? '';
      h.icon = it.icon ?? '';
      return h;
    }).filter((h: HotSearchItem) => h.keyword.length > 0);
    return Result.ok<HotSearchItem[]>(items);
  }

  /** 分类搜索：视频/直播/用户/番剧/文章；视频行可直接跳转视频页 */
  async search(type: SearchType, keyword: string, page: number, order: string = '',
    duration: number = 0, tids: number = 0): Promise<Result<SearchPage>> {
    const r = await this.api.searchByType(type, keyword, page, order, duration, tids);
    if (!r.isOk) {
      return Result.err<SearchPage>(r.error);
    }
    const data = r.value as RawSearchData;
    const sp = new SearchPage();
    sp.page = data.page ?? page;
    sp.pageSize = data.pagesize ?? 20;
    sp.total = data.numResults ?? 0;
    const items = data.result ?? [];
    sp.rows = items.map((it: RawSearchItem) => SearchRepository.parseRow(it))
      .filter((row: SearchRow) => row.kind !== SearchRowKind.Unknown);
    return Result.ok<SearchPage>(sp);
  }

  private static parseRow(it: RawSearchItem): SearchRow {
    const row = new SearchRow();
    const t = it.type ?? '';
    if (t === 'video') {
      row.kind = SearchRowKind.Video;
      row.bvid = it.bvid ?? '';
      row.aid = it.aid ?? 0;
      row.title = SearchRepository.stripEm(it.title ?? '');
      row.cover = VideoCard.fixUrl(it.pic ?? '');
      row.duration = SearchRepository.parseDuration(it.duration ?? '');
      row.playCount = it.play ?? 0;
      row.danmakuCount = it.video_review ?? it.danmaku ?? 0;
      row.mid = it.mid ?? 0;
      row.author = it.author ?? '';
      row.pubdate = it.pubdate ?? 0;
    } else if (t === 'bili_user') {
      row.kind = SearchRowKind.User;
      row.mid = it.mid ?? 0;
      row.title = SearchRepository.stripEm(it.uname ?? '');
      row.face = VideoCard.fixUrl(it.uface ?? '');
      row.fans = it.fans ?? 0;
      row.videos = it.videos ?? 0;
      row.usign = it.usign ?? '';
    } else if (t === 'live') {
      row.kind = SearchRowKind.Live;
      row.roomid = it.roomid ?? 0;
      row.title = SearchRepository.stripEm(it.title ?? '');
      row.cover = VideoCard.fixUrl(it.cover ?? '');
      row.author = it.uname ?? '';
      row.online = it.online ?? 0;
      row.area = it.area ?? '';
    } else if (t === 'media_bangumi') {
      row.kind = SearchRowKind.Bangumi;
      row.mediaId = it.media_id ?? 0;
      row.title = SearchRepository.stripEm(it.title ?? '');
      row.cover = VideoCard.fixUrl(it.cover ?? '');
      row.styles = it.styles ?? '';
      row.areas = it.areas ?? '';
      row.desc = it.desc ?? '';
    } else if (t === 'article') {
      row.kind = SearchRowKind.Article;
      row.articleId = it.id ?? 0;
      row.title = SearchRepository.stripEm(it.title ?? '');
      const imgs = it.image_urls ?? [];
      row.cover = imgs.length > 0 ? VideoCard.fixUrl(imgs[0]) : '';
      row.desc = SearchRepository.stripEm(it.desc ?? '');
      row.mid = it.mid ?? 0;
      row.pubdate = it.pubdate ?? 0;
    } else {
      row.kind = SearchRowKind.Unknown;
    }
    return row;
  }

  // ---------- 搜索历史（本地持久化） ----------

  getHistory(): string[] {
    if (this.prefs === null) {
      return [];
    }
    const raw = this.prefs.getString(SearchRepository.HISTORY_KEY, '[]');
    try {
      return JSON.parse(raw) as string[];
    } catch (e) {
      return [];
    }
  }

  addHistory(keyword: string): void {
    if (this.prefs === null || keyword.trim().length === 0) {
      return;
    }
    const list = this.getHistory();
    const idx = list.indexOf(keyword);
    if (idx >= 0) {
      list.splice(idx, 1);
    }
    list.unshift(keyword);
    while (list.length > SearchRepository.HISTORY_MAX) {
      list.pop();
    }
    this.prefs.putString(SearchRepository.HISTORY_KEY, JSON.stringify(list));
  }

  removeHistory(keyword: string): void {
    if (this.prefs === null) {
      return;
    }
    const list = this.getHistory();
    const idx = list.indexOf(keyword);
    if (idx >= 0) {
      list.splice(idx, 1);
      this.prefs.putString(SearchRepository.HISTORY_KEY, JSON.stringify(list));
    }
  }

  clearHistory(): void {
    this.prefs?.putString(SearchRepository.HISTORY_KEY, '[]');
  }

  // ---------- 工具 ----------

  private static stripEm(s: string): string {
    return s.replace(/<[^>]+>/g, '');
  }

  /** 搜索结果时长为 "mm:ss" 或 "hh:mm:ss" 字符串 */
  private static parseDuration(s: string): number {
    const parts = s.split(':');
    let sec = 0;
    for (let i = 0; i < parts.length; i++) {
      const n = Number(parts[i]);
      if (!isNaN(n)) {
        sec = sec * 60 + n;
      }
    }
    return sec;
  }
}
