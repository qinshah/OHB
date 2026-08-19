// [API 23+] 视频渲染节点组件（节点迁移专用）
import { PlayerRepository } from '../repository/PlayerRepository';
import { Logger } from '../common/utils/Logger';

/**
 * 视频渲染节点组件
 *
 * 节点迁移专用：本组件由 VideoNodeController 持有的 BuilderNode 构建，
 * 在「视频详情页 ↔ 全屏页」之间迁移时组件实例不销毁，XComponent 的
 * Surface 持续有效，播放器无需换绑 Surface、无需 reset/prepare，
 * 实现全屏切换播放零中断（参考官方《横竖屏开发最佳实践》节点迁移方案）。
 *
 * 关键特性：onLoad 只会在 Surface 首次创建时触发一次（节点迁移不触发），
 * 这正是节点迁移的价值 —— Surface 永不变，AVPlayer 无感切换。
 */
@Component
export struct VideoPlayerNode {
  /** 播放器业务 id（bvid 等），用于从 PlayerRepository 获取共享 Player 实例 */
  @Prop playerId: string = '';
  private xcController: XComponentController = new XComponentController();

  build() {
    XComponent({
      // id 按播放器区分，保证多个详情页共存时各 Surface 标识唯一
      id: `video_surface_${this.playerId}`,
      type: XComponentType.SURFACE,
      controller: this.xcController
    })
      .onLoad(() => {
        // Surface 首次创建：绑定到共享播放器（此后跨页面迁移不再触发 onLoad）
        const player = PlayerRepository.get(this.playerId);
        if (player !== null) {
          player.bindSurface(this.xcController.getXComponentSurfaceId());
          Logger.info('VideoNode', `surface bound, playerId=${this.playerId}`);
        } else {
          Logger.error('VideoNode', `player not found, playerId=${this.playerId}`);
        }
      })
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Black)
  }
}

/**
 * 全局 Builder：VideoNodeController 的 BuilderNode 构建入口。
 * 参数为播放器 id（build 时一次性传入；id 变化需销毁节点重建）。
 */
@Builder
export function videoPlayerBuilder(playerId: string) {
  VideoPlayerNode({ playerId: playerId })
}
