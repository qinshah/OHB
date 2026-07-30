import { DataState } from '../common/state/DataState';
import { AppError } from '../common/result/AppError';
import { VideoDetail } from '../models/VideoDetail';
import { PlayUrlInfo } from '../models/PlayUrlInfo';
import { VideoRepository } from '../data/repository/VideoRepository';
import { PlayerController } from '../player/PlayerController';

/**
 * 视频详情 ViewModel（Task 9）：详情 + 播放地址加载，驱动 PlayerController。
 */
@Observed
export class VideoDetailViewModel {
  detailState: DataState<VideoDetail> = DataState.idle<VideoDetail>();
  detail: VideoDetail | null = null;
  playUrlInfo: PlayUrlInfo | null = null;
  /** 播放地址加载错误 */
  playError: string = '';

  private repo: VideoRepository = new VideoRepository();
  private controller: PlayerController | null = null;
  /** 防竞态序号 */
  private loadSeq: number = 0;

  bindPlayer(controller: PlayerController): void {
    this.controller = controller;
  }

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
    if (this.controller !== null) {
      await this.controller.load(this.playUrlInfo.url, PlayerController.defaultHeaders());
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
    if (this.controller !== null) {
      await this.controller.release();
    }
  }
}
