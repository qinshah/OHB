// [API 23+] 系统级音量监听（调节由 AVVolumePanel 组件完成）
import { audio } from '@kit.AudioKit';
import { Logger } from './Logger';

/**
 * SystemAudioHelper
 *
 * 基于 @kit.AudioKit 的系统音量（音乐流）监听器。
 *
 * 设计要点：
 * - 应用无法直接调节系统音量，调节动作改由 AVVolumePanel 组件完成（见 PlayerControlView）
 * - 本类只负责"监听 + 读取"：通过 AudioVolumeManager 的 streamVolumeChange 事件，
 *   维护当前/最大/最小档位，供 Hub 显示真实值
 * - 不再持有 setVolume 接口，避免直接调用系统设值接口（系统不允许应用主动设值）
 *
 * API 选型（compileSdkVersion 26）：
 * - getVolumeByStream / getMinVolumeByStream / getMaxVolumeByStream（API 20+，同步）
 * - on('streamVolumeChange', streamUsage, callback)（API 20+，替代已废弃的 volumeChange）
 */
export class SystemAudioHelper {
  private static volMgr: audio.AudioVolumeManager | null = null;
  /** 音量变化监听者列表：Controller 回写 systemVolume + UI Hub 提示等可并存 */
  private static volumeCbs: Array<(volume: number) => void> = [];
  private static pCurrent: number = 0;
  private static pMax: number = 1;
  private static pMin: number = 0;
  private static pInitialized: boolean = false;
  private static readonly STREAM: audio.StreamUsage = audio.StreamUsage.STREAM_USAGE_MUSIC;

  /**
   * 初始化：获取 AudioVolumeManager 并注册音乐流音量变化监听。
   * 在 EntryAbility onCreate 中调用一次即可。
   */
  static async init(): Promise<void> {
    if (SystemAudioHelper.pInitialized) {
      return;
    }
    try {
      const mgr = audio.getAudioManager().getVolumeManager();
      SystemAudioHelper.volMgr = mgr;
      SystemAudioHelper.pMax = mgr.getMaxVolumeByStream(SystemAudioHelper.STREAM);
      SystemAudioHelper.pMin = mgr.getMinVolumeByStream(SystemAudioHelper.STREAM);
      SystemAudioHelper.pCurrent = mgr.getVolumeByStream(SystemAudioHelper.STREAM);
      mgr.on('streamVolumeChange', SystemAudioHelper.STREAM, (event: audio.StreamVolumeEvent) => {
        SystemAudioHelper.pCurrent = event.volume;
        SystemAudioHelper.notifyVolume(event.volume);
      });
      SystemAudioHelper.pInitialized = true;
      Logger.info('SysAudio', `init ok, range=[${SystemAudioHelper.pMin}, ${SystemAudioHelper.pMax}], cur=${SystemAudioHelper.pCurrent}`);
    } catch (e) {
      Logger.error('SysAudio', `init fail: ${JSON.stringify(e)}`);
    }
  }

  /** 注册系统音量变化回调（单监听者语义：清空原有后仅保留一个，兼容旧调用） */
  static setVolumeListener(cb: ((volume: number) => void) | null): void {
    SystemAudioHelper.volumeCbs = [];
    if (cb !== null) {
      SystemAudioHelper.volumeCbs.push(cb);
    }
  }

  /** 追加系统音量变化监听（支持多监听者：Controller 回写 + UI Hub 提示） */
  static addVolumeListener(cb: (volume: number) => void): void {
    SystemAudioHelper.volumeCbs.push(cb);
  }

  /** 移除系统音量变化监听（组件销毁时必须调用，避免泄漏） */
  static removeVolumeListener(cb: (volume: number) => void): void {
    const idx = SystemAudioHelper.volumeCbs.indexOf(cb);
    if (idx >= 0) {
      SystemAudioHelper.volumeCbs.splice(idx, 1);
    }
  }

  /** 广播音量变化给所有监听者 */
  private static notifyVolume(volume: number): void {
    SystemAudioHelper.volumeCbs.forEach((cb: (volume: number) => void) => {
      cb(volume);
    });
  }

  /** 当前系统音量（0..maxVolume） */
  static get currentVolume(): number {
    return SystemAudioHelper.pCurrent;
  }

  static get maxVolume(): number {
    return SystemAudioHelper.pMax;
  }

  static get minVolume(): number {
    return SystemAudioHelper.pMin;
  }

  /** 当前音量归一化到 0..1（用于显示百分比） */
  static get normalizedVolume(): number {
    if (SystemAudioHelper.pMax <= SystemAudioHelper.pMin) {
      return 0;
    }
    const v = (SystemAudioHelper.pCurrent - SystemAudioHelper.pMin) /
      (SystemAudioHelper.pMax - SystemAudioHelper.pMin);
    return Math.max(0, Math.min(1, v));
  }

  /** 从系统同步读取一次当前音量（用于初始化或手动同步） */
  static syncFromSystem(): void {
    if (SystemAudioHelper.volMgr === null) {
      return;
    }
    try {
      SystemAudioHelper.pCurrent =
        SystemAudioHelper.volMgr.getVolumeByStream(SystemAudioHelper.STREAM);
    } catch (e) {
      Logger.error('SysAudio', `syncFromSystem fail: ${JSON.stringify(e)}`);
    }
  }

  static get isInitialized(): boolean {
    return SystemAudioHelper.pInitialized;
  }
}
