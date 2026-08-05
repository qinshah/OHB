import { DataState, DataStatus } from '../common/state/DataState';
import { AppError } from '../common/result/AppError';
import { BangumiItem } from '../models/BangumiModels';
import { BangumiRepository } from '../data/repository/BangumiRepository';

/**
 * 番剧索引/排行 ViewModel（P2 Task 20）。
 */
@Observed
export class BangumiViewModel {
  rankState: DataState<BangumiItem[]> = DataState.idle<BangumiItem[]>();
  rankItems: BangumiItem[] = [];

  indexState: DataState<BangumiItem[]> = DataState.idle<BangumiItem[]>();
  indexItems: BangumiItem[] = [];
  isLoadingMore: boolean = false;
  hasMore: boolean = true;

  private repo: BangumiRepository = new BangumiRepository();
  private page: number = 1;
  private seasonType: number = 1;
  private order: number = 0;
  private typeId: number = 0;

  async loadRank(seasonType: number = 1, day: number = 3): Promise<void> {
    this.rankState = DataState.loading<BangumiItem[]>();
    const r = await this.repo.getRank(seasonType, day);
    if (r.isOk) {
      this.rankItems = r.value;
      this.rankState = this.rankItems.length > 0
        ? DataState.data<BangumiItem[]>(this.rankItems)
        : DataState.empty<BangumiItem[]>();
    } else {
      this.rankState = DataState.error<BangumiItem[]>(r.error);
    }
  }

  async loadIndexFirst(seasonType: number = 1, order: number = 0, typeId: number = 0): Promise<void> {
    this.seasonType = seasonType;
    this.order = order;
    this.typeId = typeId;
    this.page = 1;
    this.hasMore = true;
    this.indexState = DataState.loading<BangumiItem[]>();
    await this.fetchIndex(false);
  }

  async loadMoreIndex(): Promise<void> {
    if (this.isLoadingMore || !this.hasMore) {
      return;
    }
    this.isLoadingMore = true;
    this.page++;
    await this.fetchIndex(true);
    this.isLoadingMore = false;
  }

  private async fetchIndex(append: boolean): Promise<void> {
    const r = await this.repo.getIndex(this.seasonType, this.page, this.order, this.typeId);
    if (!r.isOk) {
      this.indexState = DataState.error<BangumiItem[]>(r.error, this.indexItems.length > 0 ? this.indexItems : null);
      return;
    }
    const list = r.value;
    this.hasMore = list.length > 0;
    if (append) {
      this.indexItems = this.indexItems.concat(list);
    } else {
      this.indexItems = list;
    }
    this.indexState = this.indexItems.length > 0
      ? DataState.data<BangumiItem[]>(this.indexItems)
      : DataState.empty<BangumiItem[]>();
  }

  get errorMessage(): string {
    return this.indexState.error?.message ?? this.rankState.error?.message ?? AppError.unknown('').message;
  }
}
