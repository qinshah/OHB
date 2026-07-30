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
