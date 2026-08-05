import { Result } from '../common/result/Result';
import { AppConstants } from '../common/constants/AppConstants';
import { ApiConstants } from './ApiConstants';
import { ChannelType, HttpClient } from './HttpClient';
import { SearchType } from '../models/SearchModels';

/**
 * Bilibili API 调用层（DataSource，Task 2/3 + P2 扩展）
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

  /** 番剧播放地址（P2 Task 20） */
  pgcPlayUrl(bvid: string, cid: number, qn: number = 80): Promise<Result<Object>> {
    return this.http.get(ApiConstants.PGC_PLAY_URL, {
      'bvid': bvid,
      'cid': cid,
      'qn': qn,
      'fnval': 1,
      'fourk': 1,
      'platform': 'pc'
    }, ChannelType.Raw);
  }

  // ---------- 视频互动（P2 Task 13） ----------

  /** 相关视频 */
  relatedVideos(bvid: string): Promise<Result<Object>> {
    return this.http.get(ApiConstants.ARCHIVE_RELATED, { 'bvid': bvid }, ChannelType.Raw);
  }

  /** 点赞/取消赞（App 通道，like=1 点赞 2 取消） */
  likeVideo(aid: number, like: number): Promise<Result<Object>> {
    return this.http.post(ApiConstants.VIDEO_LIKE, { 'aid': aid, 'like': like }, ChannelType.App);
  }

  /** 投币（App 通道，multiply 1~2，select_like 是否连赞） */
  coinVideo(aid: number, multiply: number, selectLike: number): Promise<Result<Object>> {
    return this.http.post(ApiConstants.VIDEO_COIN, {
      'aid': aid,
      'multiply': multiply,
      'select_like': selectLike
    }, ChannelType.App);
  }

  /** 一键三连 */
  tripleVideo(aid: number, csrf: string): Promise<Result<Object>> {
    return this.http.post(ApiConstants.VIDEO_TRIPLE, { 'aid': aid, 'csrf': csrf }, ChannelType.Raw);
  }

  /** 收藏/取消收藏（add_media_ids / del_media_ids 逗号分隔） */
  favResourceDeal(rid: number, addMediaIds: string, delMediaIds: string, csrf: string): Promise<Result<Object>> {
    return this.http.post(ApiConstants.FAV_RESOURCE_DEAL, {
      'rid': rid,
      'type': 2,
      'add_media_ids': addMediaIds,
      'del_media_ids': delMediaIds,
      'csrf': csrf
    }, ChannelType.Raw);
  }

  /** 稍后再看：加入 */
  toviewAdd(aid: number, csrf: string): Promise<Result<Object>> {
    return this.http.post(ApiConstants.TOVIEW_ADD, { 'aid': aid, 'csrf': csrf }, ChannelType.Raw);
  }

  /** 稍后再看：列表 */
  toviewList(): Promise<Result<Object>> {
    return this.http.get(ApiConstants.TOVIEW_WEB_LIST, {}, ChannelType.Raw);
  }

  /** 稍后再看：移除 */
  toviewDel(viewed: number, csrf: string): Promise<Result<Object>> {
    return this.http.post(ApiConstants.TOVIEW_DEL, { 'viewed': viewed, 'del': 1, 'csrf': csrf }, ChannelType.Raw);
  }

  /** 稍后再看：清空 */
  toviewClear(csrf: string): Promise<Result<Object>> {
    return this.http.post(ApiConstants.TOVIEW_CLEAR, { 'csrf': csrf }, ChannelType.Raw);
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

  /** 动态详情（P2 Task 18） */
  dynamicDetail(id: string): Promise<Result<Object>> {
    return this.http.get(ApiConstants.DYNAMIC_DETAIL, {
      'timezone_offset': -480,
      'id': id,
      'features': 'itemOpusStyle,listOnlyfans,onlyfansQaCard'
    }, ChannelType.Raw);
  }

  /** 动态点赞（up=1 点赞 / 0 取消） */
  dynamicThumb(dynIdStr: string, up: number, csrf: string): Promise<Result<Object>> {
    return this.http.post(ApiConstants.DYNAMIC_THUMB, {
      'dyn_id_str': dynIdStr,
      'up': up,
      'spmid': '333.1365.0.0',
      'csrf': csrf
    }, ChannelType.Raw);
  }

  /** 发布动态（dyn_req 为 JSON 字符串） */
  dynamicCreate(dynReqJson: string, csrf: string): Promise<Result<Object>> {
    return this.http.post(ApiConstants.DYNAMIC_CREATE, {
      'platform': 'web',
      'csrf': csrf,
      'dyn_req': dynReqJson
    }, ChannelType.Raw);
  }

  /** 话题推荐（话题广场） */
  topicRcmd(pageSize: number): Promise<Result<Object>> {
    return this.http.get(ApiConstants.TOPIC_RCMD, {
      'source': 'Web',
      'page_size': pageSize,
      'web_location': 333.1365
    }, ChannelType.Raw);
  }

  /** 话题动态流 */
  topicFeed(topicId: number, offset: string, sortBy: number): Promise<Result<Object>> {
    const params: Record<string, string | number | boolean> = {
      'topic_id': topicId,
      'sort_by': sortBy,
      'page_size': 20,
      'source': 'Web',
      'features': 'itemOpusStyle,listOnlyfans,onlyfansQaCard'
    };
    if (offset.length > 0) {
      params['offset'] = offset;
    }
    return this.http.get(ApiConstants.TOPIC_FEED, params, ChannelType.Raw);
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

  // ---------- 评论（P2 Task 14） ----------

  /** 主评论列表（paginationStr 为 cursor JSON 字符串） */
  replyMain(type: number, oid: number | string, mode: number, paginationStr: string): Promise<Result<Object>> {
    return this.http.get(ApiConstants.REPLY_MAIN, {
      'type': type,
      'oid': oid,
      'mode': mode,
      'plat': 1,
      'pagination_str': paginationStr,
      'ps': 20
    }, ChannelType.Raw);
  }

  /** 楼中楼 */
  replyReply(type: number, oid: number | string, root: number, pn: number, ps: number): Promise<Result<Object>> {
    return this.http.get(ApiConstants.REPLY_REPLY, {
      'type': type,
      'oid': oid,
      'root': root,
      'pn': pn,
      'ps': ps
    }, ChannelType.Raw);
  }

  /** 发表评论（root/parent 为 0 表示顶层评论） */
  replyAdd(type: number, oid: number | string, message: string, root: number, parent: number, csrf: string): Promise<Result<Object>> {
    return this.http.post(ApiConstants.REPLY_ADD, {
      'type': type,
      'oid': oid,
      'message': message,
      'root': root,
      'parent': parent,
      'plat': 1,
      'csrf': csrf
    }, ChannelType.Raw);
  }

  /** 评论点赞（action=1 赞 / 2 取消赞） */
  replyAction(type: number, oid: number | string, rpid: number, action: number, csrf: string): Promise<Result<Object>> {
    return this.http.post(ApiConstants.REPLY_ACTION, {
      'type': type,
      'oid': oid,
      'rpid': rpid,
      'action': action,
      'csrf': csrf
    }, ChannelType.Raw);
  }

  /** 删除评论 */
  replyDel(type: number, oid: number | string, rpid: number, csrf: string): Promise<Result<Object>> {
    return this.http.post(ApiConstants.REPLY_DEL, {
      'type': type,
      'oid': oid,
      'rpid': rpid,
      'csrf': csrf
    }, ChannelType.Raw);
  }

  // ---------- 直播（P2 Task 15） ----------

  /** 直播分区列表（App 通道） */
  liveAreaList(): Promise<Result<Object>> {
    return this.http.get(ApiConstants.LIVE_AREA_LIST, {}, ChannelType.App);
  }

  /** 直播二级列表（App 通道，parentAreaId=0 全部） */
  liveSecondList(page: number, areaId: number, parentAreaId: number): Promise<Result<Object>> {
    const params: Record<string, string | number | boolean> = {
      'page': page,
      'page_size': 20,
      'parent_area_id': parentAreaId,
      'sort_type': '',
      'platform': 'android'
    };
    if (areaId > 0) {
      params['area_id'] = areaId;
    }
    return this.http.get(ApiConstants.LIVE_SECOND_LIST, params, ChannelType.App);
  }

  /** 直播间播放信息（取第一个可播流） */
  liveRoomPlayInfo(roomId: number): Promise<Result<Object>> {
    return this.http.get(ApiConstants.LIVE_ROOM_PLAY_INFO, {
      'room_id': roomId,
      'protocol': '0,1',
      'format': '0,1,2',
      'codec': '0,1,2',
      'qn': 10000,
      'platform': 'web',
      'ptype': 8
    }, ChannelType.Raw);
  }

  /** 直播弹幕密钥（含 ws host） */
  liveDmToken(roomId: number): Promise<Result<Object>> {
    return this.http.get(ApiConstants.LIVE_DM_TOKEN, { 'id': roomId }, ChannelType.Raw);
  }

  /** 直播弹幕历史 */
  liveDmPrefetch(roomId: number): Promise<Result<Object>> {
    return this.http.get(ApiConstants.LIVE_DM_PREFETCH, { 'roomid': roomId }, ChannelType.Raw);
  }

  /** 发送直播弹幕 */
  liveSendMsg(roomId: number, msg: string, csrf: string): Promise<Result<Object>> {
    return this.http.post(ApiConstants.LIVE_SEND_MSG, {
      'bubble': 0,
      'msg': msg,
      'color': 16777215,
      'mode': 1,
      'fontsize': 25,
      'room_type': 0,
      'jumpfrom': 0,
      'reply_mid': 0,
      'reply_attr': 0,
      'replay_dmid': '',
      'statistics': '{"appId":100,"platform":5}',
      'reply_type': 0,
      'reply_uname': '',
      'rnd': Math.floor(Date.now() / 1000),
      'roomid': roomId,
      'csrf': csrf,
      'csrf_token': csrf
    }, ChannelType.Raw);
  }

  /** 添加直播屏蔽词 */
  liveShieldAdd(keyword: string, csrf: string): Promise<Result<Object>> {
    return this.http.post(ApiConstants.LIVE_SHIELD_ADD, {
      'keyword': keyword,
      'csrf': csrf,
      'csrf_token': csrf
    }, ChannelType.Raw);
  }

  /** 删除直播屏蔽词 */
  liveShieldDel(keyword: string, csrf: string): Promise<Result<Object>> {
    return this.http.post(ApiConstants.LIVE_SHIELD_DEL, {
      'keyword': keyword,
      'csrf': csrf,
      'csrf_token': csrf
    }, ChannelType.Raw);
  }

  // ---------- 收藏/历史（P2 Task 16） ----------

  /** 创建的收藏夹（全部） */
  favFolderListAll(upMid: number): Promise<Result<Object>> {
    return this.http.get(ApiConstants.FAV_FOLDER_LIST_ALL, {
      'up_mid': upMid,
      'type': 2
    }, ChannelType.Raw);
  }

  /** 收藏夹内视频 */
  favResourceList(mediaId: number, pn: number, ps: number): Promise<Result<Object>> {
    return this.http.get(ApiConstants.FAV_RESOURCE_LIST, {
      'media_id': mediaId,
      'pn': pn,
      'ps': ps,
      'keyword': '',
      'order': 'mtime',
      'type': 0,
      'tid': 0,
      'platform': 'web'
    }, ChannelType.Raw);
  }

  /** 历史记录（游标分页） */
  historyCursor(max: number, viewAt: number, ps: number): Promise<Result<Object>> {
    return this.http.get(ApiConstants.HISTORY_CURSOR, {
      'type': 'archive',
      'ps': ps,
      'max': max,
      'view_at': viewAt
    }, ChannelType.Raw);
  }

  /** 删除历史记录 */
  historyDel(kid: string, csrf: string): Promise<Result<Object>> {
    return this.http.post(ApiConstants.HISTORY_DEL, { 'kid': kid, 'csrf': csrf }, ChannelType.Raw);
  }

  /** 清空历史记录 */
  historyClear(csrf: string): Promise<Result<Object>> {
    return this.http.post(ApiConstants.HISTORY_CLEAR, { 'csrf': csrf }, ChannelType.Raw);
  }

  // ---------- 用户主页（P2 Task 17） ----------

  /** 用户空间信息（WBI） */
  userSpaceInfo(mid: number): Promise<Result<Object>> {
    return this.http.get(ApiConstants.USER_SPACE_INFO, {
      'mid': mid,
      'platform': 'web',
      'web_location': 1550101
    }, ChannelType.Web);
  }

  /** 用户关系统计 */
  userRelationStat(mid: number): Promise<Result<Object>> {
    return this.http.get(ApiConstants.USER_RELATION_STAT, { 'vmid': mid }, ChannelType.Raw);
  }

  /** 用户投稿（WBI） */
  userSpaceArchive(mid: number, pn: number, ps: number): Promise<Result<Object>> {
    return this.http.get(ApiConstants.USER_SPACE_ARCHIVE, {
      'mid': mid,
      'pn': pn,
      'ps': ps,
      'tid': 0,
      'keyword': '',
      'order': 'pubdate',
      'platform': 'web',
      'web_location': 1550101,
      'order_avoided': true
    }, ChannelType.Web);
  }

  /** 用户动态 */
  userSpaceDynamic(mid: number, offset: string): Promise<Result<Object>> {
    return this.http.get(ApiConstants.USER_SPACE_DYNAMIC, {
      'host_mid': mid,
      'timezone_offset': -480,
      'offset': offset,
      'features': 'itemOpusStyle,listOnlyfans,onlyfansQaCard'
    }, ChannelType.Raw);
  }

  /** 关注/取关（act=1 关注 2 取关） */
  relationModify(fid: number, act: number, csrf: string): Promise<Result<Object>> {
    return this.http.post(ApiConstants.USER_RELATION_MODIFY, {
      'fid': fid,
      'act': act,
      're_src': 11,
      'csrf': csrf
    }, ChannelType.Raw);
  }

  // ---------- 番剧（P2 Task 20） ----------

  /** 番剧详情 */
  pgcSeasonDetail(seasonId: number): Promise<Result<Object>> {
    return this.http.get(ApiConstants.PGC_SEASON_DETAIL, { 'season_id': seasonId }, ChannelType.Raw);
  }

  /** 番剧排行 */
  pgcSeasonRank(seasonType: number, day: number): Promise<Result<Object>> {
    return this.http.get(ApiConstants.PGC_SEASON_RANK, {
      'season_type': seasonType,
      'day': day
    }, ChannelType.Raw);
  }

  /** 番剧索引条件 */
  pgcIndexCondition(seasonType: number): Promise<Result<Object>> {
    return this.http.get(ApiConstants.PGC_INDEX_CONDITION, { 'season_type': seasonType }, ChannelType.Raw);
  }

  /** 番剧索引结果 */
  pgcIndexResult(seasonType: number, page: number, order: number, typeId: number): Promise<Result<Object>> {
    return this.http.get(ApiConstants.PGC_INDEX_RESULT, {
      'season_type': seasonType,
      'page': page,
      'page_size': 20,
      'order': order,
      'type': typeId
    }, ChannelType.Raw);
  }

  /** 追番/取消追番 */
  pgcFollow(seasonId: number, act: number, csrf: string): Promise<Result<Object>> {
    const url = act === 1 ? ApiConstants.PGC_FOLLOW_ADD : ApiConstants.PGC_FOLLOW_DEL;
    return this.http.post(url, { 'season_id': seasonId, 'csrf': csrf }, ChannelType.Raw);
  }

  // ---------- 音乐（P2 Task 20：分区排行） ----------

  /** 分区排行（rid=3 音乐） */
  ranking(rid: number): Promise<Result<Object>> {
    return this.http.get(ApiConstants.RANKING_V2, { 'rid': rid }, ChannelType.Raw);
  }
}
