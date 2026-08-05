import { Result } from '../../common/result/Result';
import { BiliApi } from '../../network/BiliApi';
import { VideoCard } from '../../models/VideoCard';

interface RawRankOwner {
  mid?: number;
  name?: string;
  face?: string;
}

interface RawRankStat {
  view?: number;
  danmaku?: number;
}

interface RawRankItem {
  aid?: number;
  bvid?: string;
  cid?: number;
  title?: string;
  pic?: string;
  duration?: number;
  pubdate?: number;
  owner?: RawRankOwner;
  stat?: RawRankStat;
}

interface RawRankData {
  list?: RawRankItem[];
}

/**
 * 音乐仓库（P2 Task 20）：音乐分区排行列表（rid=3），复用 VideoCard。
 */
export class MusicRepository {
  private api: BiliApi = new BiliApi();

  async getMusicRank(): Promise<Result<VideoCard[]>> {
    const r = await this.api.ranking(3);
    if (!r.isOk) {
      return Result.err<VideoCard[]>(r.error);
    }
    const data = r.value as RawRankData;
    const cards = (data.list ?? []).map((raw: RawRankItem) => {
      const c = new VideoCard();
      c.aid = raw.aid ?? 0;
      c.bvid = raw.bvid ?? '';
      c.cid = raw.cid ?? 0;
      c.title = raw.title ?? '';
      c.cover = VideoCard.fixUrl(raw.pic ?? '');
      c.duration = raw.duration ?? 0;
      c.pubdate = raw.pubdate ?? 0;
      c.ownerMid = raw.owner?.mid ?? 0;
      c.ownerName = raw.owner?.name ?? '';
      c.ownerFace = VideoCard.fixUrl(raw.owner?.face ?? '');
      c.playCount = raw.stat?.view ?? 0;
      c.danmakuCount = raw.stat?.danmaku ?? 0;
      c.tname = '音乐';
      return c;
    }).filter((c: VideoCard) => c.bvid.length > 0);
    return Result.ok<VideoCard[]>(cards);
  }
}
