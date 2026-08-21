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
 * 画面布局（contain 适配，修复视频宽高比问题）：
 * - 外层播放器容器固定尺寸（视频页 16:9 / 全屏页全屏），不跟随视频比例；
 * - XComponent（Surface）按视频宽高比在容器内居中 contain 显示：
 *   竖屏视频（如 9:16）在 16:9 容器内撑满高度、左右留大黑区；
 *   横屏视频（如 16:9）在 16:9 容器内恰好铺满。
 * - 宽高比经 Player 持久回调镜像到 @State videoRatio：加载期间获取到视频
 *   尺寸后画面会响应式更新（修复「UI 不响应宽高比、仅在某次无关 rebuild
 *   时顺带变化」的问题）。
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
  /** 视频宽高比（宽/高）镜像：未就绪时按 16:9 占位，就绪后随内核响应式更新 */
  @State videoRatio: number = 16 / 9;
  /** 播放器容器尺寸（vp）：onAreaChange 获取，用于计算 contain 布局 */
  @State boxW: number = 0;
  @State boxH: number = 0;
  /** Player 宽高比变化持久回调（aboutToDisappear 反注册，避免泄漏） */
  private ratioCb: ((aspect: number) => void) | null = null;

  aboutToAppear(): void {
    // 经 AppStorage 解析共享 Player：宽高比已就绪则直接取用，否则注册持久回调等待通知
    const player = AppStorage.get<Player>(PLAYER_KEY_PREFIX + this.playerId);
    if (player !== undefined) {
      if (player.aspectRatio > 0) {
        this.videoRatio = player.aspectRatio;
      }
      this.ratioCb = (aspect: number): void => {
        if (aspect > 0) {
          this.videoRatio = aspect;
        }
      };
      player.setAspectRatioListener(this.ratioCb);
    }
  }

  aboutToDisappear(): void {
    if (this.ratioCb !== null) {
      const player = AppStorage.get<Player>(PLAYER_KEY_PREFIX + this.playerId);
      if (player !== undefined) {
        player.setAspectRatioListener(null);
      }
      this.ratioCb = null;
    }
  }

  /**
   * contain 布局（宽度）：
   * - 容器尺寸未知前返回 '100%' 撑满，保证 Surface 创建与绑定；
   * - 容器尺寸与宽高比就绪后，按「视频比例 vs 容器比例」择一边撑满、另一边按比例收缩。
   */
  private videoW(): number | string {
    if (this.boxW <= 0 || this.boxH <= 0) {
      return '100%';
    }
    if (this.videoRatio >= this.boxW / this.boxH) {
      return this.boxW; // 视频较容器更宽（或等比）：撑满宽度，高度按比例
    }
    return this.boxH * this.videoRatio; // 视频较容器更高（如 9:16 竖屏）：高度撑满，宽度按比例 → 左右留黑边
  }

  /** contain 布局（高度），与 videoW() 配套 */
  private videoH(): number | string {
    if (this.boxW <= 0 || this.boxH <= 0) {
      return '100%';
    }
    if (this.videoRatio >= this.boxW / this.boxH) {
      return this.boxW / this.videoRatio;
    }
    return this.boxH;
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
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
        .width(this.videoW())
        .height(this.videoH())
        .backgroundColor(Color.Black)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
    .clip(true)
    // 容器尺寸变化（详情页 16:9 ↔ 全屏页全屏）时更新，驱动 contain 布局重算
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      const w = newArea.width as number;
      const h = newArea.height as number;
      if (w > 0 && h > 0 && (w !== this.boxW || h !== this.boxH)) {
        this.boxW = w;
        this.boxH = h;
      }
    })
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
