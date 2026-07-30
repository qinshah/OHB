/** 视频详情模型 */
export class VideoPage {
  cid: number = 0;
  part: string = '';
  page: number = 1;
  duration: number = 0;
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
