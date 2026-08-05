import { Result } from '../../common/result/Result';
import { AppError } from '../../common/result/AppError';
import { BiliApi } from '../../network/BiliApi';
import { CookieManager } from '../../network/CookieManager';
import { HistoryItem, HistoryPageData } from '../../models/HistoryModels';
import { VideoCard } from '../../models/VideoCard';

/** 历史记录原始 JSON 形状 */
interface RawHistory {
  kid?: string;
  title?: string;
  cover?: string;
  duration?: number;
  author_name?: string;
  author_mid?: number;
  view_at?: number;
  progress?: number;
  badge?: string;
  history?: RawHistoryInner;
}

interface RawHistoryInner {
  bvid?: string;
  cid?: number;
  aid?: number;
}

interface RawHistoryCursor {
  max?: number;
  view_at?: number;
}

interface RawHistoryData {
  list?: RawHistory[];
  cursor?: RawHistoryCursor;
}

/**
 * 历史记录仓库（P2 Task 16）：游标分页、删除、清空。
 */
export class HistoryRepository {
  private api: BiliApi = new BiliApi();

  async getHistory(max: number, viewAt: number, ps: number = 20): Promise<Result<HistoryPageData>> {
    const r = await this.api.historyCursor(max, viewAt, ps);
    if (!r.isOk) {
      return Result.err<HistoryPageData>(r.error);
    }
    const data = r.value as RawHistoryData;
    const page = new HistoryPageData();
    const list = data.list ?? [];
    page.items = list.map((raw: RawHistory) => HistoryRepository.parseItem(raw))
      .filter((h: HistoryItem) => h.bvid.length > 0);
    const cursor = data.cursor;
    page.max = cursor?.max ?? max;
    page.viewAt = cursor?.view_at ?? viewAt;
    page.hasMore = list.length >= ps;
    return Result.ok<HistoryPageData>(page);
  }

  async deleteItem(kid: string): Promise<Result<boolean>> {
    const csrf = CookieManager.getInstance().csrf;
    if (csrf.length === 0) {
      return Result.err<boolean>(AppError.unauthorized());
    }
    const r = await this.api.historyDel(kid, csrf);
    if (!r.isOk) {
      return Result.err<boolean>(r.error);
    }
    return Result.ok<boolean>(true);
  }

  async clearAll(): Promise<Result<boolean>> {
    const csrf = CookieManager.getInstance().csrf;
    if (csrf.length === 0) {
      return Result.err<boolean>(AppError.unauthorized());
    }
    const r = await this.api.historyClear(csrf);
    if (!r.isOk) {
      return Result.err<boolean>(r.error);
    }
    return Result.ok<boolean>(true);
  }

  private static parseItem(raw: RawHistory): HistoryItem {
    const item = new HistoryItem();
    item.kid = raw.kid ?? '';
    item.aid = raw.history?.aid ?? 0;
    item.bvid = raw.history?.bvid ?? '';
    item.cid = raw.history?.cid ?? 0;
    item.title = raw.title ?? '';
    item.cover = VideoCard.fixUrl(raw.cover ?? '');
    item.duration = raw.duration ?? 0;
    item.ownerName = raw.author_name ?? '';
    item.ownerMid = raw.author_mid ?? 0;
    item.viewAt = raw.view_at ?? 0;
    item.progress = raw.progress ?? 0;
    item.progressText = raw.progress !== undefined && raw.progress > 0
      ? HistoryRepository.progressText(raw.progress, item.duration)
      : '';
    item.badge = raw.badge ?? '';
    return item;
  }

  private static progressText(progressSec: number, durationSec: number): string {
    const p = Math.max(0, Math.floor(progressSec / 60));
    const d = Math.max(0, Math.floor(durationSec / 60));
    return `${p}分钟前看到 · 总${d}分钟`;
  }
}
