import { Result } from '../../common/result/Result';
import { AppError } from '../../common/result/AppError';
import { BiliApi } from '../../network/BiliApi';
import { CookieManager } from '../../network/CookieManager';
import { BangumiDetail, BangumiEpisode, BangumiFilterGroup, BangumiFilterOption, BangumiItem } from '../../models/BangumiModels';
import { PlayUrlInfo } from '../../models/PlayUrlInfo';
import { VideoCard } from '../../models/VideoCard';

interface RawBangumiItem {
  season_id?: number;
  media_id?: number;
  title?: string;
  cover?: string;
  score?: number;
  index_show?: string;
  type_name?: string;
  order?: number;
}

interface RawRankData {
  list?: RawBangumiItem[];
}

interface RawEpisode {
  id?: number;
  aid?: number;
  bvid?: string;
  cid?: number;
  title?: string;
  long_title?: string;
  cover?: string;
  duration?: number;
  pub_time?: string;
  badge?: string;
}

interface RawSeason {
  season_id?: number;
  media_id?: number;
  title?: string;
  cover?: string;
  score?: number;
  index_show?: string;
}

interface RawRating {
  score?: number;
}

interface RawStat {
  views?: number;
  likes?: number;
  favorites?: number;
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

interface RawFilterOption {
  id?: number;
  name?: string;
}

interface RawFilter {
  name?: string;
  values?: RawFilterOption[];
}

interface RawIndexData {
  list?: RawBangumiItem[];
  total?: number;
}

interface RawDurl {
  url?: string;
  backup_url?: string[];
}

interface RawPlayData {
  quality?: number;
  timelength?: number;
  durl?: RawDurl[];
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
      return Result.err<BangumiDetail>(AppError.parse('season detail invalid'));
    }
    const detail = new BangumiDetail();
    detail.seasonId = data.season_id;
    detail.mediaId = data.media_id ?? 0;
    detail.title = data.title ?? '';
    detail.cover = VideoCard.fixUrl(data.cover ?? '');
    detail.evaluate = data.evaluate ?? '';
    detail.total = data.total ?? 0;
    detail.followCount = data.stat?.favorites ?? 0;
    detail.viewCount = data.stat?.views ?? 0;
    detail.likeCount = data.stat?.likes ?? 0;
    detail.favCount = data.stat?.favorites ?? 0;
    detail.isFollow = (data.user_status?.follow ?? 0) === 1;
    detail.episodes = (data.episodes ?? []).map((raw: RawEpisode) => {
      const ep = new BangumiEpisode();
      ep.epId = raw.id ?? 0;
      ep.aid = raw.aid ?? 0;
      ep.bvid = raw.bvid ?? '';
      ep.cid = raw.cid ?? 0;
      ep.title = raw.title ?? '';
      ep.longTitle = raw.long_title ?? '';
      ep.cover = VideoCard.fixUrl(raw.cover ?? '');
      ep.duration = raw.duration ?? 0;
      ep.pubTime = raw.pub_time ?? '';
      ep.badge = raw.badge ?? '';
      return ep;
    });
    detail.seasons = (data.seasons ?? []).map((raw: RawSeason) => BangumiRepository.parseSeason(raw));
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

  async getIndex(seasonType: number, page: number, order: number, typeId: number): Promise<Result<BangumiItem[]>> {
    const r = await this.api.pgcIndexResult(seasonType, page, order, typeId);
    if (!r.isOk) {
      return Result.err<BangumiItem[]>(r.error);
    }
    const data = r.value as RawIndexData;
    const items = (data.list ?? []).map((raw: RawBangumiItem) => BangumiRepository.parseItem(raw))
      .filter((b: BangumiItem) => b.seasonId > 0);
    return Result.ok<BangumiItem[]>(items);
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

  /** 剧集播放地址（复用 durl MP4 通道） */
  async getPlayUrl(bvid: string, cid: number, qn: number = 80): Promise<Result<PlayUrlInfo>> {
    const r = await this.api.pgcPlayUrl(bvid, cid, qn);
    if (!r.isOk) {
      return Result.err<PlayUrlInfo>(r.error);
    }
    const d = r.value as RawPlayData;
    const durl = d.durl ?? [];
    if (durl.length === 0 || durl[0].url === undefined) {
      return Result.err<PlayUrlInfo>(AppError.parse('no pgc playable url'));
    }
    const info = new PlayUrlInfo();
    info.url = VideoCard.fixUrl(durl[0].url);
    info.backupUrls = (durl[0].backup_url ?? []).map((u: string) => VideoCard.fixUrl(u));
    info.quality = d.quality ?? 0;
    info.timelength = d.timelength ?? 0;
    return Result.ok<PlayUrlInfo>(info);
  }

  private static parseItem(raw: RawBangumiItem): BangumiItem {
    const item = new BangumiItem();
    item.seasonId = raw.season_id ?? 0;
    item.mediaId = raw.media_id ?? 0;
    item.title = raw.title ?? '';
    item.cover = VideoCard.fixUrl(raw.cover ?? '');
    item.score = raw.score ?? 0;
    item.indexShow = raw.index_show ?? '';
    item.typeName = raw.type_name ?? '';
    return item;
  }

  private static parseSeason(raw: RawSeason): BangumiItem {
    const item = new BangumiItem();
    item.seasonId = raw.season_id ?? 0;
    item.mediaId = raw.media_id ?? 0;
    item.title = raw.title ?? '';
    item.cover = VideoCard.fixUrl(raw.cover ?? '');
    item.score = raw.score ?? 0;
    item.indexShow = raw.index_show ?? '';
    return item;
  }
}
