import { avSession } from '@kit.AVSessionKit';
import { common } from '@kit.AbilityKit';
import { Logger } from '../../common/utils/Logger';

/**
 * 媒体会话辅助（P2 Task 20：MediaSession 锁屏控制）
 * 封装 AVSession 创建、元数据/播放状态同步与命令回调注册，失败静默降级。
 */
export class MediaSessionHelper {
  private static session: avSession.AVSession | null = null;
  private static attached: boolean = false;

  /** 创建/复用会话并写入元数据 */
  static async attach(context: common.Context, title: string, artist: string, durationMs: number): Promise<void> {
    try {
      if (MediaSessionHelper.session === null) {
        MediaSessionHelper.session = await avSession.createAVSession(context, 'OHB', 'video');
        MediaSessionHelper.attached = true;
      }
      const metadata: avSession.AVMetadata = {
        assetId: 'ohb_playback',
        title: title,
        artist: artist,
        duration: durationMs
      };
      await MediaSessionHelper.session.setAVMetadata(metadata);
    } catch (e) {
      Logger.warn('MediaSession', `attach fail: ${JSON.stringify(e)}`);
    }
  }

  /** 同步播放状态（state 使用 avSession.PlaybackState） */
  static async updateState(state: number, positionMs: number): Promise<void> {
    if (MediaSessionHelper.session === null) {
      return;
    }
    try {
      const playbackState: avSession.AVPlaybackState = {
        state: state,
        position: {
          elapsedTime: Math.max(0, positionMs),
          updateTime: Date.now()
        }
      };
      await MediaSessionHelper.session.setAVPlaybackState(playbackState);
    } catch (e) {
      Logger.warn('MediaSession', `updateState fail: ${JSON.stringify(e)}`);
    }
  }

  /** 注册播控命令回调（锁屏/控制中心触发） */
  static setCommandCallbacks(onPlay: () => void, onPause: () => void, onSeek: (time: number) => void): void {
    if (MediaSessionHelper.session === null) {
      return;
    }
    try {
      MediaSessionHelper.session.on('play', onPlay);
      MediaSessionHelper.session.on('pause', onPause);
      MediaSessionHelper.session.on('seek', onSeek);
    } catch (e) {
      Logger.warn('MediaSession', `setCommandCallbacks fail: ${JSON.stringify(e)}`);
    }
  }

  static async detach(): Promise<void> {
    if (MediaSessionHelper.session !== null) {
      try {
        await MediaSessionHelper.session.destroy();
      } catch (e) {
        Logger.warn('MediaSession', `detach fail: ${JSON.stringify(e)}`);
      }
      MediaSessionHelper.session = null;
    }
    MediaSessionHelper.attached = false;
  }

  static get isAttached(): boolean {
    return MediaSessionHelper.attached;
  }
}
