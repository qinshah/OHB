/** 评论系统模型（P2 Task 14） */

/** 评论成员 */
export class CommentMember {
  mid: number = 0;
  uname: string = '';
  avatar: string = '';
  level: number = 0;
  /** 是否为 UP 主 */
  isUp: boolean = false;
}

/** 单条评论（顶层或楼中楼共用） */
@Observed
export class CommentItem {
  rpid: number = 0;
  oid: number = 0;
  member: CommentMember = new CommentMember();
  content: string = '';
  pubTs: number = 0;
  likeCount: number = 0;
  replyCount: number = 0;
  /** 是否已点赞（0 未赞 1 已赞） */
  liked: number = 0;
  /** 楼中楼子评论（懒加载） */
  replies: CommentItem[] = [];
  /** 楼中楼是否已加载 */
  repliesLoaded: boolean = false;
  /** 楼中楼当前页码 */
  replyPage: number = 1;
  /** 楼中楼是否还有更多 */
  replyHasMore: boolean = false;
}

/** 评论游标（next offset 由服务端返回的字符串携带） */
export class CommentCursor {
  next: string = '';
  isEnd: boolean = false;
}

/** 评论分页包 */
export class CommentPageData {
  comments: CommentItem[] = [];
  cursor: CommentCursor = new CommentCursor();
}
