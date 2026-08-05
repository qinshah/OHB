import { Result } from '../../common/result/Result';
import { BiliApi } from '../../network/BiliApi';
import { VideoCard } from '../../models/VideoCard';
import { DynamicFeed, DynamicItem, DynamicKind } from '../../models/DynamicItem';
import { TopicFeedCard, TopicFeedPage, TopicItem } from '../../models/TopicModels';
import { CookieManager } from '../../network/CookieManager';
import { AppError } from '../../common/result/AppError';

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

interface RawStatCount {
  count?: number;
  status?: number;
}

interface RawModuleStat {
  likes?: RawStatCount;
  comments?: RawStatCount;
  forwards?: RawStatCount;
}

interface RawModule {
  module_author?: RawAuthor;
  module_dynamic?: RawModuleDynamic;
  module_stat?: RawModuleStat;
}

interface RawDynamicItem {
  id_str?: string;
  type?: string;
  modules?: RawModule;
}

interface RawDetailData {
  item?: RawDynamicItem;
}

interface RawTopicItem {
  topic_id?: number;
  topic_name?: string;
  topic_summary?: string;
  discuss_num?: number;
  cover?: string;
}

interface RawTopicRcmdData {
  topic_items?: RawTopicItem[];
}

interface RawTopicCard {
  item?: RawDynamicItem;
}

interface RawTopicFeedData {
  topic_card_list?: RawTopicCard[];
  offset?: string;
  has_more?: boolean;
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

  static parseItem(raw: RawDynamicItem): DynamicItem | null {
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

    // 互动统计（动态详情/话题卡片）
    const stat = modules.module_stat;
    item.likeCount = stat?.likes?.count ?? 0;
    item.commentCount = stat?.comments?.count ?? 0;
    item.forwardCount = stat?.forwards?.count ?? 0;
    item.isLiked = (stat?.likes?.status ?? 0) === 1;

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

  // ---------- P2 Task 18：动态详情/互动/发布/话题 ----------

  /** 动态详情 */
  async getDetail(id: string): Promise<Result<DynamicItem>> {
    const r = await this.api.dynamicDetail(id);
    if (!r.isOk) {
      return Result.err<DynamicItem>(r.error);
    }
    const data = r.value as RawDetailData;
    const item = data.item;
    if (item === undefined) {
      return Result.err<DynamicItem>(AppError.parse('dynamic detail missing item'));
    }
    const parsed = DynamicRepository.parseItem(item);
    if (parsed === null) {
      return Result.err<DynamicItem>(AppError.parse('dynamic detail parse failed'));
    }
    return Result.ok<DynamicItem>(parsed);
  }

  /** 动态点赞/取消赞 */
  async like(id: string, liked: boolean): Promise<Result<boolean>> {
    const csrf = CookieManager.getInstance().csrf;
    if (csrf.length === 0) {
      return Result.err<boolean>(AppError.unauthorized('请先登录后点赞'));
    }
    const r = await this.api.dynamicThumb(id, liked ? 1 : 0, csrf);
    if (!r.isOk) {
      return Result.err<boolean>(r.error);
    }
    return Result.ok<boolean>(true);
  }

  /**
   * 发布图文/文字动态。
   * @param text 正文
   * @param topicId 可选话题 id（0 表示不带话题）
   * @param topicName 话题名
   */
  async publish(text: string, topicId: number = 0, topicName: string = ''): Promise<Result<boolean>> {
    const csrf = CookieManager.getInstance().csrf;
    if (csrf.length === 0) {
      return Result.err<boolean>(AppError.unauthorized('请先登录后发布动态'));
    }
    if (text.trim().length === 0) {
      return Result.err<boolean>(AppError.business(-400, '动态内容不能为空'));
    }
    const mid = CookieManager.getInstance().get('DedeUserID');
    const uploadId = `${mid}_${Math.floor(Date.now() / 1000)}_${Math.floor(Math.random() * 9000) + 1000}`;
    const dynReq: PublishDynReq = {
      content: {
        contents: [{ raw_text: text, type: 1, biz_id: '' }]
      },
      scene: 1,
      upload_id: uploadId,
      meta: {
        app_meta: { from: 'create.dynamic.web', mobi_app: 'web' }
      }
    };
    if (topicId > 0 && topicName.length > 0) {
      dynReq.topic = {
        id: topicId,
        name: topicName,
        from_source: 'dyn.web.list',
        from_topic_id: 0
      };
    }
    const r = await this.api.dynamicCreate(JSON.stringify(dynReq), csrf);
    if (!r.isOk) {
      return Result.err<boolean>(r.error);
    }
    return Result.ok<boolean>(true);
  }

  /** 用户主页动态流 */
  async getSpaceFeed(mid: number, offset: string): Promise<Result<DynamicFeed>> {
    const r = await this.api.userSpaceDynamic(mid, offset);
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

  /** 话题广场推荐话题 */
  async getTopicRecommend(pageSize: number = 25): Promise<Result<TopicItem[]>> {
    const r = await this.api.topicRcmd(pageSize);
    if (!r.isOk) {
      return Result.err<TopicItem[]>(r.error);
    }
    const data = r.value as RawTopicRcmdData;
    const items = (data.topic_items ?? []).map((raw: RawTopicItem) => {
      const topic = new TopicItem();
      topic.topicId = raw.topic_id ?? 0;
      topic.topicName = raw.topic_name ?? '';
      topic.desc = raw.topic_summary ?? '';
      topic.discussCount = raw.discuss_num ?? 0;
      topic.cover = VideoCard.fixUrl(raw.cover ?? '');
      return topic;
    }).filter((t: TopicItem) => t.topicId > 0);
    return Result.ok<TopicItem[]>(items);
  }

  /** 话题动态流 */
  async getTopicFeed(topicId: number, offset: string, sortBy: number): Promise<Result<TopicFeedPage>> {
    const r = await this.api.topicFeed(topicId, offset, sortBy);
    if (!r.isOk) {
      return Result.err<TopicFeedPage>(r.error);
    }
    const data = r.value as RawTopicFeedData;
    const page = new TopicFeedPage();
    page.offset = data.offset ?? '';
    page.hasMore = data.has_more ?? true;
    const cards = data.topic_card_list ?? [];
    const parsed: TopicFeedCard[] = [];
    for (let i = 0; i < cards.length; i++) {
      const item = cards[i].item;
      if (item === undefined) {
        continue;
      }
      const dyn = DynamicRepository.parseItem(item);
      if (dyn === null) {
        continue;
      }
      const card = new TopicFeedCard();
      card.idStr = dyn.idStr;
      card.text = dyn.text;
      card.images = dyn.images;
      card.upName = dyn.upName;
      card.upFace = dyn.upFace;
      card.upMid = dyn.upMid;
      card.pubTs = dyn.pubTs;
      card.videoBvid = dyn.videoBvid;
      card.videoTitle = dyn.videoTitle;
      card.videoCover = dyn.videoCover;
      card.videoDuration = dyn.videoDuration;
      card.likeCount = dyn.likeCount;
      parsed.push(card);
    }
    page.items = parsed;
    return Result.ok<TopicFeedPage>(page);
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

/** 发布动态请求体（dyn_req JSON 形状） */
interface PublishDynReq {
  content: PublishDynContent;
  scene: number;
  upload_id: string;
  meta: PublishDynMeta;
  topic?: PublishDynTopic;
}

interface PublishDynContent {
  contents: PublishDynText[];
}

interface PublishDynText {
  raw_text: string;
  type: number;
  biz_id: string;
}

interface PublishDynMeta {
  app_meta: PublishDynAppMeta;
}

interface PublishDynAppMeta {
  from: string;
  mobi_app: string;
}

interface PublishDynTopic {
  id: number;
  name: string;
  from_source: string;
  from_topic_id: number;
}
