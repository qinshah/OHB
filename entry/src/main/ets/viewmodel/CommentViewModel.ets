import { DataState, DataStatus } from '../common/state/DataState';
import { AppError } from '../common/result/AppError';
import { CommentItem } from '../models/CommentModels';
import { CommentRepository } from '../data/repository/CommentRepository';

/**
 * 评论 ViewModel（P2 Task 14）：主评论分页、点赞、楼中楼、发表、删除。
 * type=1 视频评论，type=17 动态评论；oid 支持 number/string（动态 id 超 2^53）。
 */
@Observed
export class CommentViewModel {
  state: DataState<CommentItem[]> = DataState.idle<CommentItem[]>();
  items: CommentItem[] = [];
  isLoadingMore: boolean = false;
  isEnd: boolean = false;
  /** 发表中 */
  isPosting: boolean = false;
  /** 操作提示（成功/失败） */
  tipText: string = '';

  type: number = 1;
  oid: number | string = 0;

  private repo: CommentRepository = new CommentRepository();
  private cursorNext: string = '';
  private loadSeq: number = 0;

  init(type: number, oid: number | string): void {
    this.type = type;
    this.oid = oid;
    this.loadFirst();
  }

  async loadFirst(): Promise<void> {
    this.loadSeq++;
    const seq = this.loadSeq;
    this.state = DataState.loading<CommentItem[]>();
    this.cursorNext = '';
    this.isEnd = false;
    await this.fetch(seq, false);
  }

  async loadMore(): Promise<void> {
    if (this.isLoadingMore || this.isEnd || this.cursorNext.length === 0) {
      return;
    }
    this.isLoadingMore = true;
    await this.fetch(this.loadSeq, true);
    this.isLoadingMore = false;
  }

  private async fetch(seq: number, append: boolean): Promise<void> {
    const r = await this.repo.getMain(this.type, this.oid, this.cursorNext);
    if (seq !== this.loadSeq) {
      return;
    }
    if (!r.isOk) {
      this.state = DataState.error<CommentItem[]>(r.error, this.items.length > 0 ? this.items : null);
      return;
    }
    const page = r.value;
    this.cursorNext = page.cursor.next;
    this.isEnd = page.cursor.isEnd;
    if (append) {
      this.items = this.items.concat(page.comments);
    } else {
      this.items = page.comments;
    }
    this.state = this.items.length > 0
      ? DataState.data<CommentItem[]>(this.items)
      : DataState.empty<CommentItem[]>();
  }

  /** 点赞/取消赞（本地乐观更新） */
  async toggleLike(item: CommentItem): Promise<void> {
    const target = item.liked !== 1;
    const r = await this.repo.likeComment(this.type, this.oid, item.rpid, target);
    if (r.isOk) {
      item.liked = target ? 1 : 0;
      item.likeCount = Math.max(0, item.likeCount + (target ? 1 : -1));
    } else {
      this.tipText = r.error.message;
    }
  }

  /** 加载楼中楼 */
  async loadSubReplies(item: CommentItem): Promise<void> {
    if (item.repliesLoaded) {
      item.repliesLoaded = false;
      return;
    }
    const r = await this.repo.getSubReplies(this.type, this.oid, item.rpid, 1, 10);
    if (r.isOk) {
      item.replies = r.value;
      item.repliesLoaded = true;
      item.replyPage = 1;
      item.replyHasMore = r.value.length >= 10;
    } else {
      this.tipText = r.error.message;
    }
  }

  /** 楼中楼加载更多 */
  async loadMoreReplies(item: CommentItem): Promise<void> {
    const nextPage = item.replyPage + 1;
    const r = await this.repo.getSubReplies(this.type, this.oid, item.rpid, nextPage, 10);
    if (r.isOk) {
      item.replies = item.replies.concat(r.value);
      item.replyPage = nextPage;
      item.replyHasMore = r.value.length >= 10;
    } else {
      this.tipText = r.error.message;
    }
  }

  /** 发表评论（root/parent=0 顶层） */
  async postComment(text: string, root: number = 0, parent: number = 0): Promise<boolean> {
    if (text.trim().length === 0 || this.isPosting) {
      return false;
    }
    this.isPosting = true;
    this.tipText = '';
    const r = await this.repo.addComment(this.type, this.oid, text.trim(), root, parent);
    this.isPosting = false;
    if (!r.isOk) {
      this.tipText = r.error.message;
      return false;
    }
    this.tipText = '评论发表成功';
    await this.loadFirst();
    return true;
  }

  /** 删除评论 */
  async deleteComment(item: CommentItem): Promise<boolean> {
    const r = await this.repo.deleteComment(this.type, this.oid, item.rpid);
    if (!r.isOk) {
      this.tipText = r.error.message;
      return false;
    }
    const idx = this.items.findIndex((c: CommentItem) => c.rpid === item.rpid);
    if (idx >= 0) {
      this.items.splice(idx, 1);
    }
    this.tipText = '评论已删除';
    return true;
  }

  get isRefreshing(): boolean {
    return this.state.status === DataStatus.Refreshing;
  }

  get errorMessage(): string {
    return this.state.error?.message ?? AppError.unknown('').message;
  }

  /** 触发 @Observed 刷新（数组/嵌套对象字段变更后调用） */
  refresh(): void {
    this.items = this.items.slice();
  }
}
