// [API 23+] 弹幕数据控制器（对齐 PiliPlus PlDanmakuController 的分段加载逻辑）
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BiliApi } from '../../network/BiliApi';
import { parseDmSegReply } from '../../network/DanmakuProto';
import { DanmakuItem } from '../../models/DanmakuModels';
import { Pref } from '../storage/Pref';

/**
 * 弹幕数据控制器（cid 维度）
 *
 * 核心逻辑（对齐 PiliPlus lib/pages/danmaku/controller.dart）：
 * - 分段拉取：每 6 分钟（360000ms）一段，seg.so 的 segment_index 从 1 开始
 * - 0.1s 分桶：dmSegMap 的 key = progress / 100（渲染层每 100ms 取一次桶）
 * - 防重复：requestedSeg 记录已请求段落；请求失败时移除标记以允许重试
 * - 按需加载：getCurrentDanmaku 发现所在段未加载时异步触发请求，本次返回 null
 */
export class DanmakuController {
  /** 分段长度：6 分钟 */
  static readonly SEGMENT_LENGTH: number = 360000;
  /** 分桶粒度：0.1 秒 */
  static readonly BUCKET_LENGTH: number = 100;
  private cid: number;
  /** 0.1s 桶 → 弹幕列表 */
  private dmSegMap: Map<number, DanmakuItem[]> = new Map();
  /** 已请求段落（防重复；失败时移除以允许重试） */
  private requestedSeg: Set<number> = new Set();
  private api: BiliApi = new BiliApi();

  constructor(cid: number) {
    this.cid = cid;
  }

  /** 进度对应的段号（从 0 开始；接口 segment_index 需 +1） */
  static calcSegment(progressMs: number): number {
    return Math.floor(progressMs / DanmakuController.SEGMENT_LENGTH);
  }

  /** 进度对应的 0.1s 桶号 */
  static calcBucket(progressMs: number): number {
    return Math.floor(progressMs / DanmakuController.BUCKET_LENGTH);
  }

  /**
   * 按需请求某段弹幕（异步，fire-and-forget，重复调用自动去重）
   * 失败时移除已请求标记，下个 tick 可重试
   */
  async queryDanmaku(segmentIndex: number): Promise<void> {
    if (this.requestedSeg.has(segmentIndex)) {
      return;
    }
    this.requestedSeg.add(segmentIndex);
    const r = await this.api.dmSeg(this.cid, segmentIndex + 1);
    if (!r.isOk) {
      // 风控（412/352）/未登录等场景：移除标记允许重试，弹幕静默降级
      this.requestedSeg.delete(segmentIndex);
      hilog.warn(0x0000, TAG, 'dmSeg fail cid=%{public}d seg=%{public}d: %{public}s', this.cid, segmentIndex, r.error.message);
      return;
    }
    const items: DanmakuItem[] = parseDmSegReply(r.value);
    hilog.info(0x0000, TAG, 'dmSeg ok cid=%{public}d seg=%{public}d count=%{public}d', this.cid, segmentIndex, items.length);
    this.handleDanmaku(items);
  }

  /**
   * 合并重复 + 分桶（对齐 PiliPlus handleDanmaku）
   * - 开启「合并弹幕」时：同内容弹幕合并到首条（count++），不再单独入桶
   * - 高级弹幕（mode 7）本版不渲染，直接丢弃
   */
  private handleDanmaku(items: DanmakuItem[]): void {
    if (items.length === 0) {
      return;
    }
    const merge: boolean = Pref.danmakuMerge.get();
    const uniques: Map<string, DanmakuItem> = new Map();
    for (let i = 0; i < items.length; i++) {
      const item: DanmakuItem = items[i];
      if (item.mode === 7) {
        // 高级弹幕 content 为动画脚本 JSON，DFM 需逐字段映射，后续迭代支持
        continue;
      }
      if (merge) {
        const exist: DanmakuItem | undefined = uniques.get(item.content);
        if (exist !== undefined) {
          exist.count++;
          continue;
        }
        uniques.set(item.content, item);
      }
      const bucket: number = DanmakuController.calcBucket(item.progress);
      let list: DanmakuItem[] | undefined = this.dmSegMap.get(bucket);
      if (list === undefined) {
        list = [];
        this.dmSegMap.set(bucket, list);
      }
      list.push(item);
    }
  }

  /**
   * 取当前时刻（0.1s 桶）的弹幕：
   * 所在段未加载时异步触发请求并返回 null（下个 tick 再取）
   */
  getCurrentDanmaku(progressMs: number): DanmakuItem[] | null {
    const segmentIndex: number = DanmakuController.calcSegment(progressMs);
    if (!this.requestedSeg.has(segmentIndex)) {
      this.queryDanmaku(segmentIndex);
      return null;
    }
    return this.dmSegMap.get(DanmakuController.calcBucket(progressMs)) ?? null;
  }

  /** 释放数据 */
  dispose(): void {
    this.dmSegMap.clear();
    this.requestedSeg.clear();
  }
}

/**
 * 静态注册表：cid → 控制器
 * 详情页与全屏页各持一个渲染层，共享同一份数据（避免重复请求）；
 * 页面彻底关闭时由 VideoDetailVM.release 移除
 */
export class DanmakuControllerManager {
  private static map: Map<number, DanmakuController> = new Map();

  /** 获取（不存在则创建）cid 对应的控制器 */
  static get(cid: number): DanmakuController {
    let c: DanmakuController | undefined = DanmakuControllerManager.map.get(cid);
    if (c === undefined) {
      c = new DanmakuController(cid);
      DanmakuControllerManager.map.set(cid, c);
    }
    return c;
  }

  /** 页面彻底关闭时释放数据 */
  static remove(cid: number): void {
    const c: DanmakuController | undefined = DanmakuControllerManager.map.get(cid);
    if (c !== undefined) {
      c.dispose();
      DanmakuControllerManager.map.delete(cid);
    }
  }
}

const TAG = DanmakuControllerManager.name ?? 'DanmakuControllerManager'