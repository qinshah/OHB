/** 收藏模型（P2 Task 16） */

/** 收藏夹 */
@Observed
export class FavoriteFolder {
  id: number = 0;
  fid: number = 0;
  mid: number = 0;
  title: string = '';
  cover: string = '';
  mediaCount: number = 0;
}

/** 收藏夹内视频项 */
@Observed
export class FavoriteMedia {
  id: number = 0;
  aid: number = 0;
  bvid: string = '';
  title: string = '';
  cover: string = '';
  duration: number = 0;
  playCount: number = 0;
  danmakuCount: number = 0;
  ownerName: string = '';
  ownerMid: number = 0;
  pubdate: number = 0;
  /** 收藏时间（秒） */
  favTime: number = 0;
}
