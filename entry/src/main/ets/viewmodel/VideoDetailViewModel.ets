import { DataState } from '../common/state/DataState';
import { AppError } from '../common/result/AppError';
import { VideoDetail } from '../models/VideoDetail';
import { PlayUrlInfo } from '../models/PlayUrlInfo';
import { VideoRepository } from '../data/repository/VideoRepository';
import { PlayerController } from '../player/PlayerController';

/**
 * 视频详情 ViewModel（Task 9）：详情 + 播放地址加载，持有并驱动 PlayerController。
 *
 * 播放器实例由 VM 持有（单一所有者）：
 * - 视频页（VideoDetailPage）直接使用 vm.controller 渲染视频
 * - 全屏页（VideoFullscreenPage）经 PlayerControllerHolder 访问同一实例播放
 * - 全屏期间视频页条件渲染不挂载 XComponent；退出全屏后由 onLoad 重建 surface
 */
@Observed
export class VideoDetailViewModel {
  detailState: DataState<VideoDetail> = DataState.idle<VideoDetail>();
  detail: VideoDetail | null = null;
  playUrlInfo: PlayUrlInfo | null = null;
  /** 播放地址加载错误 */
  playError: string = '';
  /** 播放器实例（VM 持有；全屏页通过 PlayerControllerHolder 共享同一实例） */
  controller: PlayerController = new PlayerController();

  private repo: VideoRepository = new VideoRepository();
  /** 防竞态序号 */
  private loadSeq: number = 0;

  async load(bvid: string): Promise<void> {
    this.loadSeq++;
    const seq = this.loadSeq;
    this.detailState = DataState.loading<VideoDetail>();
    this.playError = '';

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
    await this.loadPlayUrl(seq, this.detail.bvid, this.detail.cid);
  }

  private async loadPlayUrl(seq: number, bvid: string, cid: number): Promise<void> {
    if (cid <= 0) {
      this.playError = '缺少 cid，无法获取播放地址';
      return;
    }
    const r = await this.repo.getPlayUrl(bvid, cid);
    if (seq !== this.loadSeq) {
      return;
    }
    if (!r.isOk) {
      this.playError = r.error.message;
      return;
    }
    this.playUrlInfo = r.value;
    await this.controller.load(this.playUrlInfo.url, PlayerController.defaultHeaders());
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
    await this.controller.release();
  }
}
