import { DataState } from '../common/state/DataState';
import { AppError } from '../common/result/AppError';
import { BangumiDetail, BangumiEpisode } from '../models/BangumiModels';
import { BangumiRepository } from '../data/repository/BangumiRepository';
import { Player } from '../player/Player';
import { PlayerRepository } from '../repository/PlayerRepository';

/**
 * 番剧详情 ViewModel（P2 Task 20）：详情、追番、选集播放。
 * 播放器经 PlayerRepository 管理（key=bangumi_seasonId）。
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
  cntlr: Player;
  private cntlrKey: string;
  private repo: BangumiRepository = new BangumiRepository();
  /** 占位播放器 id 自增序号，避免多实例碰撞 */
  private static vmSeq: number = 0;

  constructor() {
    // 构造时先以占位 id 登记，页面 aboutToAppear 经 attachCntlr(seasonId) 换为真实实例
    this.cntlrKey = `__bangumi_vm_${BangumiDetailViewModel.vmSeq}`;
    BangumiDetailViewModel.vmSeq++;
    this.cntlr = PlayerRepository.create(this.cntlrKey);
  }

  /** 绑定 seasonId 对应的播放器（页面 aboutToAppear 调用；同一 seasonId 复用已有实例） */
  attachCntlr(seasonId: number): void {
    const key = `bangumi_${seasonId}`;
    if (this.cntlrKey === key) {
      return;
    }
    const target = PlayerRepository.create(key);
    PlayerRepository.remove(this.cntlrKey); // 释放占位/旧实例
    this.cntlr = target;
    this.cntlrKey = key;
  }

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
    await this.cntlr.load(r.value.url, Player.defaultHeaders());
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
    await PlayerRepository.remove(this.cntlrKey);
  }

  get errorMessage(): string {
    return this.state.error?.message ?? AppError.unknown('').message;
  }
}
