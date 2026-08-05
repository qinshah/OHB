import { DataState, DataStatus } from '../common/state/DataState';
import { AppError } from '../common/result/AppError';
import { UserArchiveItem, UserArchivePage, UserSpaceInfo } from '../models/UserSpaceModels';
import { DynamicFeed, DynamicItem } from '../models/DynamicItem';
import { FavoriteFolder } from '../models/FavoriteModels';
import { UserSpaceRepository } from '../data/repository/UserSpaceRepository';
import { DynamicRepository } from '../data/repository/DynamicRepository';

/**
 * 用户主页 ViewModel（P2 Task 17）：空间信息、关注、视频/动态/收藏 Tab。
 */
@Observed
export class UserSpaceViewModel {
  infoState: DataState<UserSpaceInfo> = DataState.idle<UserSpaceInfo>();
  info: UserSpaceInfo | null = null;
  isFollowing: boolean = false;
  followBusy: boolean = false;
  tipText: string = '';

  archiveState: DataState<UserArchiveItem[]> = DataState.idle<UserArchiveItem[]>();
  archives: UserArchiveItem[] = [];
  archivePage: number = 1;
  archiveHasMore: boolean = true;
  isLoadingArchive: boolean = false;

  dynamicState: DataState<DynamicItem[]> = DataState.idle<DynamicItem[]>();
  dynamics: DynamicItem[] = [];
  dynOffset: string = '';
  dynHasMore: boolean = true;
  isLoadingDynamic: boolean = false;

  folderState: DataState<FavoriteFolder[]> = DataState.idle<FavoriteFolder[]>();
  folders: FavoriteFolder[] = [];

  private mid: number = 0;
  private spaceRepo: UserSpaceRepository = new UserSpaceRepository();
  private dynRepo: DynamicRepository = new DynamicRepository();

  init(mid: number): void {
    this.mid = mid;
  }

  async load(): Promise<void> {
    this.infoState = DataState.loading<UserSpaceInfo>();
    const infoR = await this.spaceRepo.getUserInfo(this.mid);
    if (!infoR.isOk) {
      this.infoState = DataState.error<UserSpaceInfo>(infoR.error);
      return;
    }
    this.info = infoR.value;
    const statR = await this.spaceRepo.getRelationStat(this.mid);
    if (statR.isOk) {
      this.info.follower = statR.value.follower;
      this.info.following = statR.value.following;
    }
    this.infoState = DataState.data<UserSpaceInfo>(this.info);
    await this.loadArchives();
  }

  async loadArchives(): Promise<void> {
    if (this.archiveState.status !== DataStatus.Idle && this.archiveState.status !== DataStatus.Data) {
      return;
    }
    this.archiveState = DataState.loading<UserArchiveItem[]>();
    this.archivePage = 1;
    await this.fetchArchives(false);
  }

  async loadMoreArchives(): Promise<void> {
    if (this.isLoadingArchive || !this.archiveHasMore) {
      return;
    }
    this.isLoadingArchive = true;
    this.archivePage++;
    await this.fetchArchives(true);
    this.isLoadingArchive = false;
  }

  private async fetchArchives(append: boolean): Promise<void> {
    const r = await this.spaceRepo.getArchive(this.mid, this.archivePage, 20);
    if (!r.isOk) {
      this.archiveState = DataState.error<UserArchiveItem[]>(r.error, this.archives.length > 0 ? this.archives : null);
      return;
    }
    const page: UserArchivePage = r.value;
    this.archiveHasMore = page.hasMore;
    if (this.info !== null && this.info.archiveCount === 0) {
      this.info.archiveCount = page.count;
    }
    if (append) {
      this.archives = this.archives.concat(page.items);
    } else {
      this.archives = page.items;
    }
    this.archiveState = this.archives.length > 0
      ? DataState.data<UserArchiveItem[]>(this.archives)
      : DataState.empty<UserArchiveItem[]>();
  }

  async loadDynamics(): Promise<void> {
    this.dynamicState = DataState.loading<DynamicItem[]>();
    this.dynOffset = '';
    await this.fetchDynamics(false);
  }

  async loadMoreDynamics(): Promise<void> {
    if (this.isLoadingDynamic || !this.dynHasMore) {
      return;
    }
    this.isLoadingDynamic = true;
    await this.fetchDynamics(true);
    this.isLoadingDynamic = false;
  }

  private async fetchDynamics(append: boolean): Promise<void> {
    const r = await this.dynRepo.getSpaceFeed(this.mid, this.dynOffset);
    if (!r.isOk) {
      this.dynamicState = DataState.error<DynamicItem[]>(r.error, this.dynamics.length > 0 ? this.dynamics : null);
      return;
    }
    const feed: DynamicFeed = r.value;
    this.dynOffset = feed.offset;
    this.dynHasMore = feed.hasMore;
    if (append) {
      this.dynamics = this.dynamics.concat(feed.items);
    } else {
      this.dynamics = feed.items;
    }
    this.dynamicState = this.dynamics.length > 0
      ? DataState.data<DynamicItem[]>(this.dynamics)
      : DataState.empty<DynamicItem[]>();
  }

  async loadFolders(): Promise<void> {
    this.folderState = DataState.loading<FavoriteFolder[]>();
    const r = await this.spaceRepo.getFolders(this.mid);
    if (r.isOk) {
      this.folders = r.value;
      this.folderState = this.folders.length > 0
        ? DataState.data<FavoriteFolder[]>(this.folders)
        : DataState.empty<FavoriteFolder[]>();
    } else {
      this.folderState = DataState.error<FavoriteFolder[]>(r.error);
    }
  }

  async toggleFollow(): Promise<void> {
    if (this.followBusy) {
      return;
    }
    this.followBusy = true;
    const r = await this.spaceRepo.modifyRelation(this.mid, !this.isFollowing);
    this.followBusy = false;
    if (r.isOk) {
      this.isFollowing = !this.isFollowing;
    } else {
      this.tipText = r.error.message;
    }
  }

  get errorMessage(): string {
    return this.infoState.error?.message ?? AppError.unknown('').message;
  }
}
