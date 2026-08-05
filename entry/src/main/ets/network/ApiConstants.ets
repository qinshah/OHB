import { AppConstants } from '../common/constants/AppConstants';

/**
 * Bilibili API 端点常量（参考 PiliPlus api.dart 的 URL 与参数，非照搬代码）
 */
export class ApiConstants {
  // ---- 用户 ----
  /** nav 用户信息 + WBI key 来源 */
  static readonly NAV: string = `${AppConstants.API_BASE}/x/web-interface/nav`;

  // ---- 推荐/热门 ----
  /** Web 端推荐（WBI 签名） */
  static readonly RCMD_WEB: string = `${AppConstants.API_BASE}/x/web-interface/wbi/index/top/feed/rcmd`;
  /** 热门视频 */
  static readonly POPULAR: string = `${AppConstants.API_BASE}/x/web-interface/popular`;

  // ---- 视频 ----
  static readonly VIDEO_DETAIL: string = `${AppConstants.API_BASE}/x/web-interface/view`;
  /** 播放地址（WBI 签名）。V1 采用 fnval=1 获取 muxed MP4，保证 AVPlayer 可靠起播 */
  static readonly PLAY_URL: string = `${AppConstants.API_BASE}/x/player/wbi/playurl`;

  // ---- 搜索 ----
  static readonly SEARCH_SUGGEST: string = `${AppConstants.SEARCH_BASE}/main/suggest`;
  static readonly SEARCH_TRENDING: string = `${AppConstants.API_BASE}/x/v2/search/trending/ranking`;
  static readonly SEARCH_TYPE: string = `${AppConstants.API_BASE}/x/web-interface/wbi/search/type`;
  static readonly SEARCH_ALL: string = `${AppConstants.API_BASE}/x/web-interface/wbi/search/all/v2`;

  // ---- 动态 ----
  static readonly DYNAMIC_FEED: string = `${AppConstants.API_BASE}/x/polymer/web-dynamic/v1/feed/all`;

  // ---- TV 扫码登录 ----
  static readonly TV_QRCODE_AUTH: string = `${AppConstants.PASSPORT_BASE}/x/passport-tv-login/qrcode/auth_code`;
  static readonly TV_QRCODE_POLL: string = `${AppConstants.PASSPORT_BASE}/x/passport-tv-login/qrcode/poll`;

  // ---- 视频互动（P2 Task 13） ----
  /** 相关视频 */
  static readonly ARCHIVE_RELATED: string = `${AppConstants.API_BASE}/x/web-interface/archive/related`;
  /** 点赞（App 通道，access_key） */
  static readonly VIDEO_LIKE: string = `${AppConstants.APP_BASE}/x/v2/view/like`;
  /** 投币（App 通道） */
  static readonly VIDEO_COIN: string = `${AppConstants.APP_BASE}/x/v2/view/coin/add`;
  /** 一键三连 */
  static readonly VIDEO_TRIPLE: string = `${AppConstants.API_BASE}/x/web-interface/archive/like/triple`;
  /** 收藏（批量处理） */
  static readonly FAV_RESOURCE_DEAL: string = `${AppConstants.API_BASE}/x/v3/fav/resource/batch-deal`;
  /** 稍后再看 */
  static readonly TOVIEW_ADD: string = `${AppConstants.API_BASE}/x/v2/history/toview/add`;
  static readonly TOVIEW_WEB_LIST: string = `${AppConstants.API_BASE}/x/v2/history/toview/web`;
  static readonly TOVIEW_DEL: string = `${AppConstants.API_BASE}/x/v2/history/toview/v2/dels`;
  static readonly TOVIEW_CLEAR: string = `${AppConstants.API_BASE}/x/v2/history/toview/clear`;

  // ---- 评论（P2 Task 14） ----
  static readonly REPLY_MAIN: string = `${AppConstants.API_BASE}/x/v2/reply/main`;
  static readonly REPLY_REPLY: string = `${AppConstants.API_BASE}/x/v2/reply/reply`;
  static readonly REPLY_ADD: string = `${AppConstants.API_BASE}/x/v2/reply/add`;
  static readonly REPLY_ACTION: string = `${AppConstants.API_BASE}/x/v2/reply/action`;
  static readonly REPLY_DEL: string = `${AppConstants.API_BASE}/x/v2/reply/del`;

  // ---- 直播（P2 Task 15） ----
  /** 直播分区列表 */
  static readonly LIVE_AREA_LIST: string = `${AppConstants.LIVE_BASE}/xlive/app-interface/v2/index/getAreaList`;
  /** 直播二级列表（分区直播间） */
  static readonly LIVE_SECOND_LIST: string = `${AppConstants.LIVE_BASE}/xlive/app-interface/v2/second/getList`;
  /** 直播间播放信息 */
  static readonly LIVE_ROOM_PLAY_INFO: string = `${AppConstants.LIVE_BASE}/xlive/web-room/v2/index/getRoomPlayInfo`;
  /** 直播间弹幕密钥 */
  static readonly LIVE_DM_TOKEN: string = `${AppConstants.LIVE_BASE}/xlive/web-room/v1/index/getDanmuInfo`;
  /** 直播间弹幕预获取 */
  static readonly LIVE_DM_PREFETCH: string = `${AppConstants.LIVE_BASE}/xlive/web-room/v1/dM/gethistory`;
  /** 发送直播弹幕 */
  static readonly LIVE_SEND_MSG: string = `${AppConstants.LIVE_BASE}/msg/send`;
  /** 添加/删除直播屏蔽词 */
  static readonly LIVE_SHIELD_ADD: string = `${AppConstants.LIVE_BASE}/xlive/web-ucenter/v1/banned/AddShieldKeyword`;
  static readonly LIVE_SHIELD_DEL: string = `${AppConstants.LIVE_BASE}/xlive/web-ucenter/v1/banned/DelShieldKeyword`;

  // ---- 收藏/历史（P2 Task 16） ----
  /** 创建的收藏夹（含默认） */
  static readonly FAV_FOLDER_LIST_ALL: string = `${AppConstants.API_BASE}/x/v3/fav/folder/created/list-all`;
  static readonly FAV_FOLDER_LIST: string = `${AppConstants.API_BASE}/x/v3/fav/folder/created/list`;
  /** 收藏夹内视频 */
  static readonly FAV_RESOURCE_LIST: string = `${AppConstants.API_BASE}/x/v3/fav/resource/list`;
  /** 历史记录 */
  static readonly HISTORY_CURSOR: string = `${AppConstants.API_BASE}/x/web-interface/history/cursor`;
  static readonly HISTORY_DEL: string = `${AppConstants.API_BASE}/x/v2/history/delete`;
  static readonly HISTORY_CLEAR: string = `${AppConstants.API_BASE}/x/v2/history/clear`;

  // ---- 用户主页（P2 Task 17） ----
  static readonly USER_SPACE_INFO: string = `${AppConstants.API_BASE}/x/space/wbi/acc/info`;
  static readonly USER_RELATION_STAT: string = `${AppConstants.API_BASE}/x/relation/stat`;
  static readonly USER_SPACE_ARCHIVE: string = `${AppConstants.API_BASE}/x/space/wbi/arc/search`;
  static readonly USER_SPACE_DYNAMIC: string = `${AppConstants.API_BASE}/x/polymer/web-dynamic/v1/feed/space`;
  static readonly USER_RELATION_MODIFY: string = `${AppConstants.API_BASE}/x/relation/modify`;

  // ---- 动态详情/发布/话题（P2 Task 18） ----
  static readonly DYNAMIC_DETAIL: string = `${AppConstants.API_BASE}/x/polymer/web-dynamic/v1/detail`;
  static readonly DYNAMIC_THUMB: string = `${AppConstants.API_BASE}/x/dynamic/feed/dyn/thumb`;
  static readonly DYNAMIC_CREATE: string = `${AppConstants.API_BASE}/x/dynamic/feed/create/dyn`;
  static readonly TOPIC_RCMD: string = `${AppConstants.API_BASE}/x/topic/web/dynamic/rcmd`;
  static readonly TOPIC_FEED: string = `${AppConstants.API_BASE}/x/polymer/web-dynamic/v1/feed/topic`;

  // ---- 番剧（P2 Task 20） ----
  static readonly PGC_SEASON_DETAIL: string = `${AppConstants.API_BASE}/pgc/view/web/season`;
  static readonly PGC_SEASON_RANK: string = `${AppConstants.API_BASE}/pgc/season/rank/web/list`;
  static readonly PGC_INDEX_CONDITION: string = `${AppConstants.API_BASE}/pgc/season/index/condition`;
  static readonly PGC_INDEX_RESULT: string = `${AppConstants.API_BASE}/pgc/season/index/result`;
  static readonly PGC_FOLLOW_ADD: string = `${AppConstants.API_BASE}/pgc/web/follow/add`;
  static readonly PGC_FOLLOW_DEL: string = `${AppConstants.API_BASE}/pgc/web/follow/del`;
  static readonly PGC_PLAY_URL: string = `${AppConstants.API_BASE}/pgc/player/web/v2/playurl`;

  // ---- 音乐（P2 Task 20：音乐分区排行） ----
  static readonly RANKING_V2: string = `${AppConstants.API_BASE}/x/web-interface/ranking/v2`;
}
