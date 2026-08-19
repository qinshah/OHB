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
 * Surface 绑定不在本类（早期方案曾用中介注册表，实测 @Component 编译单元
 * 与普通文件间 static Map 模块双实例、注册与查询读到不同副本而失效）：
 * 组件 onLoad 直接经 AppStorage 解析 Player 引用并绑定（见 VideoPlayerNode）。
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
  /** 全局 Builder 包装（构建视频组件树；参数为 playerId 字符串） */
  private wrapBuilder: WrappedBuilder<[string]> = wrapBuilder(videoPlayerBuilder);
  /** 迁移遮蔽标志：true 时 makeNode 返回 null（节点从宿主页面移除） */
  private hidden: boolean = false;
  /** makeNode 调用序号（日志观测多容器竞争时序用） */
  private nodeSeq: number = 0;
  /** 已销毁标志：dispose 后 makeNode 不再重建节点（防止容器销毁触发的 rebuild 造成 BuilderNode 泄漏） */
  private disposed: boolean = false;

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
    // 已销毁的实例不可复用（disposed 后 makeNode 恒为 null）——重建新实例
    if (c === undefined || c.disposed) {
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
    this.nodeSeq++;
    Logger.info('VideoNode',
      `makeNode#${this.nodeSeq} id=${this.playerId}, hidden=${this.hidden}, disposed=${this.disposed}`);
    if (this.disposed) {
      return null; // 已销毁：不再重建（防容器销毁触发的 rebuild 泄漏 BuilderNode）
    }
    if (this.hidden) {
      return null; // 迁移清空期：不提供节点
    }
    if (this.rootNode === null) {
      this.rootNode = new BuilderNode<[string]>(uiContext);
      // 参数只传 playerId 字符串：对象参数经实测会丢失（官方 Sample 也用简单类型）
      this.rootNode.build(this.wrapBuilder, [this.playerId]);
    }
    return this.rootNode.getFrameNode();
  }

  // ---------- 框架回调（NodeContainer 生命周期） ----------

  /** NodeContainer 挂载显示后回调 */
  aboutToAppear(): void {
    Logger.info('VideoNode', `container aboutToAppear id=${this.playerId}`);
  }

  /**
   * NodeContainer 销毁时回调（仅日志观测，不做节点操作）。
   * 实测此回调触发时垂死容器可能仍参与 makeNode 竞争（抢走节点），
   * 节点归还必须等页面完全销毁后经 requestRestore 执行（见下）。
   */
  aboutToDisappear(): void {
    Logger.info('VideoNode', `container aboutToDisappear id=${this.playerId}`);
  }

  // ---------- 节点归还（全屏页完全销毁后调用） ----------

  /** 详情页注册的容器重建回调（containerSeq++ 触发 NodeContainer 重建挂载） */
  private restoreListener: (() => void) | null = null;

  /** 注册/注销详情页的容器重建回调 */
  setRestoreListener(cb: (() => void) | null): void {
    this.restoreListener = cb;
  }

  /**
   * 归还节点给详情页——在全屏页 NavDestination.onDisAppear（页面完全销毁）
   * 时调用。日志实测：此前在容器销毁回调里 rebuild，垂死容器会抢先响应
   * makeNode 把节点抢走，详情页容器实际没拿到节点（游离态）→ 黑屏；
   * 再进全屏时新容器取走游离节点 → 画面正常（且 onLoad 不触发，
   * 证明 Surface 全程存活）。
   *
   * 双保险归还：
   * 1. rebuild()：若详情页容器仍绑定，通知其重新 makeNode 取回节点
   * 2. restoreListener：通知详情页重建 NodeContainer（ForEach key 技术），
   *    新容器 makeNode 从游离态取回节点——覆盖详情页容器已解绑的场景
   */
  requestRestore(): void {
    Logger.info('VideoNode', `requestRestore id=${this.playerId}`);
    this.hidden = false;
    this.rebuild();
    if (this.restoreListener !== null) {
      this.restoreListener();
    }
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

  /** 销毁节点实体（详情页彻底关闭时调用；全屏切换过程禁止调用） */
  dispose(): void {
    this.disposed = true;
    if (this.rootNode !== null) {
      this.rootNode.dispose();
      this.rootNode = null;
    }
  }
}
