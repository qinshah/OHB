/** 用户主页模型（P2 Task 17） */

export class UserSpaceInfo {
  mid: number = 0;
  name: string = '';
  face: string = '';
  sign: string = '';
  level: number = 0;
  sex: string = '';
  /** 粉丝数 */
  follower: number = 0;
  /** 关注数 */
  following: number = 0;
  /** 视频数 */
  archiveCount: number = 0;
  /** 大会员 */
  isVip: boolean = false;
  /** 认证说明 */
  officialTitle: string = '';
}

/** 用户投稿分页包 */
export class UserArchivePage {
  items: UserArchiveItem[] = [];
  count: number = 0;
  hasMore: boolean = true;
}

@Observed
export class UserArchiveItem {
  aid: number = 0;
  bvid: string = '';
  cid: number = 0;
  title: string = '';
  cover: string = '';
  duration: number = 0;
  playCount: number = 0;
  danmakuCount: number = 0;
  pubdate: number = 0;
}
