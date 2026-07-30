import { Result } from '../../common/result/Result';
import { BiliApi } from '../../network/BiliApi';
import { VideoCard } from '../../models/VideoCard';
import { DynamicFeed, DynamicItem, DynamicKind } from '../../models/DynamicItem';

interface RawAuthor {
  mid?: number;
  name?: string;
  face?: string;
  pub_ts?: number;
}

interface RawArchiveStat {
  play?: string;
  danmaku?: string;
}

interface RawArchive {
  bvid?: string;
  title?: string;
  cover?: string;
  duration_text?: string;
  stat?: RawArchiveStat;
}

interface RawDrawItem {
  src?: string;
}

interface RawDraw {
  items?: RawDrawItem[];
}

interface RawOpusPics {
  url?: string;
}

interface RawOpusSummary {
  text?: string;
}

interface RawOpus {
  pics?: RawOpusPics[];
  summary?: RawOpusSummary;
}

interface RawMajor {
  archive?: RawArchive;
  draw?: RawDraw;
  opus?: RawOpus;
}

interface RawDynamicDesc {
  text?: string;
}

interface RawModuleDynamic {
  desc?: RawDynamicDesc;
  major?: RawMajor;
}

interface RawDynamicModule {
  module_author?: RawAuthor;
  module_dynamic?: RawModuleDynamic;
}

interface RawDynamicItem {
  id_str?: string;
  type?: string;
  modules?: RawDynamicModule;
}

interface RawDynamicData {
  offset?: string;
  has_more?: boolean;
  items?: RawDynamicItem[];
}

/**
 * 动态仓库（Task 8）：关注动态流加载（V1 仅加载与跳转）。
 */
export class DynamicRepository {
  private api: BiliApi = new BiliApi();

  async getFeed(offset: string): Promise<Result<DynamicFeed>> {
    const r = await this.api.dynamicFeed(offset);
    if (!r.isOk) {
      return Result.err<DynamicFeed>(r.error);
    }
    const data = r.value as RawDynamicData;
    const feed = new DynamicFeed();
    feed.offset = data.offset ?? '';
    feed.hasMore = data.has_more ?? false;
    const rawItems = data.items ?? [];
    const parsed: DynamicItem[] = [];
    for (let i = 0; i < rawItems.length; i++) {
      const item = DynamicRepository.parseItem(rawItems[i]);
      if (item !== null) {
        parsed.push(item);
      }
    }
    feed.items = parsed;
    return Result.ok<DynamicFeed>(feed);
  }

  private static parseItem(raw: RawDynamicItem): DynamicItem | null {
    const modules = raw.modules;
    if (modules === undefined) {
      return null;
    }
    const item = new DynamicItem();
    item.idStr = raw.id_str ?? '';
    const author = modules.module_author;
    item.upMid = author?.mid ?? 0;
    item.upName = author?.name ?? '';
    item.upFace = VideoCard.fixUrl(author?.face ?? '');
    item.pubTs = author?.pub_ts ?? 0;

    const dyn = modules.module_dynamic;
    const major = dyn?.major;
    item.text = dyn?.desc?.text ?? major?.opus?.summary?.text ?? '';

    const type = raw.type ?? '';
    if (type === 'DYNAMIC_TYPE_AV' && major?.archive !== undefined) {
      const arc = major.archive;
      item.kind = DynamicKind.Video;
      item.videoBvid = arc.bvid ?? '';
      item.videoTitle = arc.title ?? '';
      item.videoCover = VideoCard.fixUrl(arc.cover ?? '');
      item.videoDuration = DynamicRepository.parseDuration(arc.duration_text ?? '');
      item.videoPlayCount = DynamicRepository.parseCount(arc.stat?.play ?? '');
      item.videoDanmakuCount = DynamicRepository.parseCount(arc.stat?.danmaku ?? '');
    } else if (type === 'DYNAMIC_TYPE_DRAW' || (major?.draw !== undefined) || (major?.opus !== undefined)) {
      item.kind = DynamicKind.Article;
      const drawItems = major?.draw?.items ?? [];
      const opusPics = major?.opus?.pics ?? [];
      const imgs: string[] = [];
      for (let i = 0; i < drawItems.length; i++) {
        if (drawItems[i].src !== undefined) {
          imgs.push(VideoCard.fixUrl(drawItems[i].src ?? ''));
        }
      }
      for (let i = 0; i < opusPics.length; i++) {
        if (opusPics[i].url !== undefined) {
          imgs.push(VideoCard.fixUrl(opusPics[i].url ?? ''));
        }
      }
      item.images = imgs;
    } else if (type === 'DYNAMIC_TYPE_FORWARD') {
      item.kind = DynamicKind.Forward;
    } else {
      item.kind = DynamicKind.Other;
    }
    return item;
  }

  private static parseDuration(s: string): number {
    const parts = s.split(':');
    let sec = 0;
    for (let i = 0; i < parts.length; i++) {
      const n = Number(parts[i]);
      if (!isNaN(n)) {
        sec = sec * 60 + n;
      }
    }
    return sec;
  }

  private static parseCount(s: string): number {
    if (s.endsWith('万')) {
      return Math.floor(Number(s.replace('万', '')) * 10000);
    }
    const n = Number(s);
    return isNaN(n) ? 0 : n;
  }
}
