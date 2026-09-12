import { DataState } from '../common/state/DataState';
import { AppError } from '../common/result/AppError';
import { BangumiDetail } from '../models/BangumiModels';
import { BangumiRepository } from '../data/repository/BangumiRepository';

/**
 * 番剧详情 ViewModel：季详情 + 追番。
 *
 * 播放不再由本页承担——剧集播放统一走视频页（Route.video，按 bvid 打开），
 * 复用其渲染节点/控制栏/弹幕/全屏能力，故本 VM 不持有任何播放器实例。
 */
@Observed
export class BangumiDetailViewModel {
  state: DataState<BangumiDetail> = DataState.idle<BangumiDetail>();
  detail: BangumiDetail | null = null;
  tipText: string = '';
  isBusy: boolean = false;
  /** 当前季 id（「其他季」切换后随之更新，重试与刷新以它为准） */
  seasonId: number = 0;
  private repo: BangumiRepository = new BangumiRepository();

  async load(seasonId: number): Promise<void> {
    this.seasonId = seasonId;
    this.state = DataState.loading<BangumiDetail>();
    const r = await this.repo.getDetail(seasonId);
    if (!r.isOk) {
      this.state = DataState.error<BangumiDetail>(r.error);
      return;
    }
    this.detail = r.value;
    this.state = DataState.data<BangumiDetail>(this.detail);
  }

  async toggleFollow(): Promise<void> {
    if (this.detail === null || this.isBusy) {
      return;
    }
    this.isBusy = true;
    this.tipText = '';
    const r = await this.repo.follow(this.detail.seasonId, !this.detail.isFollow);
    this.isBusy = false;
    if (r.isOk) {
      this.detail.isFollow = !this.detail.isFollow;
    } else {
      this.tipText = r.error.message;
    }
  }

  get errorMessage(): string {
    return this.state.error?.message ?? AppError.unknown('').message;
  }
}
