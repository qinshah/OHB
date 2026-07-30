/** 搜索相关模型 */

/** 搜索建议 */
export class SuggestResult {
  terms: string[] = [];
}

/** 热搜项 */
export class HotSearchItem {
  keyword: string = '';
  showName: string = '';
  icon: string = '';
}

/** 分类搜索类型 */
export enum SearchType {
  Video = 'video',
  Live = 'live',
  User = 'bili_user',
  Bangumi = 'media_bangumi',
  Article = 'article'
}

/** 搜索结果行类别 */
export enum SearchRowKind {
  Video,
  User,
  Live,
  Bangumi,
  Article,
  Unknown
}

/**
 * 通用搜索结果行（按 search_type 填充对应字段）。
 * 视频行可跳转视频页（AC-V1-2）。
 */
@Observed
export class SearchRow {
  kind: SearchRowKind = SearchRowKind.Unknown;
  // ---- 视频 ----
  bvid: string = '';
  aid: number = 0;
  // ---- 通用展示 ----
  title: string = '';
  cover: string = '';
  author: string = '';
  mid: number = 0;
  pubdate: number = 0;
  desc: string = '';
  // ---- 视频 ----
  duration: number = 0;
  playCount: number = 0;
  danmakuCount: number = 0;
  // ---- 用户 ----
  face: string = '';
  fans: number = 0;
  videos: number = 0;
  usign: string = '';
  // ---- 直播 ----
  roomid: number = 0;
  online: number = 0;
  area: string = '';
  // ---- 番剧 ----
  mediaId: number = 0;
  styles: string = '';
  areas: string = '';
  // ---- 文章 ----
  articleId: number = 0;
}

/** 搜索结果分页包 */
export class SearchPage {
  rows: SearchRow[] = [];
  page: number = 1;
  pageSize: number = 20;
  total: number = 0;

  get hasMore(): boolean {
    return this.page * this.pageSize < this.total;
  }
}
