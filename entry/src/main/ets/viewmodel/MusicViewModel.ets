import { DataState, DataStatus } from '../common/state/DataState';
import { AppError } from '../common/result/AppError';
import { VideoCard } from '../models/VideoCard';
import { MusicRepository } from '../data/repository/MusicRepository';

/**
 * 音乐 ViewModel（P2 Task 20）：音乐分区排行（rid=3）。
 */
@Observed
export class MusicViewModel {
  state: DataState<VideoCard[]> = DataState.idle<VideoCard[]>();
  items: VideoCard[] = [];

  private repo: MusicRepository = new MusicRepository();

  async load(): Promise<void> {
    if (this.state.status !== DataStatus.Idle) {
      return;
    }
    this.state = DataState.loading<VideoCard[]>();
    const r = await this.repo.getMusicRank();
    if (r.isOk) {
      this.items = r.value;
      this.state = this.items.length > 0
        ? DataState.data<VideoCard[]>(this.items)
        : DataState.empty<VideoCard[]>();
    } else {
      this.state = DataState.error<VideoCard[]>(r.error);
    }
  }

  get errorMessage(): string {
    return this.state.error?.message ?? AppError.unknown('').message;
  }
}
