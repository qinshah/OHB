import { DataState } from '../common/state/DataState';
import { HotSearchItem, SearchPage, SearchType } from '../models/SearchModels';
import { SearchRepository } from '../data/repository/SearchRepository';
import { common } from '@kit.AbilityKit';

/**
 * 搜索 ViewModel（Task 7）：建议/热搜/分类搜索/历史。
 */
@Observed
export class SearchViewModel {
  /** 热搜 */
  hotState: DataState<HotSearchItem[]> = DataState.idle<HotSearchItem[]>();
  hotItems: HotSearchItem[] = [];
  /** 建议 */
  suggestions: string[] = [];
  /** 历史 */
  history: string[] = [];
  /** 搜索结果 */
  resultState: DataState<SearchPage> = DataState.idle<SearchPage>();
  resultPage: SearchPage | null = null;
  isLoadingMore: boolean = false;

  keyword: string = '';
  searchType: SearchType = SearchType.Video;
  /** 高级筛选 */
  order: string = '';
  duration: number = 0;
  tids: number = 0;

  private repo: SearchRepository = new SearchRepository();
  private currentPage: number = 1;
  private suggestSeq: number = 0;

  init(context: common.Context): void {
    this.repo.init(context);
    this.reloadHistory();
  }

  async loadHot(): Promise<void> {
    this.hotState = DataState.loading<HotSearchItem[]>();
    const r = await this.repo.trending();
    if (r.isOk) {
      this.hotItems = r.value;
      this.hotState = this.hotItems.length > 0
        ? DataState.data<HotSearchItem[]>(this.hotItems)
        : DataState.empty<HotSearchItem[]>();
    } else {
      this.hotState = DataState.error<HotSearchItem[]>(r.error);
    }
  }

  /** 输入联想（带防抖序号防竞态） */
  async onKeywordChange(text: string): Promise<void> {
    this.keyword = text;
    if (text.trim().length === 0) {
      this.suggestions = [];
      return;
    }
    this.suggestSeq++;
    const seq = this.suggestSeq;
    const r = await this.repo.suggest(text);
    if (seq !== this.suggestSeq) {
      return;
    }
    if (r.isOk) {
      this.suggestions = r.value.terms;
    }
  }

  async doSearch(type: SearchType, keyword: string): Promise<void> {
    this.searchType = type;
    this.keyword = keyword;
    this.currentPage = 1;
    this.resultState = DataState.loading<SearchPage>();
    this.repo.addHistory(keyword);
    this.reloadHistory();
    await this.fetchResult();
  }

  async loadMoreResult(): Promise<void> {
    if (this.isLoadingMore || this.resultPage === null || !this.resultPage.hasMore) {
      return;
    }
    this.isLoadingMore = true;
    this.currentPage++;
    await this.fetchResult();
    this.isLoadingMore = false;
  }

  private async fetchResult(): Promise<void> {
    const r = await this.repo.search(this.searchType, this.keyword, this.currentPage,
      this.order, this.duration, this.tids);
    if (r.isOk) {
      const page = r.value;
      if (this.resultPage !== null && page.page > 1) {
        page.rows = this.resultPage.rows.concat(page.rows);
      }
      this.resultPage = page;
      this.resultState = page.rows.length > 0
        ? DataState.data<SearchPage>(page)
        : DataState.empty<SearchPage>();
    } else {
      this.resultState = DataState.error<SearchPage>(r.error, this.resultPage);
    }
  }

  reloadHistory(): void {
    this.history = this.repo.getHistory();
  }

  removeHistoryItem(keyword: string): void {
    this.repo.removeHistory(keyword);
    this.reloadHistory();
  }

  clearHistory(): void {
    this.repo.clearHistory();
    this.reloadHistory();
  }
}
