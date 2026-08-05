import { Result } from '../../common/result/Result';
import { AppError } from '../../common/result/AppError';
import { BiliApi } from '../../network/BiliApi';
import { CookieManager } from '../../network/CookieManager';
import { FavoriteFolder, FavoriteMedia } from '../../models/FavoriteModels';
import { VideoCard } from '../../models/VideoCard';

/** 收藏原始 JSON 形状 */
interface RawFolder {
  id?: number;
  fid?: number;
  mid?: number;
  title?: string;
  cover?: string;
  media_count?: number;
}

interface RawFolderData {
  list?: RawFolder[];
}

interface RawMediaCntInfo {
  play?: number;
  danmaku?: number;
}

interface RawMediaUpper {
  mid?: number;
  name?: string;
}

interface RawMedia {
  id?: number;
  type?: number;
  title?: string;
  cover?: string;
  duration?: number;
  bvid?: string;
  pubtime?: number;
  fav_time?: number;
  cnt_info?: RawMediaCntInfo;
  upper?: RawMediaUpper;
}

interface RawResourceData {
  medias?: RawMedia[];
  has_more?: boolean;
}

/**
 * 收藏仓库（P2 Task 16）：收藏夹列表、收藏夹内视频、收藏/取消收藏。
 */
export class FavoriteRepository {
  private api: BiliApi = new BiliApi();

  /** 当前用户创建的收藏夹 */
  async getFolders(upMid: number): Promise<Result<FavoriteFolder[]>> {
    const r = await this.api.favFolderListAll(upMid);
    if (!r.isOk) {
      return Result.err<FavoriteFolder[]>(r.error);
    }
    const data = r.value as RawFolderData;
    const folders = (data.list ?? []).map((raw: RawFolder) => {
      const folder = new FavoriteFolder();
      folder.id = raw.id ?? 0;
      folder.fid = raw.fid ?? folder.id;
      folder.mid = raw.mid ?? 0;
      folder.title = raw.title ?? '';
      folder.cover = VideoCard.fixUrl(raw.cover ?? '');
      folder.mediaCount = raw.media_count ?? 0;
      return folder;
    }).filter((f: FavoriteFolder) => f.id > 0);
    return Result.ok<FavoriteFolder[]>(folders);
  }

  /** 收藏夹内视频 */
  async getMediaList(mediaId: number, pn: number, ps: number): Promise<Result<FavoriteMedia[]>> {
    const r = await this.api.favResourceList(mediaId, pn, ps);
    if (!r.isOk) {
      return Result.err<FavoriteMedia[]>(r.error);
    }
    const data = r.value as RawResourceData;
    const medias = (data.medias ?? []).map((raw: RawMedia) => {
      const media = new FavoriteMedia();
      media.id = raw.id ?? 0;
      media.aid = raw.id ?? 0;
      media.bvid = raw.bvid ?? '';
      media.title = raw.title ?? '';
      media.cover = VideoCard.fixUrl(raw.cover ?? '');
      media.duration = raw.duration ?? 0;
      media.playCount = raw.cnt_info?.play ?? 0;
      media.danmakuCount = raw.cnt_info?.danmaku ?? 0;
      media.ownerMid = raw.upper?.mid ?? 0;
      media.ownerName = raw.upper?.name ?? '';
      media.pubdate = raw.pubtime ?? 0;
      media.favTime = raw.fav_time ?? 0;
      return media;
    }).filter((m: FavoriteMedia) => m.id > 0);
    return Result.ok<FavoriteMedia[]>(medias);
  }

  /** 收藏视频（add=true 加入收藏夹；false 从收藏夹移除） */
  async dealFavorite(aid: number, mediaId: number, add: boolean): Promise<Result<boolean>> {
    const csrf = CookieManager.getInstance().csrf;
    if (csrf.length === 0) {
      return Result.err<boolean>(AppError.unauthorized('请先登录后收藏'));
    }
    const r = await this.api.favResourceDeal(aid,
      add ? `${mediaId}` : '',
      add ? '' : `${mediaId}`,
      csrf);
    if (!r.isOk) {
      return Result.err<boolean>(r.error);
    }
    return Result.ok<boolean>(true);
  }
}
