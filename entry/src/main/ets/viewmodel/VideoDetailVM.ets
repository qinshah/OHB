import { DataState } from '../common/state/DataState';
import { AppError } from '../common/result/AppError';
import { VideoDetail, VideoPage } from '../models/VideoDetail';
import { PlayUrlInfo } from '../models/PlayUrlInfo';
import { VideoCard } from '../models/VideoCard';
import { VideoRepository } from '../data/repository/VideoRepository';
import { Player } from '../player/Player';
import { PlayerRepository } from '../repository/PlayerRepository';
import { Pref } from '../services/storage/Pref';
import { DanmakuControllerManager } from '../services/danmaku/DanmakuController';

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

  /** 分P切换（P2 Task 13） */
  async switchPage(page: VideoPage, index: number): Promise<void> {
    if (this.detail === null || this.actionBusy) {
      return;
    }
    this.actionBusy = true;
    this.actionTip = '';
    const pos = this.playerVM.positionMs;
    this.detail.cid = page.cid;
    await this.loadPlayUrl(this.loadSeq, this.detail.bvid, this.detail.cid);
    if (pos > 0 && this.playUrlInfo !== null) {
      // 新分P从 0 开始播放（不沿用旧进度）
      this.playerVM.seekTo(0);
    }
    this.actionBusy = false;
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
    this.playUrlInfo = r.value;
    // 画质列表/当前画质同步给 Player（控制栏画质按钮数据源）
    this.playerVM.qualityOptions = this.playUrlInfo.qualityOptions;
    this.playerVM.currentQuality = this.playUrlInfo.quality;
    // 弹幕数据源跟随 cid（分P切换时 DanmakuLayer 检测到变化会重置渲染并拉取新数据）
    this.playerVM.danmakuCid = cid;
    await this.playerVM.load(this.playUrlInfo.url, Player.defaultHeaders());
    // 应用默认倍速（设置中心，AP-4）
    const speed = Pref.defaultSpeed.get();
    if (speed !== 1) {
      await this.playerVM.setSpeed(speed);
    }
  }

  /**
   * 切换画质（参考 PiliPlus updatePlayer 逻辑，适配 durl 模式）：
   * - durl 单流模式下不同 qn 对应不同 URL，需带新 qn 重新请求 playurl
   *   （PiliPlus 是 DASH 多流缓存切换，无需重新请求）
   * - 记住当前播放进度 → 重拉流 load(startAtMs) → prepared 后自动 seek 回进度续播
   * - 实际画质以接口返回值为准（未登录/非大会员请求高画质会被静默降级）
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
      this.playUrlInfo = r.value;
      this.playerVM.qualityOptions = this.playUrlInfo.qualityOptions;
      this.playerVM.currentQuality = this.playUrlInfo.quality;
      // 起播位置 = 切换前进度（prepared 后自动 seek）
      await this.playerVM.load(this.playUrlInfo.url, Player.defaultHeaders(), resumeMs);
      // 倍速重放（换流后内核倍速重置为 1.0）
      if (this.playerVM.speed !== 1) {
        await this.playerVM.setSpeed(this.playerVM.speed);
      }
      // 持久化画质偏好（下次打开视频/新视频生效）
      Pref.defaultQuality.put(qn);
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
