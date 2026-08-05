/** 历史记录模型（P2 Task 16） */

@Observed
export class HistoryItem {
  /** 历史记录 kid（删除用） */
  kid: string = '';
  aid: number = 0;
  bvid: string = '';
  cid: number = 0;
  title: string = '';
  cover: string = '';
  duration: number = 0;
  ownerName: string = '';
  ownerMid: number = 0;
  /** 观看时间（秒） */
  viewAt: number = 0;
  /** 观看进度（秒） */
  progress: number = 0;
  /** 观看进度文案 */
  progressText: string = '';
  /** 设备/来源角标 */
  badge: string = '';
}

/** 历史记录分页包 */
export class HistoryPageData {
  items: HistoryItem[] = [];
  max: number = 0;
  viewAt: number = 0;
  hasMore: boolean = true;
}
