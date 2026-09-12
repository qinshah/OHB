import { Result } from '../../common/result/Result';
import { AppError } from '../../common/result/AppError';
import { BiliApi } from '../../network/BiliApi';
import { VideoCard } from '../../models/VideoCard';
import { VideoDetail, VideoPage } from '../../models/VideoDetail';
import { PlayUrlInfo, QualityOption } from '../../models/PlayUrlInfo';
import { Quality, QualityUtil } from '../../models/Quality';
import { PlayUrlParser, RawPlayData } from './PlayUrlParser';
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

  /**
   * 取流（统一入口）。
   *
   * 流程（对齐 PiliPlus：始终以最高档做一次探测请求，再按账号真实可用档位选流）：
   * 1. 先以 `QualityUtil.PROBE_QUALITY` + DASH(fnval=4048) 探测，
   *    这样服务端才会返回账号真实的完整档位（未带 DASH 时大会员档位会被隐藏，
   *    这正是此前「切 720P 以上画质总被回退到 720P」的根因）与 DASH 视频/音频轨
   * 2. 用 `QualityUtil.findAvailable` 把「期望画质」折算为「实际可用画质」
   * 3. 目标档位 ≤720P → 走单文件 MP4（含音轨，兼容性最好）
   *    目标档位 >720P → B 站已下线对应 MP4，只能走 DASH 双流（视频轨 + 音频轨）
   * 4. DASH 取不到对应流时回退到单文件最高档，保证可播
   */
  async getPlayUrl(bvid: string, cid: number, preferredQn: number = Quality.High1080): Promise<Result<PlayUrlInfo>> {
    const probeR = await this.api.playUrl(bvid, cid, QualityUtil.PROBE_QUALITY, QualityUtil.FNVAL_DASH);
    if (!probeR.isOk) {
      return Result.err<PlayUrlInfo>(probeR.error);
    }
    const probe = probeR.value as RawPlayData;
    const dashCodes = PlayUrlParser.dashVideoCodes(probe);
    const options = PlayUrlParser.parseQualityOptions(probe, dashCodes);
    if (options.length === 0) {
      return Result.err<PlayUrlInfo>(AppError.parse('no quality options'));
    }
    // 期望画质 → 实际可播画质（accept_quality 会虚报，高画质必须以 DASH 实际流为准）
    const target = PlayUrlParser.resolveTarget(probe, preferredQn);
    hilog.info(0x0000, TAG, 'getPlayUrl preferred=%{public}d target=%{public}d declared=%{public}s dash=%{public}s',
      preferredQn, target, `${PlayUrlParser.acceptCodes(probe)}`, `${dashCodes}`);

    if (!QualityUtil.needsDash(target)) {
      const single = await this.getSingleFilePlayUrl(bvid, cid, target);
      if (single.isOk) {
        single.value.qualityOptions = options;
        this.logResult('single', single.value);
        return single;
      }
      hilog.warn(0x0000, TAG, 'single-file url failed, fallback to dash: %{public}s', single.error.message);
    }

    const info = new PlayUrlInfo();
    if (PlayUrlParser.fillDash(info, probe, target)) {
      info.qualityOptions = options;
      this.logResult('dash', info);
      return Result.ok<PlayUrlInfo>(info);
    }

    // 该档位没有 DASH 流（或响应不含 dash）→ 退回单文件最高档
    const fallbackQn = Math.min(target, QualityUtil.MAX_SINGLE_FILE);
    const single = await this.getSingleFilePlayUrl(bvid, cid, fallbackQn);
    if (!single.isOk) {
      return single;
    }
    single.value.qualityOptions = options;
    this.logResult('single-fallback', single.value);
    return single;
  }

  /**
   * 单文件（MP4/durl）取流：fnval=1，音视频同流，AvPlayer 单实例可播。
   * 亦作为 DASH 双流播放失败时的兜底地址来源（见 PlaySource.fallbackProvider）。
   */
  async getSingleFilePlayUrl(bvid: string, cid: number,
    qn: number = QualityUtil.MAX_SINGLE_FILE): Promise<Result<PlayUrlInfo>> {
    const r = await this.api.playUrl(bvid, cid, qn, QualityUtil.FNVAL_MP4);
    if (!r.isOk) {
      return Result.err<PlayUrlInfo>(r.error);
    }
    const d = r.value as RawPlayData;
    const info = new PlayUrlInfo();
    if (!PlayUrlParser.fillSingleFile(info, d, qn)) {
      return Result.err<PlayUrlInfo>(AppError.parse('no playable url'));
    }
    info.qualityOptions = PlayUrlParser.parseQualityOptions(d);
    return Result.ok<PlayUrlInfo>(info);
  }

  private logResult(mode: string, info: PlayUrlInfo): void {
    hilog.info(0x0000, TAG, 'getPlayUrl ok mode=%{public}s qn=%{public}d dash=%{public}s options=%{public}s',
      mode, info.quality, `${info.isDash}`, `${info.qualityOptions.map((o: QualityOption) => `${o.qn}:${o.desc}`)}`);
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

  /** 短文案（画质名称映射已统一收敛到 QualityUtil.shortDesc） */
  static qualityName(qn: number): string {
    return QualityUtil.shortDesc(qn);
  }
}

// 日志 TAG（规范：统一定义在文件最下方）
const TAG = VideoRepository.name ?? 'VideoRepository';
