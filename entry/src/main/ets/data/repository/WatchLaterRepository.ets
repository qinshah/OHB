import { Result } from '../../common/result/Result';
import { AppError } from '../../common/result/AppError';
import { BiliApi } from '../../network/BiliApi';
import { CookieManager } from '../../network/CookieManager';
import { HistoryItem } from '../../models/HistoryModels';
import { VideoCard } from '../../models/VideoCard';

interface RawLaterItem {
  aid?: number;
  bvid?: string;
  cid?: number;
  title?: string;
  pic?: string;
  duration?: number;
  owner?: RawLaterOwner;
  pubdate?: number;
  progress?: number;
}

interface RawLaterOwner {
  mid?: number;
  name?: string;
}

interface RawLaterData {
  list?: RawLaterItem[];
  count?: number;
}

/**
 * 稍后再看仓库（P2 Task 16）：列表、加入、移除、清空。
 */
export class WatchLaterRepository {
  private api: BiliApi = new BiliApi();

  async getList(): Promise<Result<HistoryItem[]>> {
    const r = await this.api.toviewList();
    if (!r.isOk) {
      return Result.err<HistoryItem[]>(r.error);
    }
    const data = r.value as RawLaterData;
    const items = (data.list ?? []).map((raw: RawLaterItem) => {
      const item = new HistoryItem();
      item.aid = raw.aid ?? 0;
      item.bvid = raw.bvid ?? '';
      item.cid = raw.cid ?? 0;
      item.title = raw.title ?? '';
      item.cover = VideoCard.fixUrl(raw.pic ?? '');
      item.duration = raw.duration ?? 0;
      item.ownerMid = raw.owner?.mid ?? 0;
      item.ownerName = raw.owner?.name ?? '';
      item.progress = raw.progress ?? 0;
      return item;
    }).filter((h: HistoryItem) => h.bvid.length > 0);
    return Result.ok<HistoryItem[]>(items);
  }

  async add(aid: number): Promise<Result<boolean>> {
    const csrf = CookieManager.getInstance().csrf;
    if (csrf.length === 0) {
      return Result.err<boolean>(AppError.unauthorized('请先登录后使用稍后再看'));
    }
    const r = await this.api.toviewAdd(aid, csrf);
    if (!r.isOk) {
      return Result.err<boolean>(r.error);
    }
    return Result.ok<boolean>(true);
  }

  async remove(aid: number): Promise<Result<boolean>> {
    const csrf = CookieManager.getInstance().csrf;
    if (csrf.length === 0) {
      return Result.err<boolean>(AppError.unauthorized());
    }
    const r = await this.api.toviewDel(aid, csrf);
    if (!r.isOk) {
      return Result.err<boolean>(r.error);
    }
    return Result.ok<boolean>(true);
  }

  async clear(): Promise<Result<boolean>> {
    const csrf = CookieManager.getInstance().csrf;
    if (csrf.length === 0) {
      return Result.err<boolean>(AppError.unauthorized());
    }
    const r = await this.api.toviewClear(csrf);
    if (!r.isOk) {
      return Result.err<boolean>(r.error);
    }
    return Result.ok<boolean>(true);
  }
}
