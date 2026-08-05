import { DataState, DataStatus } from '../common/state/DataState';
import { AppError } from '../common/result/AppError';
import { FavoriteFolder, FavoriteMedia } from '../models/FavoriteModels';
import { FavoriteRepository } from '../data/repository/FavoriteRepository';

/**
 * 收藏 ViewModel（P2 Task 16）：收藏夹列表 / 收藏夹内视频分页。
 */
@Observed
export class FavoriteViewModel {
  folderState: DataState<FavoriteFolder[]> = DataState.idle<FavoriteFolder[]>();
  folders: FavoriteFolder[] = [];

  mediaState: DataState<FavoriteMedia[]> = DataState.idle<FavoriteMedia[]>();
  medias: FavoriteMedia[] = [];
  currentMediaId: number = 0;
  isLoadingMore: boolean = false;
  hasMore: boolean = true;
  tipText: string = '';

  private repo: FavoriteRepository = new FavoriteRepository();
  private page: number = 1;
  private loadSeq: number = 0;

  async loadFolders(upMid: number): Promise<void> {
    this.folderState = DataState.loading<FavoriteFolder[]>();
    const r = await this.repo.getFolders(upMid);
    if (r.isOk) {
      this.folders = r.value;
      this.folderState = this.folders.length > 0
        ? DataState.data<FavoriteFolder[]>(this.folders)
        : DataState.empty<FavoriteFolder[]>();
    } else {
      this.folderState = DataState.error<FavoriteFolder[]>(r.error);
    }
  }

  async loadMediaFirst(mediaId: number): Promise<void> {
    this.loadSeq++;
    const seq = this.loadSeq;
    this.currentMediaId = mediaId;
    this.page = 1;
    this.hasMore = true;
    this.mediaState = DataState.loading<FavoriteMedia[]>();
    await this.fetchMedia(seq, false);
  }

  async loadMoreMedia(): Promise<void> {
    if (this.isLoadingMore || !this.hasMore) {
      return;
    }
    this.isLoadingMore = true;
    this.page++;
    await this.fetchMedia(this.loadSeq, true);
    this.isLoadingMore = false;
  }

  private async fetchMedia(seq: number, append: boolean): Promise<void> {
    const r = await this.repo.getMediaList(this.currentMediaId, this.page, 20);
    if (seq !== this.loadSeq) {
      return;
    }
    if (!r.isOk) {
      this.mediaState = DataState.error<FavoriteMedia[]>(r.error, this.medias.length > 0 ? this.medias : null);
      return;
    }
    const list = r.value;
    this.hasMore = list.length > 0;
    if (append) {
      this.medias = this.medias.concat(list);
    } else {
      this.medias = list;
    }
    this.mediaState = this.medias.length > 0
      ? DataState.data<FavoriteMedia[]>(this.medias)
      : DataState.empty<FavoriteMedia[]>();
  }

  /** 从收藏夹移除 */
  async removeMedia(media: FavoriteMedia): Promise<boolean> {
    const r = await this.repo.dealFavorite(media.aid, this.currentMediaId, false);
    if (!r.isOk) {
      this.tipText = r.error.message;
      return false;
    }
    const idx = this.medias.findIndex((m: FavoriteMedia) => m.id === media.id);
    if (idx >= 0) {
      this.medias.splice(idx, 1);
    }
    this.tipText = '已取消收藏';
    return true;
  }

  get errorMessage(): string {
    return this.mediaState.error?.message ?? this.folderState.error?.message ?? AppError.unknown('').message;
  }
}
