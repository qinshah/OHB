import { DataState, DataStatus } from '../common/state/DataState';
import { AppError } from '../common/result/AppError';
import { HistoryItem } from '../models/HistoryModels';
import { HistoryRepository } from '../data/repository/HistoryRepository';

/**
 * 历史记录 ViewModel（P2 Task 16）：游标分页、删除、清空。
 */
@Observed
export class HistoryViewModel {
  state: DataState<HistoryItem[]> = DataState.idle<HistoryItem[]>();
  items: HistoryItem[] = [];
  isLoadingMore: boolean = false;
  hasMore: boolean = true;
  tipText: string = '';

  private repo: HistoryRepository = new HistoryRepository();
  private max: number = 0;
  private viewAt: number = 0;

  async loadFirst(): Promise<void> {
    this.state = DataState.loading<HistoryItem[]>();
    this.max = 0;
    this.viewAt = 0;
    this.hasMore = true;
    await this.fetch(false);
  }

  async loadMore(): Promise<void> {
    if (this.isLoadingMore || !this.hasMore) {
      return;
    }
    this.isLoadingMore = true;
    await this.fetch(true);
    this.isLoadingMore = false;
  }

  private async fetch(append: boolean): Promise<void> {
    const r = await this.repo.getHistory(this.max, this.viewAt);
    if (!r.isOk) {
      this.state = DataState.error<HistoryItem[]>(r.error, this.items.length > 0 ? this.items : null);
      return;
    }
    const page = r.value;
    this.max = page.max;
    this.viewAt = page.viewAt;
    this.hasMore = page.hasMore;
    if (append) {
      this.items = this.items.concat(page.items);
    } else {
      this.items = page.items;
    }
    this.state = this.items.length > 0
      ? DataState.data<HistoryItem[]>(this.items)
      : DataState.empty<HistoryItem[]>();
  }

  async deleteItem(item: HistoryItem): Promise<boolean> {
    const r = await this.repo.deleteItem(item.kid);
    if (!r.isOk) {
      this.tipText = r.error.message;
      return false;
    }
    const idx = this.items.findIndex((h: HistoryItem) => h.kid === item.kid);
    if (idx >= 0) {
      this.items.splice(idx, 1);
    }
    this.tipText = '已删除该记录';
    return true;
  }

  async clearAll(): Promise<boolean> {
    const r = await this.repo.clearAll();
    if (!r.isOk) {
      this.tipText = r.error.message;
      return false;
    }
    this.items = [];
    this.state = DataState.empty<HistoryItem[]>();
    this.tipText = '历史记录已清空';
    return true;
  }

  get errorMessage(): string {
    return this.state.error?.message ?? AppError.unknown('').message;
  }
}
