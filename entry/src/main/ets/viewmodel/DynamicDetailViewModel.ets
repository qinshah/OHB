import { DataState } from '../common/state/DataState';
import { AppError } from '../common/result/AppError';
import { DynamicItem } from '../models/DynamicItem';
import { DynamicRepository } from '../data/repository/DynamicRepository';

/**
 * 动态详情 ViewModel（P2 Task 18）：详情展示 + 点赞。
 */
@Observed
export class DynamicDetailViewModel {
  state: DataState<DynamicItem> = DataState.idle<DynamicItem>();
  item: DynamicItem | null = null;
  tipText: string = '';

  private repo: DynamicRepository = new DynamicRepository();

  async load(id: string): Promise<void> {
    this.state = DataState.loading<DynamicItem>();
    const r = await this.repo.getDetail(id);
    if (!r.isOk) {
      this.state = DataState.error<DynamicItem>(r.error);
      return;
    }
    this.item = r.value;
    this.state = DataState.data<DynamicItem>(this.item);
  }

  async toggleLike(): Promise<void> {
    if (this.item === null) {
      return;
    }
    const target = !this.item.isLiked;
    const r = await this.repo.like(this.item.idStr, target);
    if (r.isOk) {
      this.item.isLiked = target;
      this.item.likeCount = Math.max(0, this.item.likeCount + (target ? 1 : -1));
    } else {
      this.tipText = r.error.message;
    }
  }

  get errorMessage(): string {
    return this.state.error?.message ?? AppError.unknown('').message;
  }
}
