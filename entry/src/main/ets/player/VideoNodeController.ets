// [API 23+] 视频节点迁移控制器
import { BuilderNode, NodeController } from '@kit.ArkUI';
import { Logger } from '../common/utils/Logger';
import { videoPlayerBuilder } from './VideoPlayerNode';

/**
 * 视频节点迁移控制器（参考官方《横竖屏开发最佳实践》节点迁移方案）
 *
 * 作用：让同一个 XComponent 渲染节点（含 Surface）在
 * 「视频详情页 ↔ 全屏页」之间迁移，而不销毁重建：
 * - XComponent 实例全程存活 → Surface 持续有效
 * - AVPlayer 无需换绑 Surface、无需 reset/prepare → 播放零中断
 *
 * 多实例设计：按播放器 id（bvid）管理。多个视频详情页可在路由栈中共存，
 * 各自持有独立节点互不干扰（区别于官方 Sample 的全局单例，
 * 适配本项目 PlayerRepository 多播放器共存架构）。
 *
 * 迁移时序：
 * - 进全屏：详情页 hideFromCurrentHost()（清空详情页节点，防转场穿帮）
 *   → 全屏页 NodeContainer 创建 → makeNode 返回同一节点 → 自动迁移挂载
 * - 退全屏：全屏页销毁 → restoreToHost() 触发 rebuild
 *   → 详情页 NodeContainer 重新 makeNode → 节点挂回详情页
 */
export class VideoNodeController extends NodeController {
  /** 播放器业务 id（节点与播放器一一对应） */
  readonly playerId: string;
  /** BuilderNode 持有的视频组件树根节点（跨页面迁移的实体，永不轻易销毁） */
  private rootNode: BuilderNode<[string]> | null = null;
  /** 全局 Builder 包装（构建视频组件树） */
  private wrapBuilder: WrappedBuilder<[string]> = wrapBuilder(videoPlayerBuilder);
  /** 迁移遮蔽标志：true 时 makeNode 返回 null（节点从宿主页面移除） */
  private hidden: boolean = false;

  private constructor(playerId: string) {
    super();
    this.playerId = playerId;
  }

  // ---------- 实例管理（按 playerId，多详情页共存时各自独立） ----------

  /** id → 控制器实例 */
  private static instances: Map<string, VideoNodeController> = new Map<string, VideoNodeController>();

  /** 获取/创建指定播放器 id 的节点控制器 */
  static get(playerId: string): VideoNodeController {
    let c = VideoNodeController.instances.get(playerId);
    if (c === undefined) {
      c = new VideoNodeController(playerId);
      VideoNodeController.instances.set(playerId, c);
      Logger.info('VideoNode', `create controller id=${playerId}, total=${VideoNodeController.instances.size}`);
    }
    return c;
  }

  /** 销毁并移除控制器（详情页彻底关闭时调用；全屏切换过程禁止调用） */
  static remove(playerId: string): void {
    const c = VideoNodeController.instances.get(playerId);
    if (c !== undefined) {
      c.dispose();
      VideoNodeController.instances.delete(playerId);
      Logger.info('VideoNode', `remove controller id=${playerId}, total=${VideoNodeController.instances.size}`);
    }
  }

  // ---------- NodeController 实现 ----------

  /**
   * NodeContainer 挂载时回调：返回视频组件树实体节点。
   * 同一 FrameNode 被新的 NodeContainer 获取时会自动从旧容器迁移挂载，
   * 这是节点迁移的核心机制。
   */
  makeNode(uiContext: UIContext): FrameNode | null {
    if (this.hidden) {
      return null; // 迁移清空期：不提供节点
    }
    if (this.rootNode === null) {
      this.rootNode = new BuilderNode<[string]>(uiContext);
      this.rootNode.build(this.wrapBuilder, [this.playerId]);
    }
    return this.rootNode.getFrameNode();
  }

  // ---------- 迁移控制 ----------

  /**
   * 从当前宿主页面移除节点（进入全屏跳转前调用）。
   * 触发 rebuild 使宿主 NodeContainer 重新 makeNode 并拿到 null，
   * 详情页视频区即时清空，避免转场动画期间「双视频」穿帮。
   */
  hideFromCurrentHost(): void {
    this.hidden = true;
    this.rebuild();
    // 立即恢复：等待全屏页 NodeContainer 创建时经 makeNode 取走节点
    this.hidden = false;
  }

  /**
   * 将节点归还宿主页面（全屏页销毁时调用；详情页 onShown 可兜底重复调用）。
   * 触发 rebuild 使详情页 NodeContainer 重新 makeNode 取回节点。
   * 幂等：节点已挂载时重复调用无副作用。
   */
  restoreToHost(): void {
    this.hidden = false;
    this.rebuild();
  }

  /** 销毁节点实体（详情页彻底关闭时调用；全屏切换过程禁止调用） */
  dispose(): void {
    if (this.rootNode !== null) {
      this.rootNode.dispose();
      this.rootNode = null;
    }
  }
}
