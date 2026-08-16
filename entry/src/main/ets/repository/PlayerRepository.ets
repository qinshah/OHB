// [API 23+] 播放器仓库
import { Player } from '../player/Player';
import { Logger } from '../common/utils/Logger';

/**
 * 播放器仓库（静态单例）
 *
 * 统一管理所有 Player 实例（PlayerMap），替代在父子组件之间通过 @Prop/@Provide、
 * 路由参数等方式直接传递 Player 实例：
 * - 需要新建播放器的页面调用 create(id)，仓库负责创建并登记
 * - 需要复用同一播放器的 view/子页面（如 PlayerControlView、VideoFullscreenPage）
 *   通过 get(id) 获取，使用相同播放器的页面以业务 id（bvid / roomId / seasonId 等）建立联系
 * - 构造函数私有，全局仅一个实例
 */
export class PlayerRepository {
  /** id → Player 实例 */
  private static  map: Map<string, Player> = new Map<string, Player>();

  private constructor() {
  }

  /**
   * 创建并登记播放器；该 id 已存在时直接返回现有实例（避免重复创建）。
   * 新建 Player 的地方（详情页/直播间/番剧页）都通过此方法创建。
   */
 static   create(id: string): Player {
    let p = PlayerRepository.map.get(id);
    if (p === undefined) {
      p = new Player(id);
      PlayerRepository.map.set(id, p);
      Logger.info('PlayerRepo', `create id=${id}, total=${PlayerRepository.map.size}`);
    }
    return p;
  }

  /**
   * 获取已登记的播放器；未登记返回 null。
   * view / 子页面（PlayerControlView、VideoFullscreenPage）通过此方法获取共享实例。
   */
  static  get(id: string): Player | null {
    const p = PlayerRepository.map.get(id);
    return p === undefined ? null : p;
  }

  /** 是否存在指定 id 的播放器 */
  static  has(id: string): boolean {
    return PlayerRepository.map.has(id);
  }

  /** 移除并释放指定播放器（页面销毁时调用） */
  static  async remove(id: string): Promise<void> {
    const p = PlayerRepository.map.get(id);
    if (p !== undefined) {
      PlayerRepository.map.delete(id);
      await p.release();
      Logger.info('PlayerRepo', `remove id=${id}, total=${PlayerRepository.map.size}`);
    }
  }

  /** 释放全部播放器（应用退出等场景） */
  static  async releaseAll(): Promise<void> {
    const keys: string[] = [];
    PlayerRepository.map.forEach((_p: Player, id: string) => {
      keys.push(id);
    });
    for (let i = 0; i < keys.length; i++) {
      const p = PlayerRepository.map.get(keys[i]);
      if (p !== undefined) {
        PlayerRepository.map.delete(keys[i]);
        await p.release();
      }
    }
    Logger.info('PlayerRepo', 'releaseAll done');
  }
}
