import { Result } from '../../common/result/Result';
import { AppError } from '../../common/result/AppError';
import { BiliApi } from '../../network/BiliApi';
import { CommentCursor, CommentItem, CommentMember, CommentPageData } from '../../models/CommentModels';
import { CookieManager } from '../../network/CookieManager';
import { VideoCard } from '../../models/VideoCard';

/** 评论原始 JSON 形状 */
interface RawReplyMember {
  mid?: number;
  uname?: string;
  avatar?: string;
  level_info?: RawLevelInfo;
}

interface RawLevelInfo {
  current_level?: number;
}

interface RawReplyContent {
  message?: string;
}

interface RawUpAction {
  like?: number;
}

interface RawReply {
  rpid?: number;
  oid?: number;
  member?: RawReplyMember;
  content?: RawReplyContent;
  ctime?: number;
  like?: number;
  rcount?: number;
  up_action?: RawUpAction;
}

interface RawReplyCursor {
  next?: string;
  is_end?: number;
}

interface RawReplyData {
  replies?: RawReply[];
  top_replies?: RawReply[];
  cursor?: RawReplyCursor;
}

interface RawReplyReplyData {
  replies?: RawReply[];
}

/**
 * 评论仓库（P2 Task 14）：主评论分页、楼中楼、点赞、发表、删除。
 * 评论类型：1=视频稿件，17=动态。
 */
export class CommentRepository {
  private api: BiliApi = new BiliApi();

  /** 主评论列表（分页游标由 cursor.next 携带） */
  async getMain(type: number, oid: number | string, next: string, mode: number = 3): Promise<Result<CommentPageData>> {
    const pagination = JSON.stringify({ 'offset': next });
    const r = await this.api.replyMain(type, oid, mode, pagination);
    if (!r.isOk) {
      return Result.err<CommentPageData>(r.error);
    }
    const data = r.value as RawReplyData;
    const page = new CommentPageData();
    const rawReplies = (data.replies ?? []).concat(data.top_replies ?? []);
    page.comments = rawReplies
      .map((raw: RawReply) => CommentRepository.parseItem(raw))
      .filter((c: CommentItem) => c.rpid > 0);
    const cursor = data.cursor;
    page.cursor.next = cursor?.next ?? '';
    page.cursor.isEnd = (cursor?.is_end ?? 0) === 1;
    return Result.ok<CommentPageData>(page);
  }

  /** 楼中楼子评论 */
  async getSubReplies(type: number, oid: number | string, root: number, pn: number, ps: number): Promise<Result<CommentItem[]>> {
    const r = await this.api.replyReply(type, oid, root, pn, ps);
    if (!r.isOk) {
      return Result.err<CommentItem[]>(r.error);
    }
    const data = r.value as RawReplyReplyData;
    const items = (data.replies ?? [])
      .map((raw: RawReply) => CommentRepository.parseItem(raw))
      .filter((c: CommentItem) => c.rpid > 0);
    return Result.ok<CommentItem[]>(items);
  }

  /** 发表评论（root/parent=0 表示顶层） */
  async addComment(type: number, oid: number | string, message: string, root: number = 0, parent: number = 0): Promise<Result<boolean>> {
    const csrf = CookieManager.getInstance().csrf;
    if (csrf.length === 0) {
      return Result.err<boolean>(AppError.unauthorized('请先登录后发表评论'));
    }
    const r = await this.api.replyAdd(type, oid, message, root, parent, csrf);
    if (!r.isOk) {
      return Result.err<boolean>(r.error);
    }
    return Result.ok<boolean>(true);
  }

  /** 点赞/取消赞（action=1 赞，2 取消） */
  async likeComment(type: number, oid: number | string, rpid: number, liked: boolean): Promise<Result<boolean>> {
    const csrf = CookieManager.getInstance().csrf;
    if (csrf.length === 0) {
      return Result.err<boolean>(AppError.unauthorized());
    }
    const r = await this.api.replyAction(type, oid, rpid, liked ? 1 : 2, csrf);
    if (!r.isOk) {
      return Result.err<boolean>(r.error);
    }
    return Result.ok<boolean>(true);
  }

  /** 删除评论 */
  async deleteComment(type: number, oid: number | string, rpid: number): Promise<Result<boolean>> {
    const csrf = CookieManager.getInstance().csrf;
    if (csrf.length === 0) {
      return Result.err<boolean>(AppError.unauthorized());
    }
    const r = await this.api.replyDel(type, oid, rpid, csrf);
    if (!r.isOk) {
      return Result.err<boolean>(r.error);
    }
    return Result.ok<boolean>(true);
  }

  private static parseItem(raw: RawReply): CommentItem {
    const item = new CommentItem();
    item.rpid = raw.rpid ?? 0;
    item.oid = raw.oid ?? 0;
    const m = raw.member;
    if (m !== undefined) {
      const member = new CommentMember();
      member.mid = m.mid ?? 0;
      member.uname = m.uname ?? '';
      member.avatar = VideoCard.fixUrl(m.avatar ?? '');
      member.level = m.level_info?.current_level ?? 0;
      item.member = member;
    }
    item.content = raw.content?.message ?? '';
    item.pubTs = raw.ctime ?? 0;
    item.likeCount = raw.like ?? 0;
    item.replyCount = raw.rcount ?? 0;
    item.liked = raw.up_action?.like ?? 0;
    return item;
  }
}
