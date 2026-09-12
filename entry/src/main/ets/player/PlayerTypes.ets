/** 播放器公共类型 */

/** 播放状态机（UI 层统一消费，与具体内核无关） */
export enum PlaybackState {
  /** 初始 */
  Idle,
  /** 加载/缓冲中 */
  Preparing,
  /** 已就绪 */
  Prepared,
  /** 播放中 */
  Playing,
  /** 已暂停 */
  Paused,
  /** 已停止 */
  Stopped,
  /** 播放完成 */
  Completed,
  /** 错误 */
  Error,
  /** 已释放 */
  Released
}

/**
 * 播放源（支持「单文件」与「DASH 双流」两种形态）。
 *
 * - 单文件（MP4/durl）：audioUrl 为空，音视频都在 url 中，AVPlayer 单实例直接播
 * - DASH 双流：B 站 720P 以上画质只有 DASH（视频轨/音频轨分离），
 *   需要 url=视频轨、audioUrl=音频轨，由内核起两路播放器并做音画同步
 */
export class PlaySource {
  /** 视频地址（单文件模式下含音轨） */
  url: string = '';
  /** 请求头（B 站防盗链 Referer/UA） */
  headers: Record<string, string> = {};
  /** DASH 音频轨地址；为空表示单文件模式 */
  audioUrl: string = '';
  /** 音频轨备用地址（首个失败时尝试） */
  audioBackupUrls: string[] = [];
  /**
   * DASH 双流播放失败时的兜底单文件地址提供者（惰性请求，正常路径不额外打接口）。
   * 内核在 video/audio 任一路报错时调用，拿到地址后自动切换为单文件播放。
   */
  fallbackProvider: (() => Promise<string>) | null = null;

  /** 是否 DASH 双流模式 */
  get isDash(): boolean {
    return this.audioUrl.length > 0;
  }
}
