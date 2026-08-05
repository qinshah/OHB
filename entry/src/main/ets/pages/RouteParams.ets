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
