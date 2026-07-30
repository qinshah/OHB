import { DataState, DataStatus } from '../common/state/DataState';
import { AppError } from '../common/result/AppError';
import { DynamicFeed, DynamicItem } from '../models/DynamicItem';
import { DynamicRepository } from '../data/repository/DynamicRepository';
import { AccountManager } from '../services/account/AccountManager';

/**
 * 动态 ViewModel（Task 8）：关注动态流加载/刷新/分页（V1 仅加载与跳转）。
 */
@Observed
export class DynamicViewModel {
  feedState: DataState<DynamicItem[]> = DataState.idle<DynamicItem[]>();
  items: DynamicItem[] = [];
  isLoadingMore: boolean = false;
  hasMore: boolean = true;

  private repo: DynamicRepository = new DynamicRepository();
  private offset: string = '';

  async loadFirst(): Promise<void> {
    if (!AccountManager.getInstance().isLoggedIn) {
      this.feedState = DataState.error<DynamicItem[]>(AppError.unauthorized());
      return;
    }
    this.feedState = DataState.loading<DynamicItem[]>();
    this.offset = '';
    await this.fetch(false);
  }

  async refresh(): Promise<void> {
    this.feedState = DataState.refreshing<DynamicItem[]>(this.items);
    this.offset = '';
    await this.fetch(false);
  }

  async loadMore(): Promise<void> {
    if (this.isLoadingMore || !this.hasMore || this.offset.length === 0) {
      return;
    }
    this.isLoadingMore = true;
    await this.fetch(true);
    this.isLoadingMore = false;
  }

  private async fetch(append: boolean): Promise<void> {
    const r = await this.repo.getFeed(this.offset);
    if (r.isOk) {
      const feed: DynamicFeed = r.value;
      this.offset = feed.offset;
      this.hasMore = feed.hasMore;
      if (append) {
        this.items = this.items.concat(feed.items);
      } else {
        this.items = feed.items;
      }
      this.feedState = this.items.length > 0
        ? DataState.data<DynamicItem[]>(this.items)
        : DataState.empty<DynamicItem[]>();
    } else {
      this.feedState = DataState.error<DynamicItem[]>(r.error, this.items.length > 0 ? this.items : null);
    }
  }

  get isRefreshing(): boolean {
    return this.feedState.status === DataStatus.Refreshing;
  }
}
