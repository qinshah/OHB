/**
 * 统一视频卡片模型（推荐 / 热门 / 搜索结果 / 动态内视频共用）
 */
@Observed
export class VideoCard {
  bvid: string = '';
  aid: number = 0;
  cid: number = 0;
  title: string = '';
  /** 封面（缺协议头时补 https:） */
  cover: string = '';
  /** 时长（秒） */
  duration: number = 0;
  playCount: number = 0;
  danmakuCount: number = 0;
  ownerName: string = '';
  ownerMid: number = 0;
  ownerFace: string = '';
  pubdate: number = 0;
  /** 分区名 */
  tname: string = '';
  /** 推荐理由 / 角标 */
  rcmdReason: string = '';
  /** 点赞数（用于低赞比过滤） */
  likeCount: number = 0;

  static fixUrl(url: string): string {
    if (url.startsWith('//')) {
      return `https:${url}`;
    }
    if (url.startsWith('http://')) {
      return url.replace('http://', 'https://');
    }
    return url;
  }
}
