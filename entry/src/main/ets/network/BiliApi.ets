import { Result } from '../common/result/Result';
import { AppConstants } from '../common/constants/AppConstants';
import { ApiConstants } from './ApiConstants';
import { ChannelType, HttpClient } from './HttpClient';
import { SearchType } from '../models/SearchModels';

/**
 * Bilibili API 调用层（DataSource，Task 2/3）
 * 只负责发请求并返回原始 data Object；模型解析在 Repository 完成。
 */
export class BiliApi {
  private http: HttpClient = HttpClient.getInstance();

  // ---------- 用户 ----------

  /** nav 用户信息（含 WBI key） */
  nav(): Promise<Result<Object>> {
    return this.http.get(ApiConstants.NAV, {}, ChannelType.Raw);
  }

  // ---------- 推荐 / 热门 ----------

  /** Web 端推荐视频流（WBI 签名） */
  recommendWeb(freshIdx: number): Promise<Result<Object>> {
    return this.http.get(ApiConstants.RCMD_WEB, {
      'version': 1,
      'feed_version': 'V8',
      'homepage_ver': 1,
      'ps': AppConstants.PAGE_SIZE,
      'fresh_idx': freshIdx,
      'brush': freshIdx,
      'fresh_type': 4
    }, ChannelType.Web);
  }

  /** 热门视频 */
  popular(pn: number): Promise<Result<Object>> {
    return this.http.get(ApiConstants.POPULAR, {
      'pn': pn,
      'ps': AppConstants.PAGE_SIZE
    }, ChannelType.Raw);
  }

  // ---------- 视频 ----------

  videoDetail(bvid: string): Promise<Result<Object>> {
    return this.http.get(ApiConstants.VIDEO_DETAIL, { 'bvid': bvid }, ChannelType.Raw);
  }

  /**
   * 播放地址（WBI 签名）
   * V1 采用 fnval=1（muxed MP4 durl），保证 AVPlayer 可靠起播；
   * DASH 多清晰度在 P1（Task 12）完善。
   */
  playUrl(bvid: string, cid: number, qn: number = 80): Promise<Result<Object>> {
    return this.http.get(ApiConstants.PLAY_URL, {
      'bvid': bvid,
      'cid': cid,
      'qn': qn,
      'fnval': 1,
      'fnver': 0,
      'fourk': 1,
      'platform': 'pc',
      'voice_balance': 1,
      'web_location': 1315873
    }, ChannelType.Web);
  }

  // ---------- 搜索 ----------

  /** 搜索建议（非标准包络：{"code":0,"result":{"tag":[...]}}，走裸 JSON） */
  searchSuggest(term: string): Promise<Result<Object>> {
    return this.http.getRawJson(ApiConstants.SEARCH_SUGGEST, {
      'term': term,
      'main_ver': 'v1',
      'highlight': ''
    });
  }

  /** 热搜榜 */
  searchTrending(): Promise<Result<Object>> {
    return this.http.get(ApiConstants.SEARCH_TRENDING, { 'limit': 30 }, ChannelType.Raw);
  }

  /** 分类搜索（WBI 签名） */
  searchByType(type: SearchType, keyword: string, page: number, order: string = '',
    duration: number = 0, tids: number = 0): Promise<Result<Object>> {
    const params: Record<string, string | number | boolean> = {
      'search_type': type,
      'keyword': keyword,
      'page': page,
      'page_size': AppConstants.PAGE_SIZE,
      'platform': 'pc',
      'web_location': 1430654
    };
    if (order.length > 0) {
      params['order'] = order;
    }
    if (duration > 0) {
      params['duration'] = duration;
    }
    if (tids > 0) {
      params['tids'] = tids;
    }
    return this.http.get(ApiConstants.SEARCH_TYPE, params, ChannelType.Web, AppConstants.SEARCH_REFERER);
  }

  // ---------- 动态 ----------

  /** 关注动态流 */
  dynamicFeed(offset: string): Promise<Result<Object>> {
    return this.http.get(ApiConstants.DYNAMIC_FEED, {
      'type': 'all',
      'timezone_offset': -480,
      'offset': offset,
      'features': 'itemOpusStyle,listOnlyfans,onlyfansQaCard'
    }, ChannelType.Raw);
  }

  // ---------- TV 扫码登录 ----------

  /** 申请登录二维码（AppSign + App UA） */
  tvQrCodeAuth(): Promise<Result<Object>> {
    return this.http.post(ApiConstants.TV_QRCODE_AUTH, {
      'local_id': '0',
      'platform': 'android',
      'mobi_app': 'android_hd'
    }, ChannelType.App, true);
  }

  /** 轮询扫码状态 */
  tvQrCodePoll(authCode: string): Promise<Result<Object>> {
    return this.http.post(ApiConstants.TV_QRCODE_POLL, {
      'auth_code': authCode,
      'local_id': '0',
      'platform': 'android',
      'mobi_app': 'android_hd'
    }, ChannelType.App, true);
  }
}
