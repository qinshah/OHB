import { DataState, DataStatus } from '../common/state/DataState';
import { VideoCard } from '../models/VideoCard';
import { VideoRepository } from '../data/repository/VideoRepository';
import { common } from '@kit.AbilityKit';

/**
 * 首页 ViewModel（Task 6）：推荐流加载/刷新/分页，DataState 状态机管理。
 */
@Observed
export class HomeViewModel {
  feedState: DataState<VideoCard[]> = DataState.idle<VideoCard[]>();
  items: VideoCard[] = [];
  isLoadingMore: boolean = false;
  hasMore: boolean = true;
  /** 展示模式：推荐 / 热门 */
  mode: 'recommend' | 'popular' = 'recommend';

  private repo: VideoRepository = new VideoRepository();
  private freshIdx: number = 1;
  private popularPage: number = 1;

  init(context: common.Context): void {
    this.repo.initFilter(context);
  }

  async loadFirst(): Promise<void> {
    this.feedState = DataState.loading<VideoCard[]>();
    this.freshIdx = 1;
    this.popularPage = 1;
    await this.fetch(false);
  }

  async refresh(): Promise<void> {
    this.feedState = DataState.refreshing<VideoCard[]>(this.items);
    this.freshIdx = 1;
    this.popularPage = 1;
    await this.fetch(false);
  }

  async loadMore(): Promise<void> {
    if (this.isLoadingMore || !this.hasMore) {
      return;
    }
    this.isLoadingMore = true;
    this.freshIdx++;
    this.popularPage++;
    await this.fetch(true);
    this.isLoadingMore = false;
  }

  private async fetch(append: boolean): Promise<void> {
    const r = this.mode === 'recommend'
      ? await this.repo.getRecommend(this.freshIdx)
      : await this.repo.getPopular(this.popularPage);
    if (r.isOk) {
      const list = r.value;
      if (append) {
        this.items = this.items.concat(list);
      } else {
        this.items = list;
      }
      this.hasMore = list.length > 0;
      if (this.items.length === 0) {
        this.feedState = DataState.empty<VideoCard[]>();
      } else {
        this.feedState = DataState.data<VideoCard[]>(this.items);
      }
    } else {
      this.feedState = DataState.error<VideoCard[]>(r.error, this.items.length > 0 ? this.items : null);
    }
  }

  get isRefreshing(): boolean {
    return this.feedState.status === DataStatus.Refreshing;
  }
}
