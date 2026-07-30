import { Result } from '../../common/result/Result';
import { AppError } from '../../common/result/AppError';
import { BiliApi } from '../../network/BiliApi';
import { VideoCard } from '../../models/VideoCard';
import { VideoDetail, VideoPage } from '../../models/VideoDetail';
import { PlayUrlInfo } from '../../models/PlayUrlInfo';
import { PrefsStorage } from '../../services/storage/PrefsStorage';
import { AccountManager } from '../../services/account/AccountManager';
import { common } from '@kit.AbilityKit';

// ---- 原始 JSON 形状 ----
interface RawOwner {
  mid?: number;
  name?: string;
  face?: string;
}

interface RawStat {
  view?: number;
  danmaku?: number;
  like?: number;
  reply?: number;
  favorite?: number;
  coin?: number;
  share?: number;
}

interface RawRcmdItem {
  bvid?: string;
  id?: number;
  cid?: number;
  title?: string;
  pic?: string;
  cover?: string;
  duration?: number;
  pubdate?: number;
  tname?: string;
  owner?: RawOwner;
  stat?: RawStat;
  rcmd_reason?: RawRcmdReason;
}

interface RawRcmdReason {
  content?: string;
}

interface RawRcmdData {
  item?: RawRcmdItem[];
}

interface RawPopularData {
  list?: RawRcmdItem[];
}

interface RawDetailPage {
  cid?: number;
  part?: string;
  page?: number;
  duration?: number;
}

interface RawDetailData {
  bvid?: string;
  aid?: number;
  title?: string;
  desc?: string;
  pic?: string;
  duration?: number;
  pubdate?: number;
  owner?: RawOwner;
  stat?: RawStat;
  pages?: RawDetailPage[];
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

/** 推荐/热门/搜索共用解析 */
function parseCard(raw: RawRcmdItem): VideoCard {
  const c = new VideoCard();
  c.bvid = raw.bvid ?? '';
  c.aid = raw.id ?? 0;
  c.cid = raw.cid ?? 0;
  c.title = raw.title ?? '';
  c.cover = VideoCard.fixUrl(raw.pic ?? raw.cover ?? '');
  c.duration = raw.duration ?? 0;
  c.pubdate = raw.pubdate ?? 0;
  c.tname = raw.tname ?? '';
  c.ownerName = raw.owner?.name ?? '';
  c.ownerMid = raw.owner?.mid ?? 0;
  c.ownerFace = VideoCard.fixUrl(raw.owner?.face ?? '');
  c.playCount = raw.stat?.view ?? 0;
  c.danmakuCount = raw.stat?.danmaku ?? 0;
  c.likeCount = raw.stat?.like ?? 0;
  c.rcmdReason = raw.rcmd_reason?.content ?? '';
  return c;
}

/**
 * 视频仓库（Task 6/9）：推荐流、热门、详情、播放地址。
 * 推荐过滤（黑名单用户/关键词/低赞比）在此完成（FR-1）。
 */
export class VideoRepository {
  private api: BiliApi = new BiliApi();
  private filterPrefs: PrefsStorage | null = null;

  initFilter(context: common.Context): void {
    const am = AccountManager.getInstance();
    this.filterPrefs = new PrefsStorage(context, am.currentUserPrefName());
  }

  /** 用户级过滤设置（可在设置中心扩展） */
  private get filterBlackMids(): number[] {
    const raw = this.filterPrefs?.getString('filter_black_mids', '') ?? '';
    if (raw.length === 0) {
      return [];
    }
    return raw.split(',').map((s: string) => Number(s)).filter((n: number) => n > 0);
  }

  private get filterKeywords(): string[] {
    const raw = this.filterPrefs?.getString('filter_keywords', '') ?? '';
    if (raw.length === 0) {
      return [];
    }
    return raw.split(',').filter((s: string) => s.trim().length > 0);
  }

  private get filterMinLikeRatio(): number {
    return this.filterPrefs?.getNumber('filter_min_like_ratio', 0) ?? 0;
  }

  /** 过滤：黑名单 UP / 标题关键词 / 低赞比 */
  private applyFilter(cards: VideoCard[]): VideoCard[] {
    const blackMids = this.filterBlackMids;
    const keywords = this.filterKeywords;
    const minRatio = this.filterMinLikeRatio;
    if (blackMids.length === 0 && keywords.length === 0 && minRatio <= 0) {
      return cards;
    }
    return cards.filter((c: VideoCard) => {
      if (blackMids.indexOf(c.ownerMid) >= 0) {
        return false;
      }
      for (let i = 0; i < keywords.length; i++) {
        if (c.title.indexOf(keywords[i]) >= 0) {
          return false;
        }
      }
      if (minRatio > 0 && c.playCount > 0) {
        const ratio = c.likeCount / c.playCount;
        if (ratio < minRatio) {
          return false;
        }
      }
      return true;
    });
  }

  async getRecommend(freshIdx: number): Promise<Result<VideoCard[]>> {
    const r = await this.api.recommendWeb(freshIdx);
    if (!r.isOk) {
      return Result.err<VideoCard[]>(r.error);
    }
    const data = r.value as RawRcmdData;
    const items = data.item ?? [];
    const cards = items.map((it: RawRcmdItem) => parseCard(it))
      .filter((c: VideoCard) => c.bvid.length > 0);
    return Result.ok<VideoCard[]>(this.applyFilter(cards));
  }

  async getPopular(pn: number): Promise<Result<VideoCard[]>> {
    const r = await this.api.popular(pn);
    if (!r.isOk) {
      return Result.err<VideoCard[]>(r.error);
    }
    const data = r.value as RawPopularData;
    const items = data.list ?? [];
    const cards = items.map((it: RawRcmdItem) => parseCard(it))
      .filter((c: VideoCard) => c.bvid.length > 0);
    return Result.ok<VideoCard[]>(this.applyFilter(cards));
  }

  async getVideoDetail(bvid: string): Promise<Result<VideoDetail>> {
    const r = await this.api.videoDetail(bvid);
    if (!r.isOk) {
      return Result.err<VideoDetail>(r.error);
    }
    const d = r.value as RawDetailData;
    if (d.bvid === undefined) {
      return Result.err<VideoDetail>(AppError.parse('detail missing bvid'));
    }
    const v = new VideoDetail();
    v.bvid = d.bvid;
    v.aid = d.aid ?? 0;
    v.title = d.title ?? '';
    v.desc = d.desc ?? '';
    v.cover = VideoCard.fixUrl(d.pic ?? '');
    v.duration = d.duration ?? 0;
    v.pubdate = d.pubdate ?? 0;
    v.ownerMid = d.owner?.mid ?? 0;
    v.ownerName = d.owner?.name ?? '';
    v.ownerFace = VideoCard.fixUrl(d.owner?.face ?? '');
    v.view = d.stat?.view ?? 0;
    v.danmaku = d.stat?.danmaku ?? 0;
    v.reply = d.stat?.reply ?? 0;
    v.favorite = d.stat?.favorite ?? 0;
    v.coin = d.stat?.coin ?? 0;
    v.share = d.stat?.share ?? 0;
    v.like = d.stat?.like ?? 0;
    const pages = d.pages ?? [];
    v.pages = pages.map((p: RawDetailPage) => {
      const vp = new VideoPage();
      vp.cid = p.cid ?? 0;
      vp.part = p.part ?? '';
      vp.page = p.page ?? 1;
      vp.duration = p.duration ?? 0;
      return vp;
    });
    v.cid = v.pages.length > 0 ? v.pages[0].cid : 0;
    return Result.ok<VideoDetail>(v);
  }

  async getPlayUrl(bvid: string, cid: number, qn: number = 80): Promise<Result<PlayUrlInfo>> {
    const r = await this.api.playUrl(bvid, cid, qn);
    if (!r.isOk) {
      return Result.err<PlayUrlInfo>(r.error);
    }
    const d = r.value as RawPlayData;
    const durl = d.durl ?? [];
    if (durl.length === 0 || durl[0].url === undefined) {
      return Result.err<PlayUrlInfo>(AppError.parse('no playable url'));
    }
    const info = new PlayUrlInfo();
    info.url = VideoCard.fixUrl(durl[0].url);
    info.backupUrls = (durl[0].backup_url ?? []).map((u: string) => VideoCard.fixUrl(u));
    info.quality = d.quality ?? 0;
    info.qualityDesc = VideoRepository.qualityName(info.quality);
    info.timelength = d.timelength ?? 0;
    return Result.ok<PlayUrlInfo>(info);
  }

  static qualityName(qn: number): string {
    switch (qn) {
      case 127: return '8K';
      case 120: return '4K';
      case 116: return '1080P60';
      case 112: return '1080P+';
      case 80: return '1080P';
      case 64: return '720P';
      case 32: return '480P';
      case 16: return '360P';
      default: return `${qn}P`;
    }
  }
}
