import { DataState } from '../common/state/DataState';
import { AppError } from '../common/result/AppError';
import { TopicFeedCard, TopicFeedPage, TopicItem } from '../models/TopicModels';
import { DynamicRepository } from '../data/repository/DynamicRepository';

/**
 * 话题广场/话题流 ViewModel（P2 Task 18）。
 */
@Observed
export class TopicViewModel {
  topicState: DataState<TopicItem[]> = DataState.idle<TopicItem[]>();
  topics: TopicItem[] = [];

  feedState: DataState<TopicFeedCard[]> = DataState.idle<TopicFeedCard[]>();
  feedItems: TopicFeedCard[] = [];
  currentTopicId: number = 0;
  isLoadingMore: boolean = false;
  hasMore: boolean = true;
  tipText: string = '';

  private repo: DynamicRepository = new DynamicRepository();
  private offset: string = '';
  private sortBy: number = 0;

  async loadTopics(): Promise<void> {
    this.topicState = DataState.loading<TopicItem[]>();
    const r = await this.repo.getTopicRecommend(25);
    if (r.isOk) {
      this.topics = r.value;
      this.topicState = this.topics.length > 0
        ? DataState.data<TopicItem[]>(this.topics)
        : DataState.empty<TopicItem[]>();
    } else {
      this.topicState = DataState.error<TopicItem[]>(r.error);
    }
  }

  async loadFeedFirst(topicId: number, sortBy: number = 0): Promise<void> {
    this.currentTopicId = topicId;
    this.sortBy = sortBy;
    this.offset = '';
    this.hasMore = true;
    this.feedState = DataState.loading<TopicFeedCard[]>();
    await this.fetchFeed(false);
  }

  async loadMoreFeed(): Promise<void> {
    if (this.isLoadingMore || !this.hasMore) {
      return;
    }
    this.isLoadingMore = true;
    await this.fetchFeed(true);
    this.isLoadingMore = false;
  }

  private async fetchFeed(append: boolean): Promise<void> {
    const r = await this.repo.getTopicFeed(this.currentTopicId, this.offset, this.sortBy);
    if (!r.isOk) {
      this.feedState = DataState.error<TopicFeedCard[]>(r.error, this.feedItems.length > 0 ? this.feedItems : null);
      return;
    }
    const page: TopicFeedPage = r.value;
    this.offset = page.offset;
    this.hasMore = page.hasMore;
    if (append) {
      this.feedItems = this.feedItems.concat(page.items);
    } else {
      this.feedItems = page.items;
    }
    this.feedState = this.feedItems.length > 0
      ? DataState.data<TopicFeedCard[]>(this.feedItems)
      : DataState.empty<TopicFeedCard[]>();
  }

  get errorMessage(): string {
    return this.feedState.error?.message ?? this.topicState.error?.message ?? AppError.unknown('').message;
  }
}
