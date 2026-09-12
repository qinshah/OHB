/** 视频详情模型 */
export class VideoPage {
  cid: number = 0;
  part: string = '';
  page: number = 1;
  duration: number = 0;
  /**
   * 番剧分集：该集自己的 bvid（普通视频分P为空串，沿用视频本身的 bvid）。
   * 番剧每一集都是独立稿件，切集时必须连带更换 bvid 重新取流。
   */
  bvid: string = '';
}

export class VideoDetail {
  bvid: string = '';
  aid: number = 0;
  cid: number = 0;
  title: string = '';
  desc: string = '';
  cover: string = '';
  duration: number = 0;
  pubdate: number = 0;
  ownerMid: number = 0;
  ownerName: string = '';
  ownerFace: string = '';
  view: number = 0;
  danmaku: number = 0;
  reply: number = 0;
  favorite: number = 0;
  coin: number = 0;
  share: number = 0;
  like: number = 0;
  pages: VideoPage[] = [];
}
