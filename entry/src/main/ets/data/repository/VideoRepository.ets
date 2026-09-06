import { Result } from '../../common/result/Result';
import { AppError } from '../../common/result/AppError';
import { BiliApi } from '../../network/BiliApi';
import { VideoCard } from '../../models/VideoCard';
import { VideoDetail, VideoPage } from '../../models/VideoDetail';
import { PlayUrlInfo, QualityOption } from '../../models/PlayUrlInfo';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { PrefsStorage } from '../../services/storage/PrefsStorage';
import { AccountManager } from '../../services/account/AccountManager';
import { CookieManager } from '../../network/CookieManager';
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

/** support_formats 单项（playurl 响应，画质描述） */
interface RawSupportFormat {
  quality?: number;
  new_desc?: string;
  display_desc?: string;
  superscript?: string;
}

interface RawPlayData {
  quality?: number;
  timelength?: number;
  durl?: RawDurl[];
  /** 可用画质 qn 列表（账号可见范围内，从高到低） */
  accept_quality?: number[];
  /** 画质描述（与 accept_quality 对应） */
  support_formats?: RawSupportFormat[];
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
    info.qualityOptions = VideoRepository.parseQualityOptions(d);
    // 未登录时 fnval=1 接口只返回 2 档画质（accept_quality=[64,16]），
    // 借 DASH 请求（try_look 只对 DASH 生效）补全画质列表（含 1080P 试看）
    if (info.qualityOptions.length <= 2) {
      const f = await this.api.playUrlFormats(bvid, cid);
      if (f.isOk) {
        const fd = f.value as RawPlayData;
        const dashOptions = VideoRepository.parseQualityOptions(fd);
        if (dashOptions.length > info.qualityOptions.length) {
          hilog.info(0x0000, TAG,
            'quality list from dash: %{public}d items (durl only %{public}d)',
            dashOptions.length, info.qualityOptions.length);
          info.qualityOptions = dashOptions;
        }
      }
    }
    hilog.info(0x0000, TAG, 'getPlayUrl qn=%{public}d real=%{public}d options=%{public}s',
      qn, info.quality, `${info.qualityOptions.map((o: QualityOption) => `${o.qn}:${o.desc}`)}`);
    return Result.ok<PlayUrlInfo>(info);
  }

  /**
   * 组装可用画质列表（参考 PiliPlus VideoQuality 使用方式）：
   * - 以 accept_quality（账号可见范围内的 qn 列表）为准，从 support_formats 取
   *   new_desc（列表项完整描述）/ display_desc（按钮短文案）/ superscript（大会员角标）
   * - 描述兜底链：new_desc → display_desc → qualityName 本地映射
   *   （实测未登录时 support_formats 的 new_desc 为空串、display_desc 才有值如「720P」）
   */
  private static parseQualityOptions(d: RawPlayData): QualityOption[] {
    const qns: number[] = d.accept_quality ?? [];
    if (qns.length === 0) {
      return [];
    }
    const formats: RawSupportFormat[] = d.support_formats ?? [];
    const list: QualityOption[] = [];
    for (const q of qns) {
      const o = new QualityOption();
      o.qn = q;
      let matched: RawSupportFormat | null = null;
      for (const f of formats) {
        if (f.quality === q) {
          matched = f;
          break;
        }
      }
      if (matched !== null) {
        o.desc = matched.new_desc ?? '';
        o.shortDesc = matched.display_desc ?? '';
        o.superscript = matched.superscript ?? '';
      } else {
        // 兜底：qn 映射本地文案
        o.desc = VideoRepository.qualityName(q);
        o.shortDesc = o.desc;
      }
      // desc 兜底链：new_desc 空 → display_desc → qualityName
      if (o.desc.length === 0) {
        o.desc = o.shortDesc.length > 0 ? o.shortDesc : VideoRepository.qualityName(q);
      }
      if (o.shortDesc.length === 0) {
        o.shortDesc = VideoRepository.qualityName(q);
      }
      list.push(o);
    }
    return list;
  }

  // ---------- P2 Task 13：视频详情互动 ----------

  /** 相关视频 */
  async getRelated(bvid: string): Promise<Result<VideoCard[]>> {
    const r = await this.api.relatedVideos(bvid);
    if (!r.isOk) {
      return Result.err<VideoCard[]>(r.error);
    }
    const list = r.value as RawRcmdItem[];
    const cards = list.map((it: RawRcmdItem) => parseCard(it))
      .filter((c: VideoCard) => c.bvid.length > 0);
    return Result.ok<VideoCard[]>(cards);
  }

  /** 点赞（like=true 点赞 / false 取消） */
  async likeVideo(aid: number, like: boolean): Promise<Result<boolean>> {
    const r = await this.api.likeVideo(aid, like ? 1 : 2);
    if (!r.isOk) {
      return Result.err<boolean>(r.error);
    }
    return Result.ok<boolean>(true);
  }

  /** 投币（multiply 1~2） */
  async coinVideo(aid: number, multiply: number = 1): Promise<Result<boolean>> {
    const r = await this.api.coinVideo(aid, multiply, 0);
    if (!r.isOk) {
      return Result.err<boolean>(r.error);
    }
    return Result.ok<boolean>(true);
  }

  /** 一键三连 */
  async tripleVideo(aid: number): Promise<Result<boolean>> {
    const csrf = CookieManager.getInstance().csrf;
    if (csrf.length === 0) {
      return Result.err<boolean>(AppError.unauthorized('请先登录后三连'));
    }
    const r = await this.api.tripleVideo(aid, csrf);
    if (!r.isOk) {
      return Result.err<boolean>(r.error);
    }
    return Result.ok<boolean>(true);
  }

  /** 收藏/取消收藏（mediaId 为收藏夹 id） */
  async favoriteVideo(aid: number, mediaId: number, add: boolean): Promise<Result<boolean>> {
    const csrf = CookieManager.getInstance().csrf;
    if (csrf.length === 0) {
      return Result.err<boolean>(AppError.unauthorized('请先登录后收藏'));
    }
    const r = await this.api.favResourceDeal(aid,
      add ? `${mediaId}` : '',
      add ? '' : `${mediaId}`,
      csrf);
    if (!r.isOk) {
      return Result.err<boolean>(r.error);
    }
    return Result.ok<boolean>(true);
  }

  /** 加入稍后再看 */
  async addWatchLater(aid: number): Promise<Result<boolean>> {
    const csrf = CookieManager.getInstance().csrf;
    if (csrf.length === 0) {
      return Result.err<boolean>(AppError.unauthorized('请先登录后使用稍后再看'));
    }
    const r = await this.api.toviewAdd(aid, csrf);
    if (!r.isOk) {
      return Result.err<boolean>(r.error);
    }
    return Result.ok<boolean>(true);
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

// 日志 TAG（规范：统一定义在文件最下方）
const TAG = VideoRepository.name ?? 'VideoRepository';
