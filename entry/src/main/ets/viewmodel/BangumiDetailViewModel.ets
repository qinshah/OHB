import { DataState } from '../common/state/DataState';
import { AppError } from '../common/result/AppError';
import { BangumiDetail, BangumiEpisode } from '../models/BangumiModels';
import { BangumiRepository } from '../data/repository/BangumiRepository';
import { PlayerController } from '../player/PlayerController';

/**
 * 番剧详情 ViewModel（P2 Task 20）：详情、追番、选集播放。
 */
@Observed
export class BangumiDetailViewModel {
  state: DataState<BangumiDetail> = DataState.idle<BangumiDetail>();
  detail: BangumiDetail | null = null;
  /** 当前选中剧集 */
  currentEpisode: BangumiEpisode | null = null;
  playError: string = '';
  tipText: string = '';
  isBusy: boolean = false;
  /** 播放器实例（本页持有） */
  controller: PlayerController = new PlayerController();

  private repo: BangumiRepository = new BangumiRepository();

  async load(seasonId: number): Promise<void> {
    this.state = DataState.loading<BangumiDetail>();
    const r = await this.repo.getDetail(seasonId);
    if (!r.isOk) {
      this.state = DataState.error<BangumiDetail>(r.error);
      return;
    }
    this.detail = r.value;
    this.state = DataState.data<BangumiDetail>(this.detail);
    if (this.detail.episodes.length > 0) {
      await this.selectEpisode(this.detail.episodes[0]);
    }
  }

  async selectEpisode(episode: BangumiEpisode): Promise<void> {
    this.currentEpisode = episode;
    this.playError = '';
    if (episode.bvid.length === 0 || episode.cid <= 0) {
      this.playError = '该剧集暂不支持播放';
      return;
    }
    const r = await this.repo.getPlayUrl(episode.bvid, episode.cid);
    if (!r.isOk) {
      this.playError = r.error.message;
      return;
    }
    await this.controller.load(r.value.url, PlayerController.defaultHeaders());
  }

  async toggleFollow(): Promise<void> {
    if (this.detail === null || this.isBusy) {
      return;
    }
    this.isBusy = true;
    const r = await this.repo.follow(this.detail.seasonId, !this.detail.isFollow);
    this.isBusy = false;
    if (r.isOk) {
      this.detail.isFollow = !this.detail.isFollow;
    } else {
      this.tipText = r.error.message;
    }
  }

  async release(): Promise<void> {
    await this.controller.release();
  }

  get errorMessage(): string {
    return this.state.error?.message ?? AppError.unknown('').message;
  }
}
