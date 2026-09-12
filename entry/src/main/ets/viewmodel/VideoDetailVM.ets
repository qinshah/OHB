import { DataState } from '../common/state/DataState';
import { AppError } from '../common/result/AppError';
import { VideoDetail, VideoPage } from '../models/VideoDetail';
import { PlayUrlInfo } from '../models/PlayUrlInfo';
import { Quality, QualityUtil } from '../models/Quality';
import { VideoCard } from '../models/VideoCard';
import { VideoRepository } from '../data/repository/VideoRepository';
import { BangumiRepository } from '../data/repository/BangumiRepository';
import { BangumiEpisode } from '../models/BangumiModels';
import { Player } from '../player/Player';
import { PlaySource } from '../player/PlayerTypes';
import { PlayerRepository } from '../repository/PlayerRepository';
import { Pref } from '../services/storage/Pref';
import { DanmakuControllerManager } from '../services/danmaku/DanmakuController';
import { promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

/**
 * 视频详情 ViewModel（Task 9）：详情 + 播放地址加载，持有并驱动 PlayerController。
 *
 * 播放器实例由 PlayerRepository 统一管理（静态单例，key=bvid）：
 * - 详情页（VideoDetailPage）经 attachPlayer(bvid) 创建/复用播放器
 * - 全屏页（VideoFullscreenPage）经 PlayerRepository.get(bvid) 访问同一实例播放
 * - 视频渲染节点由 VideoNodeController 管理：详情页与全屏页共享同一 XComponent，
 *   Surface 绑定在 VideoPlayerNode.onLoad 中完成（本 VM 不再经手 surface）
 */
@Observed
export class VideoDetailVM {
  detailState: DataState<VideoDetail> = DataState.idle<VideoDetail>();
  detail: VideoDetail | null = null;
  playUrlInfo: PlayUrlInfo | null = null;
  /** 播放地址加载错误 */
  playError: string = '';
  /**
   * 番剧分集模式：detail.pages 来自整季剧集（每集自带 bvid），
   * 选集列表按「集数」渲染而非「分P」（见 loadPgcEpisodes）。
   */
  isPgc: boolean = false;
  /** 相关视频（P2 Task 13） */
  relatedState: DataState<VideoCard[]> = DataState.idle<VideoCard[]>();
  related: VideoCard[] = [];
  /** 互动状态（P2 Task 13） */
  liked: boolean = false;
  coined: boolean = false;
  favorited: boolean = false;
  watchLaterAdded: boolean = false;
  actionBusy: boolean = false;
  actionTip: string = '';
  playerVM: Player;
  private playerKey: string;
  private repo: VideoRepository = new VideoRepository();
  private bangumiRepo: BangumiRepository = new BangumiRepository();
  /** 番剧季号（>0 表示番剧分集模式） */
  private seasonId: number = 0;
  /** 占位播放器 id 自增序号，避免多实例碰撞 */
  private static vmSeq: number = 0;
  /** 防竞态序号 */
  private loadSeq: number = 0;
  /** 画质切换进行中（防重入） */
  private qualityChanging: boolean = false;

  constructor() {
    // 构造时先以占位 id 登记，页面 aboutToAppear 经 attachPlayer(bvid) 换为真实实例
    this.playerKey = `__video_vm_${VideoDetailVM.vmSeq}`;
    VideoDetailVM.vmSeq++;
    this.playerVM = PlayerRepository.create(this.playerKey);
  }

  /**
   * 绑定 bvid 对应的播放器（页面 aboutToAppear 调用；同一 bvid 复用已有实例）。
   * 通过 PlayerRepository 以 bvid 为 key 建立联系，全屏页可经 get(bvid) 获取同一实例。
   */
  attachPlayer(bvid: string): void {
    if (this.playerKey === bvid) {
      return;
    }
    const target = PlayerRepository.create(bvid);
    PlayerRepository.remove(this.playerKey); // 释放占位/旧实例
    this.playerVM = target;
    this.playerKey = bvid;
    // 弹幕开关跟随设置中心初始值（后续由控制栏按钮切换并持久化）
    this.playerVM.danmakuEnabled = Pref.danmakuEnabled.get();
    // 注册画质切换处理：控制栏 Select → Player.requestQualityChange → 此处 changeQuality
    // （注意：attachPlayer 首次绑定后才注册；后续同一 bvid 复用 Player，无需重复注册）
    this.playerVM.setQualityChangeListener((qn: number) => {
      this.changeQuality(qn);
    });
    // 经 AppStorage 发布 Player 引用：VideoPlayerNode 组件 onLoad 时跨模块解析并绑定 Surface。
    // 不用自定义 static Map 注册表——@Component 编译单元存在模块双实例问题（注册与查询
    // 读到不同副本）；AppStorage 是框架级全局单例，跨模块绝对共享。
    // 时序：本方法在 aboutToAppear 同步执行，必然早于 XComponent onLoad。
    AppStorage.setOrCreate(VideoDetailVM.playerKeyOf(bvid), target);
  }

  /** AppStorage 中 Player 引用的 key（与 VideoPlayerNode 的字面量前缀保持一致） */
  static playerKeyOf(bvid: string): string {
    return `__ohb_vplayer_${bvid}`;
  }

  async load(bvid: string): Promise<void> {
    this.loadSeq++;
    const seq = this.loadSeq;
    this.detailState = DataState.loading<VideoDetail>();
    this.playError = '';
    this.relatedState = DataState.idle<VideoCard[]>();
    this.related = [];

    const r = await this.repo.getVideoDetail(bvid);
    if (seq !== this.loadSeq) {
      return;
    }
    if (!r.isOk) {
      this.detailState = DataState.error<VideoDetail>(r.error);
      return;
    }
    this.detail = r.value;
    this.detailState = DataState.data<VideoDetail>(this.detail);
    this.loadRelated(bvid);
    await this.loadPlayUrl(seq, this.detail.bvid, this.detail.cid);
  }

  /** 相关视频 */
  async loadRelated(bvid: string): Promise<void> {
    this.relatedState = DataState.loading<VideoCard[]>();
    const r = await this.repo.getRelated(bvid);
    if (!r.isOk) {
      this.relatedState = DataState.error<VideoCard[]>(r.error);
      return;
    }
    this.related = r.value;
    this.relatedState = this.related.length > 0
      ? DataState.data<VideoCard[]>(this.related)
      : DataState.empty<VideoCard[]>();
  }

  /** 分P切换（P2 Task 13）／番剧切集 */
  async switchPage(page: VideoPage, index: number): Promise<void> {
    if (this.detail === null || this.actionBusy) {
      return;
    }
    this.actionBusy = true;
    this.actionTip = '';
    // 番剧每一集都是独立稿件：切集必须连带更换 bvid，否则会取到上一集的流
    if (page.bvid.length > 0) {
      this.detail.bvid = page.bvid;
    }
    this.detail.cid = page.cid;
    await this.loadPlayUrl(this.loadSeq, this.detail.bvid, this.detail.cid);
    // 新分P / 新剧集从 0 开始播放（不沿用旧进度）
    this.playerVM.seekTo(0);
    this.actionBusy = false;
  }

  /**
   * 番剧分集：按季拉取整季剧集，写入 detail.pages 作为选集列表。
   *
   * 与普通分P的差异：
   * - 普通分P同属一个稿件（bvid 不变、仅 cid 变化）
   * - 番剧每集是独立稿件（bvid 与 cid 都要变），故 pages 逐集携带 bvid
   * - 接口 duration 为毫秒，这里换算为秒以对齐 FormatUtils.duration
   * 失败时静默返回：选集加载不影响当前剧集播放。
   */
  async loadPgcEpisodes(seasonId: number): Promise<void> {
    if (seasonId <= 0) {
      return;
    }
    this.seasonId = seasonId;
    const r = await this.bangumiRepo.getDetail(seasonId);
    if (!r.isOk || this.detail === null) {
      return;
    }
    const eps = r.value.episodes;
    const pages: VideoPage[] = [];
    for (let i = 0; i < eps.length; i++) {
      const ep: BangumiEpisode = eps[i];
      if (ep.bvid.length === 0 || ep.cid <= 0) {
        continue;
      }
      const p = new VideoPage();
      p.cid = ep.cid;
      p.bvid = ep.bvid;
      p.page = pages.length + 1;
      p.part = ep.longTitle.length > 0 ? ep.longTitle : ep.title;
      p.duration = Math.floor(ep.duration / 1000);
      pages.push(p);
    }
    if (pages.length === 0) {
      return;
    }
    this.isPgc = true;
    this.detail.pages = pages;
    // 对齐当前正在播放的一集（入口非首集时也能正确高亮）
    for (let i = 0; i < pages.length; i++) {
      if (pages[i].cid === this.detail.cid) {
        this.detail.bvid = pages[i].bvid;
        break;
      }
    }
  }

  // ---------- P2 Task 13：互动 ----------

  async like(): Promise<void> {
    if (this.detail === null || this.actionBusy) {
      return;
    }
    this.actionBusy = true;
    this.actionTip = '';
    const target = !this.liked;
    const r = await this.repo.likeVideo(this.detail.aid, target);
    if (r.isOk) {
      this.liked = target;
      this.detail.like = Math.max(0, this.detail.like + (target ? 1 : -1));
    } else {
      this.actionTip = r.error.message;
    }
    this.actionBusy = false;
  }

  async coin(): Promise<void> {
    if (this.detail === null || this.actionBusy || this.coined) {
      return;
    }
    this.actionBusy = true;
    this.actionTip = '';
    const r = await this.repo.coinVideo(this.detail.aid, 1);
    if (r.isOk) {
      this.coined = true;
      this.detail.coin = this.detail.coin + 1;
      this.actionTip = '投币成功';
    } else {
      this.actionTip = r.error.message;
    }
    this.actionBusy = false;
  }

  async triple(): Promise<void> {
    if (this.detail === null || this.actionBusy) {
      return;
    }
    this.actionBusy = true;
    this.actionTip = '';
    const r = await this.repo.tripleVideo(this.detail.aid);
    if (r.isOk) {
      this.liked = true;
      this.coined = true;
      this.favorited = true;
      this.detail.like = this.detail.like + 1;
      this.detail.coin = this.detail.coin + 1;
      this.detail.favorite = this.detail.favorite + 1;
      this.actionTip = '一键三连成功';
    } else {
      this.actionTip = r.error.message;
    }
    this.actionBusy = false;
  }

  /** 收藏（需要默认收藏夹 id，0 表示仅移除） */
  async favorite(mediaId: number = 0): Promise<void> {
    if (this.detail === null || this.actionBusy) {
      return;
    }
    this.actionBusy = true;
    this.actionTip = '';
    const target = !this.favorited;
    const r = await this.repo.favoriteVideo(this.detail.aid, mediaId, target);
    if (r.isOk) {
      this.favorited = target;
      this.detail.favorite = Math.max(0, this.detail.favorite + (target ? 1 : -1));
      this.actionTip = target ? '已收藏' : '已取消收藏';
    } else {
      this.actionTip = r.error.message;
    }
    this.actionBusy = false;
  }

  /** 加入稍后再看 */
  async addWatchLater(): Promise<void> {
    if (this.detail === null || this.actionBusy || this.watchLaterAdded) {
      return;
    }
    this.actionBusy = true;
    this.actionTip = '';
    const r = await this.repo.addWatchLater(this.detail.aid);
    if (r.isOk) {
      this.watchLaterAdded = true;
      this.actionTip = '已加入稍后再看';
    } else {
      this.actionTip = r.error.message;
    }
    this.actionBusy = false;
  }

  private async loadPlayUrl(seq: number, bvid: string, cid: number): Promise<void> {
    if (cid <= 0) {
      this.playError = '缺少 cid，无法获取播放地址';
      return;
    }
    const qn = Pref.defaultQuality.get();
    const r = await this.repo.getPlayUrl(bvid, cid, qn);
    if (seq !== this.loadSeq) {
      return;
    }
    if (!r.isOk) {
      this.playError = r.error.message;
      return;
    }
    await this.applyPlayUrl(r.value, 0);
    // 弹幕数据源跟随 cid（分P切换时 DanmakuLayer 检测到变化会重置渲染并拉取新数据）
    this.playerVM.danmakuCid = cid;
    // 应用默认倍速（设置中心，AP-4）
    const speed = Pref.defaultSpeed.get();
    if (speed !== 1) {
      await this.playerVM.setSpeed(speed);
    }
  }

  /**
   * 把取流结果落到播放器：同步画质列表/当前画质，并组装播放源。
   * 目标画质需要 DASH 时 info.audioUrl 非空，播放器会起「视频轨 + 音频轨」双路
   * （B 站 720P 以上画质只有 DASH，单文件 MP4 已下线），并注册兜底地址提供者。
   */
  private async applyPlayUrl(info: PlayUrlInfo, startAtMs: number): Promise<void> {
    this.playUrlInfo = info;
    // 画质列表/当前画质同步给 Player（控制栏画质按钮数据源）
    this.playerVM.qualityOptions = info.qualityOptions;
    this.playerVM.currentQuality = info.quality;
    const src = new PlaySource();
    src.url = info.url;
    src.headers = Player.defaultHeaders();
    src.audioUrl = info.audioUrl;
    src.audioBackupUrls = info.audioBackupUrls;
    // DASH 双流失败时惰性取单文件地址（多打一次接口只发生在真的播不了时）
    src.fallbackProvider = (): Promise<string> => this.fetchFallbackUrl();
    await this.playerVM.load(src, startAtMs);
  }

  /** 兜底地址：单文件最高档（≤720P，含音轨） */
  private async fetchFallbackUrl(): Promise<string> {
    if (this.detail === null) {
      return '';
    }
    const r = await this.repo.getSingleFilePlayUrl(this.detail.bvid, this.detail.cid);
    return r.isOk ? r.value.url : '';
  }

  /**
   * 切换画质。
   *
   * 取流与档位折算统一由 PlayUrlInfo/QualityUtil 处理（对齐 PiliPlus updatePlayer）：
   * - 重新请求（B 站不同 qn 对应不同地址，DASH 亦需按目标档位换视频轨）
   * - 记住当前播放进度 → 换源 → prepared 后自动 seek 回进度续播
   * - 实际画质以接口返回为准；被服务端降级（非大会员/该视频无该档位）时提示用户，
   *   避免出现「选了 1080P 却悄悄播 720P」的困惑
   * - 持久化到 Pref.defaultQuality，下次打开视频生效
   */
  async changeQuality(qn: number): Promise<void> {
    if (this.detail === null || this.qualityChanging || qn === this.playerVM.currentQuality) {
      return;
    }
    this.qualityChanging = true;
    this.playerVM.qualityChanging = true;
    // 记住当前进度（换流后 seek 回去，对齐 PiliPlus 的 playedTime 续播）
    const resumeMs: number = this.playerVM.positionMs;
    try {
      const r = await this.repo.getPlayUrl(this.detail.bvid, this.detail.cid, qn);
      if (!r.isOk) {
        this.playError = r.error.message;
        return;
      }
      await this.applyPlayUrl(r.value, resumeMs);
      // 倍速重放（换流后内核倍速重置为 1.0）
      if (this.playerVM.speed !== 1) {
        await this.playerVM.setSpeed(this.playerVM.speed);
      }
      // 持久化画质偏好（下次打开视频/新视频生效）
      Pref.defaultQuality.put(qn);
      if (r.value.quality !== qn) {
        // 非大会员或该视频不提供该档位：服务端就近降级，明确告知
        promptAction.showToast({
          message: $r('app.string.quality_unavailable_toast',
            QualityUtil.shortDesc(qn), QualityUtil.shortDesc(r.value.quality))
        });
      }
      hilog.info(0x0000, TAG, 'changeQuality request=%{public}d actual=%{public}d dash=%{public}s',
        qn, r.value.quality, `${r.value.isDash}`);
    } finally {
      this.playerVM.qualityChanging = false;
      this.qualityChanging = false;
    }
  }

  /** 重试播放地址 */
  async retryPlayUrl(): Promise<void> {
    if (this.detail === null) {
      return;
    }
    this.playError = '';
    await this.loadPlayUrl(this.loadSeq, this.detail.bvid, this.detail.cid);
  }

  async release(): Promise<void> {
    this.loadSeq++;
    // 页面彻底关闭：释放弹幕分桶数据（详情页/全屏页共享，仅此处移除）
    if (this.detail !== null && this.detail.cid > 0) {
      DanmakuControllerManager.remove(this.detail.cid);
    }
    // 清理 AppStorage 中发布的 Player 引用（防止泄漏与脏引用）
    AppStorage.delete(VideoDetailVM.playerKeyOf(this.playerKey));
    await PlayerRepository.remove(this.playerKey);
  }
}

// 日志 TAG（规范：统一定义在文件最下方）
const TAG = VideoDetailVM.name ?? 'VideoDetailVM';
