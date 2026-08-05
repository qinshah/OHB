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
  /** 更新至（如 "更新至12话"） */
  indexShow: string = '';
  /** 分区名 */
  typeName: string = '';
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
  duration: number = 0;
  pubTime: string = '';
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

/** 番剧索引条件项 */
export class BangumiFilterOption {
  id: number = 0;
  name: string = '';
}

/** 番剧索引条件分类 */
export class BangumiFilterGroup {
  name: string = '';
  options: BangumiFilterOption[] = [];
}
