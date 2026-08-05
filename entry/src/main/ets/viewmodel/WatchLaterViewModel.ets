import { DataState } from '../common/state/DataState';
import { AppError } from '../common/result/AppError';
import { HistoryItem } from '../models/HistoryModels';
import { WatchLaterRepository } from '../data/repository/WatchLaterRepository';

/**
 * 稍后再看 ViewModel（P2 Task 16）：列表、移除、清空。
 */
@Observed
export class WatchLaterViewModel {
  state: DataState<HistoryItem[]> = DataState.idle<HistoryItem[]>();
  items: HistoryItem[] = [];
  tipText: string = '';

  private repo: WatchLaterRepository = new WatchLaterRepository();

  async load(): Promise<void> {
    this.state = DataState.loading<HistoryItem[]>();
    const r = await this.repo.getList();
    if (!r.isOk) {
      this.state = DataState.error<HistoryItem[]>(r.error);
      return;
    }
    this.items = r.value;
    this.state = this.items.length > 0
      ? DataState.data<HistoryItem[]>(this.items)
      : DataState.empty<HistoryItem[]>();
  }

  async remove(item: HistoryItem): Promise<boolean> {
    const r = await this.repo.remove(item.aid);
    if (!r.isOk) {
      this.tipText = r.error.message;
      return false;
    }
    const idx = this.items.findIndex((h: HistoryItem) => h.aid === item.aid);
    if (idx >= 0) {
      this.items.splice(idx, 1);
    }
    this.tipText = '已从稍后再看移除';
    return true;
  }

  async clear(): Promise<boolean> {
    const r = await this.repo.clear();
    if (!r.isOk) {
      this.tipText = r.error.message;
      return false;
    }
    this.items = [];
    this.state = DataState.empty<HistoryItem[]>();
    this.tipText = '稍后再看已清空';
    return true;
  }

  get errorMessage(): string {
    return this.state.error?.message ?? AppError.unknown('').message;
  }
}
