// [API 23+] 视频渲染节点组件（节点迁移专用）
import { Logger } from '../common/utils/Logger';
import { Player } from './Player';

/**
 * AppStorage 中 Player 引用的 key 前缀（与 VideoDetailVM.playerKeyOf 保持一致）。
 * 注意：两个文件各自定义相同字面量——@Component 编译单元存在模块双实例问题，
 * 共享模块里的常量不可靠，但字符串字面量值恒等。
 */
const PLAYER_KEY_PREFIX = '__ohb_vplayer_';

/**
 * 视频渲染节点组件
 *
 * 节点迁移专用：本组件由 VideoNodeController 持有的 BuilderNode 构建，
 * 在「视频详情页 ↔ 全屏页」之间迁移时组件实例不销毁，XComponent 的
 * Surface 持续有效，播放器无需换绑 Surface、无需 reset/prepare，
 * 实现全屏切换播放零中断（参考官方《横竖屏开发最佳实践》节点迁移方案）。
 *
 * Surface 绑定（历经三次踩坑的最终方案）：
 * - 坑1：BuilderNode.build() 传对象参数会丢失 → 只传 playerId 字符串
 * - 坑2：struct 成员上的 ?.() 可选链调用在空值时抛 TypeError 崩溃 → 显式判空
 * - 坑3：自定义 static Map 注册表在 @Component 编译单元与普通文件间
 *   存在模块双实例（注册写 A 副本、查询读 B 副本）→ 改用 AppStorage
 *   （框架级全局单例，跨模块绝对共享）传递 Player 引用
 * - 时序保障：attachPlayer（发布 Player）在页面 aboutToAppear 同步执行，
 *   必然早于 XComponent onLoad，绑定永不为空
 */
@Component
export struct VideoPlayerNode {
  /** 播放器业务 id（bvid 等）；由 builder 以 string 参数传入 */
  playerId: string = '';
  private xcController: XComponentController = new XComponentController();

  build() {
    XComponent({
      // id 按播放器区分，保证多个详情页共存时各 Surface 标识唯一
      id: `video_surface_${this.playerId}`,
      type: XComponentType.SURFACE,
      controller: this.xcController
    })
      .onLoad(() => {
        const surfaceId = this.xcController.getXComponentSurfaceId();
        Logger.info('VideoNode', `onLoad playerId=${this.playerId}, surfaceId=${surfaceId}`);
        // 经 AppStorage 解析共享 Player（引用传递，跨模块同一实例）
        const player = AppStorage.get<Player>(PLAYER_KEY_PREFIX + this.playerId);
        if (player !== undefined) {
          player.bindSurface(surfaceId);
          Logger.info('VideoNode', `surface bound via AppStorage, id=${this.playerId}`);
        } else {
          Logger.error('VideoNode', `player not in AppStorage, id=${this.playerId}`);
        }
      })
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Black)
  }
}

/**
 * 全局 Builder：VideoNodeController 的 BuilderNode 构建入口。
 * 参数为 playerId 字符串（简单类型传递可靠；对象参数实测会丢失）。
 */
@Builder
export function videoPlayerBuilder(playerId: string) {
  VideoPlayerNode({ playerId: playerId })
}
