/** 路由对象参数定义（NavPathStack param 为 Object，页面内按接口转型） */

export interface LiveRoomParam {
  roomId: number;
  title: string;
}

export interface FavoriteDetailParam {
  mediaId: number;
  title: string;
}

export interface UserSpaceParam {
  mid: number;
}

export interface DynamicDetailParam {
  id: string;
}

export interface TopicFeedParam {
  topicId: number;
  topicName: string;
}

export interface BangumiDetailParam {
  seasonId: number;
}

/**
 * 视频页参数。
 * - 普通视频：路由参数直接传 bvid 字符串（历史调用方式，保持兼容）
 * - 番剧分集：传本对象，附带 seasonId，视频页据此加载整季剧集作为选集列表
 */
export interface VideoParam {
  bvid: string;
  /** 番剧季号（>0 表示番剧分集模式） */
  seasonId?: number;
}
