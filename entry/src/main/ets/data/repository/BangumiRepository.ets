import { Result } from '../../common/result/Result';
import { AppError } from '../../common/result/AppError';
import { BiliApi } from '../../network/BiliApi';
import { CookieManager } from '../../network/CookieManager';
import {
  BangumiConditionGroup,
  BangumiConditionValue,
  BangumiDetail,
  BangumiEpisode,
  BangumiIndexCondition,
  BangumiIndexResult,
  BangumiItem,
  BangumiOrderItem
} from '../../models/BangumiModels';
import { PlayUrlInfo } from '../../models/PlayUrlInfo';
import { VideoCard } from '../../models/VideoCard';

/** 每页条数（3 列网格 × 7 行，对齐 PiliPlus pagesize=21） */
export const BANGUMI_INDEX_PAGE_SIZE: number = 21;

interface RawBadgeInfo {
  bg_color?: string;
  bg_color_night?: string;
  text?: string;
}

/** 索引条目的首集信息（first_ep） */
interface RawFirstEp {
  ep_id?: number;
  cover?: string;
}

interface RawBangumiItem {
  season_id?: number;
  media_id?: number;
  title?: string;
  cover?: string;
  score?: string;
  index_show?: string;
  type_name?: string;
  order?: string;
  subTitle?: string;
  badge?: string;
  badge_type?: number;
  badge_info?: RawBadgeInfo;
  /** 首集信息（卡片点击直达播放时用于定位入口剧集） */
  first_ep?: RawFirstEp;
}

interface RawRankData {
  list?: RawBangumiItem[];
}

interface RawEpisode {
  /** 剧集 id（与 ep_id 同值，接口两个字段都给） */
  id?: number;
  ep_id?: number;
  aid?: number;
  bvid?: string;
  cid?: number;
  title?: string;
  long_title?: string;
  cover?: string;
  /** 时长（毫秒，番剧单位为 ms） */
  duration?: number;
  /** 首播时间（Unix 秒） */
  pub_time?: number;
  badge?: string;
}

interface RawSeason {
  season_id?: number;
  media_id?: number;
  /** 首季/本季标题在 seasons[] 里是 season_title（title 为空） */
  title?: string;
  season_title?: string;
  cover?: string;
  score?: number;
  index_show?: string;
  new_ep?: RawNewEp;
}

interface RawRating {
  score?: number;
}

/** 最新一话信息（new_ep.desc 形如 "6月13日起 每周六11:00"） */
interface RawNewEp {
  desc?: string;
  title?: string;
}

interface RawStat {
  views?: number;
  likes?: number;
  /** 追番数（配合 follow_text，如 "1782.2万追番"） */
  favorites?: number;
  /** 收藏数 */
  favorite?: number;
}

interface RawUserStatus {
  follow?: number;
}

interface RawSeasonData {
  season_id?: number;
  media_id?: number;
  title?: string;
  cover?: string;
  evaluate?: string;
  total?: number;
  rating?: RawRating;
  stat?: RawStat;
  user_status?: RawUserStatus;
  episodes?: RawEpisode[];
  seasons?: RawSeason[];
}

interface RawConditionValue {
  keyword?: string;
  name?: string;
}

interface RawConditionFilter {
  field?: string;
  name?: string;
  values?: RawConditionValue[];
}

interface RawConditionOrder {
  field?: string;
  name?: string;
  sort?: string;
}

interface RawConditionData {
  filter?: RawConditionFilter[];
  order?: RawConditionOrder[];
}

interface RawIndexData {
  list?: RawBangumiItem[];
  total?: number;
  has_next?: number;
}

interface RawPlayDurl {
  url?: string;
  backup_url?: string[];
  /** 片长（毫秒） */
  length?: number;
}

/** /pgc/player/web/v2/playurl 的 result.video_info */
interface RawPlayVideoInfo {
  quality?: number;
  timelength?: number;
  durl?: RawPlayDurl[];
  durls?: RawPlayDurl[];
}

/** /pgc/player/web/v2/playurl 的 result（兼容旧版平铺结构） */
interface RawPlayResult {
  /** v2：视频信息在 result.video_info */
  video_info?: RawPlayVideoInfo;
  /** v1（旧）：durl/quality 直接平铺在 result 下 */
  durl?: RawPlayDurl[];
  quality?: number;
  timelength?: number;
}

/**
 * 番剧仓库（P2 Task 20）：详情、排行、索引、追番、播放地址。
 */
export class BangumiRepository {
  private api: BiliApi = new BiliApi();

  async getDetail(seasonId: number): Promise<Result<BangumiDetail>> {
    const r = await this.api.pgcSeasonDetail(seasonId);
    if (!r.isOk) {
      return Result.err<BangumiDetail>(r.error);
    }
    const data = r.value as RawSeasonData;
    if (data.season_id === undefined) {
      // 走到这里说明包络解析拿到了非 season 载荷（接口异常或字段变更）
      return Result.err<BangumiDetail>(AppError.parse('season detail invalid'));
    }
    const detail = new BangumiDetail();
    detail.seasonId = data.season_id;
    detail.mediaId = data.media_id ?? 0;
    detail.title = data.title ?? '';
    detail.cover = VideoCard.fixUrl(data.cover ?? '');
    detail.evaluate = data.evaluate ?? '';
    const episodes = data.episodes ?? [];
    // 接口 total 常为 0（如季番/长篇），回退为剧集列表长度
    const apiTotal = data.total ?? 0;
    detail.total = apiTotal > 0 ? apiTotal : episodes.length;
    const stat = data.stat;
    // favorites = 追番数（与 stat.follow_text 一致），favorite = 收藏数
    detail.followCount = stat?.favorites ?? 0;
    detail.viewCount = stat?.views ?? 0;
    detail.likeCount = stat?.likes ?? 0;
    detail.favCount = stat?.favorite ?? 0;
    detail.isFollow = (data.user_status?.follow ?? 0) === 1;
    detail.episodes = episodes.map((raw: RawEpisode) => {
      const ep = new BangumiEpisode();
      ep.epId = raw.ep_id ?? raw.id ?? 0;
      ep.aid = raw.aid ?? 0;
      ep.bvid = raw.bvid ?? '';
      ep.cid = raw.cid ?? 0;
      ep.title = raw.title ?? '';
      ep.longTitle = raw.long_title ?? '';
      ep.cover = VideoCard.fixUrl(raw.cover ?? '');
      ep.duration = raw.duration ?? 0;
      ep.pubTime = raw.pub_time ?? 0;
      ep.badge = raw.badge ?? '';
      return ep;
    });
    // seasons[] 会把自己也算进来，过滤掉当前季避免「其他季」出现重复空行
    detail.seasons = (data.seasons ?? [])
      .map((raw: RawSeason) => BangumiRepository.parseSeason(raw))
      .filter((s: BangumiItem) => s.seasonId > 0 && s.seasonId !== detail.seasonId);
    return Result.ok<BangumiDetail>(detail);
  }

  async getRank(seasonType: number, day: number): Promise<Result<BangumiItem[]>> {
    const r = await this.api.pgcSeasonRank(seasonType, day);
    if (!r.isOk) {
      return Result.err<BangumiItem[]>(r.error);
    }
    const data = r.value as RawRankData;
    const items = (data.list ?? []).map((raw: RawBangumiItem) => BangumiRepository.parseItem(raw))
      .filter((b: BangumiItem) => b.seasonId > 0);
    return Result.ok<BangumiItem[]>(items);
  }

  /**
   * 番剧索引条件：排序项 + 筛选分组。
   * 对齐 PiliPlus PgcIndexController.getPgcIndexCondition（season_type=1、type=0）。
   */
  async getIndexCondition(seasonType: number): Promise<Result<BangumiIndexCondition>> {
    const r = await this.api.pgcIndexCondition(seasonType);
    if (!r.isOk) {
      return Result.err<BangumiIndexCondition>(r.error);
    }
    const data = r.value as RawConditionData;
    const cond = new BangumiIndexCondition();
    cond.orders = (data.order ?? []).map((raw: RawConditionOrder) => {
      const o = new BangumiOrderItem();
      o.field = raw.field ?? '';
      o.name = raw.name ?? '';
      o.sort = raw.sort ?? '';
      return o;
    }).filter((o: BangumiOrderItem) => o.field.length > 0);
    cond.filters = (data.filter ?? []).map((raw: RawConditionFilter) => {
      const g = new BangumiConditionGroup();
      g.field = raw.field ?? '';
      g.name = raw.name ?? '';
      g.values = (raw.values ?? []).map((v: RawConditionValue) => {
        const cv = new BangumiConditionValue();
        cv.keyword = v.keyword ?? '';
        cv.name = v.name ?? '';
        return cv;
      });
      return g;
    }).filter((g: BangumiConditionGroup) => g.field.length > 0 && g.values.length > 0);
    return Result.ok<BangumiIndexCondition>(cond);
  }

  /**
   * 番剧索引结果：params 为当前选中的 order / 各 filter 分组，
   * 这里补全分页参数后请求（对齐 PiliPlus PgcHttp.pgcIndexResult）。
   */
  async getIndexResult(params: Record<string, string | number | boolean>, page: number): Promise<Result<BangumiIndexResult>> {
    const query: Record<string, string | number | boolean> = {};
    const keys = Object.keys(params);
    for (let i = 0; i < keys.length; i++) {
      query[keys[i]] = params[keys[i]];
    }
    query['page'] = page;
    query['pagesize'] = BANGUMI_INDEX_PAGE_SIZE;
    const r = await this.api.pgcIndexResult(query);
    if (!r.isOk) {
      return Result.err<BangumiIndexResult>(r.error);
    }
    const data = r.value as RawIndexData;
    const res = new BangumiIndexResult();
    res.items = (data.list ?? []).map((raw: RawBangumiItem) => BangumiRepository.parseItem(raw))
      .filter((b: BangumiItem) => b.seasonId > 0);
    res.hasNext = (data.has_next ?? 0) !== 0;
    return Result.ok<BangumiIndexResult>(res);
  }

  async follow(seasonId: number, follow: boolean): Promise<Result<boolean>> {
    const csrf = CookieManager.getInstance().csrf;
    if (csrf.length === 0) {
      return Result.err<boolean>(AppError.unauthorized('请先登录后追番'));
    }
    const r = await this.api.pgcFollow(seasonId, follow ? 1 : 2, csrf);
    if (!r.isOk) {
      return Result.err<boolean>(r.error);
    }
    return Result.ok<boolean>(true);
  }

  /** 剧集播放地址（/pgc/player/web/v2/playurl，MP4 durl 通道，AvPlayer 可直接播） */
  async getPlayUrl(bvid: string, cid: number, qn: number = 80): Promise<Result<PlayUrlInfo>> {
    const r = await this.api.pgcPlayUrl(bvid, cid, qn);
    if (!r.isOk) {
      return Result.err<PlayUrlInfo>(r.error);
    }
    const res = r.value as RawPlayResult;
    // v2 结构：result.video_info.{durl,quality,timelength}；旧版结构直接平铺在 result 下
    const video: RawPlayVideoInfo | undefined = res.video_info;
    let durl: RawPlayDurl[] = [];
    let quality = 0;
    let timelength = 0;
    if (video !== undefined && video !== null) {
      durl = video.durl ?? video.durls ?? [];
      quality = video.quality ?? 0;
      timelength = video.timelength ?? 0;
    } else {
      durl = res.durl ?? [];
      quality = res.quality ?? 0;
      timelength = res.timelength ?? 0;
    }
    if (durl.length === 0 || durl[0].url === undefined) {
      return Result.err<PlayUrlInfo>(AppError.parse('no pgc playable url'));
    }
    const info = new PlayUrlInfo();
    info.url = VideoCard.fixUrl(durl[0].url);
    info.backupUrls = (durl[0].backup_url ?? []).map((u: string) => VideoCard.fixUrl(u));
    info.quality = quality;
    info.timelength = timelength > 0 ? timelength : (durl[0].length ?? 0);
    return Result.ok<PlayUrlInfo>(info);
  }

  private static parseItem(raw: RawBangumiItem): BangumiItem {
    const item = new BangumiItem();
    item.seasonId = raw.season_id ?? 0;
    item.mediaId = raw.media_id ?? 0;
    item.title = raw.title ?? '';
    item.cover = VideoCard.fixUrl(raw.cover ?? '');
    item.score = BangumiRepository.parseScore(raw.score);
    item.indexShow = raw.index_show ?? '';
    item.typeName = raw.type_name ?? '';
    item.badge = BangumiRepository.parseBadgeText(raw);
    item.badgeColor = raw.badge_info?.bg_color ?? '';
    item.subTitle = raw.subTitle ?? '';
    item.order = raw.order ?? '';
    item.firstEpId = raw.first_ep?.ep_id ?? 0;
    return item;
  }

  /** 角标文案：优先 badge_info.text，回退 badge（接口两者可能一空一有） */
  private static parseBadgeText(raw: RawBangumiItem): string {
    const info = raw.badge_info;
    if (info !== undefined && info !== null) {
      const text = info.text;
      if (text !== undefined && text !== null && text.length > 0) {
        return text;
      }
    }
    return raw.badge ?? '';
  }

  /** 评分：接口 score 为字符串（"9.7" / ""），空串与非法值统一按 0（无评分）处理 */
  private static parseScore(raw: string | undefined): number {
    if (raw === undefined || raw === null || raw.length === 0) {
      return 0;
    }
    const v = Number(raw);
    return isNaN(v) ? 0 : v;
  }

  private static parseSeason(raw: RawSeason): BangumiItem {
    const item = new BangumiItem();
    item.seasonId = raw.season_id ?? 0;
    item.mediaId = raw.media_id ?? 0;
    // seasons[] 用 season_title 承载标题，title 通常为空
    item.title = raw.season_title ?? raw.title ?? '';
    item.cover = VideoCard.fixUrl(raw.cover ?? '');
    item.score = raw.score ?? 0;
    item.indexShow = raw.index_show ?? raw.new_ep?.desc ?? '';
    return item;
  }
}
