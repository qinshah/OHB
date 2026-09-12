/** 番剧模型（P2 Task 20） */

/** 番剧卡片（排行/索引共用） */
@Observed
export class BangumiItem {
  seasonId: number = 0;
  mediaId: number = 0;
  title: string = '';
  cover: string = '';
  /** 评分（0 表示无评分） */
  score: number = 0;
  /** 更新状态文案（索引接口 index_show，如 "更新至第191话" / "全12话"） */
  indexShow: string = '';
  /** 分区名 */
  typeName: string = '';
  /** 角标文案（索引接口 badge：出品 / 独家 / 大会员，空表示无角标） */
  badge: string = '';
  /** 角标底色（索引接口 badge_info.bg_color，空则回退品牌色） */
  badgeColor: string = '';
  /** 副标题（索引接口 subTitle） */
  subTitle: string = '';
  /** 热度文案（索引接口 order，如 "1782.2万追番"） */
  order: string = '';
}

/** 剧集 */
export class BangumiEpisode {
  epId: number = 0;
  aid: number = 0;
  bvid: string = '';
  cid: number = 0;
  title: string = '';
  longTitle: string = '';
  cover: string = '';
  /** 时长（毫秒） */
  duration: number = 0;
  /** 首播时间（Unix 秒，0 表示未知） */
  pubTime: number = 0;
  /** 是否付费/会员 */
  badge: string = '';
}

/** 番剧详情 */
export class BangumiDetail {
  seasonId: number = 0;
  mediaId: number = 0;
  title: string = '';
  cover: string = '';
  evaluate: string = '';
  /** 总集数 */
  total: number = 0;
  /** 追番数 */
  followCount: number = 0;
  /** 播放数 */
  viewCount: number = 0;
  /** 点赞数 */
  likeCount: number = 0;
  /** 收藏数 */
  favCount: number = 0;
  /** 是否已追番 */
  isFollow: boolean = false;
  episodes: BangumiEpisode[] = [];
  /** 其他季 */
  seasons: BangumiItem[] = [];
}

// ---------- 番剧索引（pgc/season/index，对齐 PiliPlus PgcIndexController） ----------

/** 索引排序项（order 数组元素） */
export class BangumiOrderItem {
  /** 排序字段值，直接作为 order 查询参数 */
  field: string = '';
  name: string = '';
  sort: string = '';
}

/** 索引筛选值（filter[].values[] 元素） */
export class BangumiConditionValue {
  /** 选项值，直接作为该分组的查询参数 */
  keyword: string = '';
  name: string = '';
}

/** 索引筛选分组（filter[] 元素，如 地区/风格/类型…） */
export class BangumiConditionGroup {
  /** 查询参数字段名（area / style_id / season_version …） */
  field: string = '';
  name: string = '';
  values: BangumiConditionValue[] = [];
}

/** 索引筛选条件（排序 + 筛选分组） */
export class BangumiIndexCondition {
  orders: BangumiOrderItem[] = [];
  filters: BangumiConditionGroup[] = [];
}

/** 索引查询结果（列表 + 是否还有下一页） */
export class BangumiIndexResult {
  items: BangumiItem[] = [];
  hasNext: boolean = false;
}

/** 索引筛选/排序的当前选中项（field → 选中值） */
export class BangumiSelection {
  field: string = '';
  /** 选中的 keyword（排序组为 order 字段值） */
  value: string = '';
  /** 选中项显示名，用于左侧胶囊文案 */
  label: string = '';
}

