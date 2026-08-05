/** 动态流模型（V1：仅加载与跳转） */

export enum DynamicKind {
  /** 视频动态 */
  Video,
  /** 图文/文字动态 */
  Article,
  /** 转发动态 */
  Forward,
  /** 其他（V1 按纯文本展示） */
  Other
}

@Observed
export class DynamicItem {
  idStr: string = '';
  kind: DynamicKind = DynamicKind.Other;
  upName: string = '';
  upFace: string = '';
  upMid: number = 0;
  pubTs: number = 0;
  /** 文本内容（图文/转发/视频描述摘要） */
  text: string = '';
  /** 视频动态字段 */
  videoTitle: string = '';
  videoCover: string = '';
  videoBvid: string = '';
  videoDuration: number = 0;
  videoPlayCount: number = 0;
  videoDanmakuCount: number = 0;
  /** 图文动态的图片列表 */
  images: string[] = [];
  /** 点赞数（P2 Task 18 互动） */
  likeCount: number = 0;
  /** 评论数 */
  commentCount: number = 0;
  /** 转发数 */
  forwardCount: number = 0;
  /** 是否已点赞 */
  isLiked: boolean = false;
}

export class DynamicFeed {
  items: DynamicItem[] = [];
  /** 下一页游标 */
  offset: string = '';
  hasMore: boolean = true;
}
