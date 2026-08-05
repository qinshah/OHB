import { DataState, DataStatus } from '../common/state/DataState';
import { AppError } from '../common/result/AppError';
import { LiveArea, LiveRoom } from '../models/LiveModels';
import { LiveRepository } from '../data/repository/LiveRepository';

/**
 * 直播 ViewModel（P2 Task 15）：分区 + 直播间列表分页。
 */
@Observed
export class LiveViewModel {
  areaState: DataState<LiveArea[]> = DataState.idle<LiveArea[]>();
  areas: LiveArea[] = [];
  roomState: DataState<LiveRoom[]> = DataState.idle<LiveRoom[]>();
  rooms: LiveRoom[] = [];
  isLoadingMore: boolean = false;
  hasMore: boolean = true;
  /** 当前选中分区 id（0=全部） */
  currentAreaId: number = 0;

  private repo: LiveRepository = new LiveRepository();
  private page: number = 1;

  async loadAreas(): Promise<void> {
    if (this.areaState.status !== DataStatus.Idle) {
      return;
    }
    this.areaState = DataState.loading<LiveArea[]>();
    const r = await this.repo.getAreas();
    if (r.isOk) {
      this.areas = r.value;
      this.areaState = this.areas.length > 0
        ? DataState.data<LiveArea[]>(this.areas)
        : DataState.empty<LiveArea[]>();
    } else {
      this.areaState = DataState.error<LiveArea[]>(r.error);
    }
  }

  async loadFirst(areaId: number = 0): Promise<void> {
    this.currentAreaId = areaId;
    this.page = 1;
    this.hasMore = true;
    this.roomState = DataState.loading<LiveRoom[]>();
    await this.fetch(false);
  }

  async loadMore(): Promise<void> {
    if (this.isLoadingMore || !this.hasMore) {
      return;
    }
    this.isLoadingMore = true;
    this.page++;
    await this.fetch(true);
    this.isLoadingMore = false;
  }

  private async fetch(append: boolean): Promise<void> {
    const r = await this.repo.getRooms(this.page, this.currentAreaId, 0);
    if (!r.isOk) {
      this.roomState = DataState.error<LiveRoom[]>(r.error, this.rooms.length > 0 ? this.rooms : null);
      return;
    }
    const list = r.value;
    this.hasMore = list.length > 0;
    if (append) {
      this.rooms = this.rooms.concat(list);
    } else {
      this.rooms = list;
    }
    this.roomState = this.rooms.length > 0
      ? DataState.data<LiveRoom[]>(this.rooms)
      : DataState.empty<LiveRoom[]>();
  }

  get errorMessage(): string {
    return this.roomState.error?.message ?? AppError.unknown('').message;
  }
}
