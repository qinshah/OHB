import { Result } from '../../common/result/Result';
import { AppError } from '../../common/result/AppError';
import { BiliApi } from '../../network/BiliApi';
import { CookieManager } from '../../network/CookieManager';
import { UserArchiveItem, UserArchivePage, UserSpaceInfo } from '../../models/UserSpaceModels';
import { FavoriteFolder } from '../../models/FavoriteModels';
import { VideoCard } from '../../models/VideoCard';

interface RawSpaceInfo {
  mid?: number;
  name?: string;
  face?: string;
  sign?: string;
  level?: number;
  sex?: string;
  official?: RawOfficial;
  vip?: RawVip;
}

interface RawOfficial {
  title?: string;
}

interface RawVip {
  status?: number;
}

interface RawRelationStat {
  following?: number;
  follower?: number;
}

interface RawVlistItem {
  aid?: number;
  bvid?: string;
  cid?: number;
  title?: string;
  pic?: string;
  duration?: number;
  play?: number;
  video_review?: number;
  pubdate?: number;
}

interface RawArchiveList {
  vlist?: RawVlistItem[];
}

interface RawArchivePage {
  count?: number;
}

interface RawArchiveData {
  list?: RawArchiveList;
  page?: RawArchivePage;
}

/**
 * 用户主页仓库（P2 Task 17）：空间信息、关系统计、投稿、动态、关注/取关。
 */
export class UserSpaceRepository {
  private api: BiliApi = new BiliApi();

  async getUserInfo(mid: number): Promise<Result<UserSpaceInfo>> {
    const r = await this.api.userSpaceInfo(mid);
    if (!r.isOk) {
      return Result.err<UserSpaceInfo>(r.error);
    }
    const data = r.value as RawSpaceInfo;
    const info = new UserSpaceInfo();
    info.mid = data.mid ?? mid;
    info.name = data.name ?? '';
    info.face = VideoCard.fixUrl(data.face ?? '');
    info.sign = data.sign ?? '';
    info.level = data.level ?? 0;
    info.sex = data.sex ?? '';
    info.isVip = (data.vip?.status ?? 0) === 1;
    info.officialTitle = data.official?.title ?? '';
    return Result.ok<UserSpaceInfo>(info);
  }

  async getRelationStat(mid: number): Promise<Result<UserSpaceInfo>> {
    const r = await this.api.userRelationStat(mid);
    if (!r.isOk) {
      return Result.err<UserSpaceInfo>(r.error);
    }
    const data = r.value as RawRelationStat;
    const info = new UserSpaceInfo();
    info.following = data.following ?? 0;
    info.follower = data.follower ?? 0;
    return Result.ok<UserSpaceInfo>(info);
  }

  /** 用户投稿 */
  async getArchive(mid: number, pn: number, ps: number): Promise<Result<UserArchivePage>> {
    const r = await this.api.userSpaceArchive(mid, pn, ps);
    if (!r.isOk) {
      return Result.err<UserArchivePage>(r.error);
    }
    const data = r.value as RawArchiveData;
    const page = new UserArchivePage();
    page.count = data.page?.count ?? 0;
    const vlist = data.list?.vlist ?? [];
    page.items = vlist.map((raw: RawVlistItem) => {
      const item = new UserArchiveItem();
      item.aid = raw.aid ?? 0;
      item.bvid = raw.bvid ?? '';
      item.cid = raw.cid ?? 0;
      item.title = raw.title ?? '';
      item.cover = VideoCard.fixUrl(raw.pic ?? '');
      item.duration = raw.duration ?? 0;
      item.playCount = raw.play ?? 0;
      item.danmakuCount = raw.video_review ?? 0;
      item.pubdate = raw.pubdate ?? 0;
      return item;
    }).filter((i: UserArchiveItem) => i.bvid.length > 0);
    page.hasMore = page.items.length >= ps;
    return Result.ok<UserArchivePage>(page);
  }

  /** 用户收藏夹（粉丝也可看） */
  async getFolders(mid: number): Promise<Result<FavoriteFolder[]>> {
    const r = await this.api.favFolderListAll(mid);
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

  /** 关注/取关 */
  async modifyRelation(mid: number, follow: boolean): Promise<Result<boolean>> {
    const csrf = CookieManager.getInstance().csrf;
    if (csrf.length === 0) {
      return Result.err<boolean>(AppError.unauthorized('请先登录后关注'));
    }
    const r = await this.api.relationModify(mid, follow ? 1 : 2, csrf);
    if (!r.isOk) {
      return Result.err<boolean>(r.error);
    }
    return Result.ok<boolean>(true);
  }
}

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
