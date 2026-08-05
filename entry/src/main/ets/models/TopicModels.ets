/** 话题广场模型（P2 Task 18） */

@Observed
export class TopicItem {
  topicId: number = 0;
  topicName: string = '';
  /** 话题简介 */
  desc: string = '';
  /** 讨论数 */
  discussCount: number = 0;
  /** 头像/封面 */
  cover: string = '';
}

/** 话题动态流 */
export class TopicFeedPage {
  items: TopicFeedCard[] = [];
  offset: string = '';
  hasMore: boolean = true;
}

/** 话题卡片（内含一条动态） */
@Observed
export class TopicFeedCard {
  idStr: string = '';
  text: string = '';
  images: string[] = [];
  upName: string = '';
  upFace: string = '';
  upMid: number = 0;
  pubTs: number = 0;
  videoBvid: string = '';
  videoTitle: string = '';
  videoCover: string = '';
  videoDuration: number = 0;
  likeCount: number = 0;
}
