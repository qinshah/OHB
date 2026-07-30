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

  // ---- 直播/用户分区排行等 P2 再补 ----
}
