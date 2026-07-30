/** 播放地址模型（V1：muxed MP4 durl） */
export class PlayUrlInfo {
  url: string = '';
  /** 清晰度代码（qn），如 80=1080P */
  quality: number = 0;
  /** 清晰度文案 */
  qualityDesc: string = '';
  /** 时长（毫秒） */
  timelength: number = 0;
  /** 备用链接 */
  backupUrls: string[] = [];
}
