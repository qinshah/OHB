// [API 23+] 弹幕渲染层（对齐 PiliPlus PlDanmaku 的驱动模型）
import { DanmakuView, DanmakuContext, BaseDanmaku, BaseDanmakuParser, DANMAKU_STYLE_STROKEN,
  Danmakus, IDanmakus, ST_BY_TIME, Callback, RenderMode, Duration, DanmakuTimer }
  from '@ohos/danmakuflamemaster';
import { Player } from '../player/Player';
import { PlayerRepository } from '../repository/PlayerRepository';
import { PlaybackState } from '../player/PlayerTypes';
import { DanmakuItem } from '../models/DanmakuModels';
import { DanmakuController, DanmakuControllerManager } from '../services/danmaku/DanmakuController';
import { Pref } from '../services/storage/Pref';
import { hilog } from '@kit.PerformanceAnalysisKit';

/** DFM 滚动弹幕基准存活时长（DanmakuFactory.COMMON_DANMAKU_DURATION，ms） */
const DFM_BASE_DURATION_MS: number = 3800;
/** 顶部/底部固定弹幕存活时长（对齐 PiliPlus danmakuStaticDuration 默认 4s，ms） */
const STATIC_DURATION_MS: number = 4000;
/** tick 间隔：与 0.1s 分桶粒度一致（PiliPlus videoPositionListen 同节奏） */
const TICK_INTERVAL_MS: number = 100;

/**
 * Danmakus 构造参数。
 * 库内部 Args 类未从 index 导出，此处定义结构一致的本地类后经 ESObject 透传
 * （官方 DemoV1 的 BiliDanmukuParser 同样采用该写法）。
 */
class EmptyParserArgs {
  sortType: number = ST_BY_TIME;
  duplicateMergingEnabled: boolean = false;
}

/**
 * 空数据源解析器：本层采用「动态 addDanmaku」模式（播放进度驱动逐条添加），
 * 初始时间轴为空，parse() 返回空集合即可满足 prepare() 的非空 parser 要求。
 */
class EmptyDanmakuParser extends BaseDanmakuParser {
  protected parse(): IDanmakus {
    return new Danmakus(new EmptyParserArgs() as ESObject);
  }
}

/**
 * prepare 完成回调（ArkTS 不允许对象字面量实现含方法接口，需具名类）。
 * prepared 时启动 DFM 内部时钟（驱动滚动动画）。
 */
class DanmakuLayerCallback implements Callback {
  private readonly onPrepared: () => void;

  constructor(onPrepared: () => void) {
    this.onPrepared = onPrepared;
  }

  prepared(): void {
    this.onPrepared();
  }

  updateTimer(timer: DanmakuTimer): void {
  }

  danmakuShown(danmaku: BaseDanmaku): void {
  }

  drawingFinished(): void {
  }
}

/**
 * 弹幕渲染层：透明 Canvas 叠加在视频画面之上。
 *
 * 驱动模型（对齐 PiliPlus lib/pages/danmaku/view.dart）：
 * - 每 100ms tick 读取播放器进度 → 取当前 0.1s 分桶弹幕 → 逐条 addDanmaku
 * - 暂停/恢复 → model.pause()/resume()；弹幕开关 → model.hide()/show()
 * - seek 不清屏（旧弹幕自然滚出，新位置弹幕即刻接管，与 PiliPlus 行为一致）
 * - cid 变化（切分P/换视频）→ 清屏 + 换 DanmakuController（数据按 cid 共享缓存）
 *
 * 双层实例：详情页与全屏页各持一个 DanmakuLayer（独立 Model），共享同一份
 * 分桶数据（DanmakuControllerManager）；详情页实例传 pauseWhenFullscreen=true，
 * 进入全屏时暂停渲染，避免两层同时弹。
 *
 * 尺寸说明：显示区域设置（danmakuShowArea）通过本组件高度（占父容器比例）实现，
 * onAreaChange 中同步 model 宽高（px）——DFM 内部以 px 计算布局/滚动轨迹。
 */
@Component
export struct DanmakuLayer {
  /** 播放器业务 id（bvid），经 PlayerRepository.get(id) 获取共享 Player */
  @Prop playerId: string = '';
  /** 详情页实例传 true：进入全屏时本层暂停（全屏页另有一层） */
  pauseWhenFullscreen: boolean = false;
  /** DFM 视图模型（纯代理，delegate 由 DanmakuView aboutToAppear 挂载） */
  @State model: DanmakuView.Model = new DanmakuView.Model();
  /** 显示区域：本层高度占父容器（播放区）的比例，0.25–1.0 */
  @State private areaRatio: number = 0.5;

  private playerVM: Player | null = null;
  private ctx: DanmakuContext | null = null;
  private controller: DanmakuController | null = null;
  /** 当前数据源 cid（tick 中与 player.danmakuCid 对比，变化则重置） */
  private currentCid: number = 0;
  /** 上一个已消费的 0.1s 桶号（同桶去重，防止重复添加） */
  private lastBucket: number = -1;
  private tickTimer: number = -1;
  /** prepare 完成（DFM 时钟可 start、addDanmaku 可用） */
  private prepared: boolean = false;
  /** model 尺寸已初始化（onAreaChange 首帧后置 true） */
  private sized: boolean = false;
  /** 上次可见状态（开关镜像，变化时才调 show/hide） */
  private visible: boolean = true;
  /** 像素密度（textSize 需 px 单位，缓存 vp2px(1)） */
  private pxPerVp: number = 3;
  // ---- 设置快照（tick 对比，变化才热应用，避免每帧重配置） ----
  private lastOpacity: number = -1;
  private lastFontScale: number = -1;
  private lastDurationSec: number = -1;
  private lastSpeed: number = -1;

  aboutToAppear(): void {
    this.playerVM = PlayerRepository.get(this.playerId);
    this.areaRatio = Pref.danmakuShowArea.get();
    // 注意：DanmakuContext 必须在 DanmakuView 挂载后创建（首帧 onAreaChange 中）——
    // 库内部 OhosDisplayer 依赖 GlobalContext 中的 uiContext 计算像素密度，
    // 该值由 DanmakuView 的 aboutToAppear 写入；过早创建会导致 density=1、字号异常。
    this.model.setMode(RenderMode.CANVAS_2D);
    this.model.setCallback(new DanmakuLayerCallback((): void => {
      this.prepared = true;
      this.model.start();
      hilog.info(0x0000, TAG, 'prepared playerId=%{public}s', this.playerId);
    }));
    this.startTick();
  }

  aboutToDisappear(): void {
    if (this.tickTimer >= 0) {
      clearInterval(this.tickTimer);
      this.tickTimer = -1;
    }
    // 视图自身的 aboutToDisappear 会做 delegate 清理（停止动画/销毁后端），此处不重复 release
    this.playerVM = null;
    this.controller = null;
    this.ctx = null;
  }

  build() {
    Stack() {
      DanmakuView({ model: this.model })
    }
    .width('100%')
    // 显示区域设置：弹幕只占用播放区上部 areaRatio 比例（顶部对齐 Stack 默认布局）
    .height(`${Math.round(this.areaRatio * 100)}%`)
    .clip(true)
    // 不拦截触摸：手势/控制层在上方兄弟节点，本层须透传触摸给下层
    .hitTestBehavior(HitTestMode.None)
    .onAreaChange((_old: Area, newArea: Area) => {
      const w: number = Math.round(newArea.width as number);
      const h: number = Math.round(newArea.height as number);
      if (w <= 0 || h <= 0) {
        return;
      }
      // vp → px：DFM 内部布局/滚动轨迹均以 px 计算
      this.pxPerVp = this.getUIContext().vp2px(1);
      this.model.setWidth(Math.round(w * this.pxPerVp));
      this.model.setHeight(Math.round(h * this.pxPerVp));
      if (!this.sized) {
        this.sized = true;
        this.prepareView();
      }
    })
  }

  /**
   * 初始化 DFM：建 Context（此时视图已挂载，密度正确）→ 链式配置 → prepare。
   * prepared 回调中 start() 启动内部时钟；此后 addDanmaku 动态添加。
   */
  private prepareView(): void {
    this.ctx = DanmakuContext.create();
    const maxLines: Map<number, number> = new Map<number, number>();
    maxLines.set(BaseDanmaku.TYPE_SCROLL_RL, 10); // 滚动弹幕最多 10 行
    maxLines.set(BaseDanmaku.TYPE_FIX_TOP, 2);    // 顶部固定最多 2 行
    maxLines.set(BaseDanmaku.TYPE_FIX_BOTTOM, 2); // 底部固定最多 2 行
    const overlapping: Map<number, boolean> = new Map<number, boolean>();
    overlapping.set(BaseDanmaku.TYPE_SCROLL_RL, true);
    overlapping.set(BaseDanmaku.TYPE_FIX_TOP, true);
    overlapping.set(BaseDanmaku.TYPE_FIX_BOTTOM, true);
    this.ctx
      .setDanmakuStyle(DANMAKU_STYLE_STROKEN, 3) // 黑色描边宽度（px），保证浅色弹幕在视频上可读
      .setDuplicateMergingEnabled(false)
      .setScrollSpeedFactor(1.0)
      .setScaleTextSize(1.0)
      .setMaximumLines(maxLines)
      .preventOverlapping(overlapping)
      .setDanmakuMargin(4);
    const parser: BaseDanmakuParser = new EmptyDanmakuParser();
    this.model.prepare(parser, this.ctx);
    hilog.info(0x0000, TAG, 'prepare playerId=%{public}s area=%{public}f', this.playerId, this.areaRatio);
  }

  private startTick(): void {
    if (this.tickTimer >= 0) {
      return;
    }
    this.tickTimer = setInterval((): void => {
      this.tick();
    }, TICK_INTERVAL_MS);
  }

  /**
   * 100ms tick：状态同步 + 位置驱动（对齐 PiliPlus videoPositionListen）。
   * 顺序：cid 变化检测 → 开关 → 全屏互斥 → 播放状态 → 设置热应用 → 分桶取弹幕。
   */
  private tick(): void {
    if (!this.prepared || this.model === null) {
      return;
    }
    if (this.playerVM === null) {
      // 页面栈顺序兜底：aboutToAppear 时仓库可能尚未登记（正常情况下不会发生）
      this.playerVM = PlayerRepository.get(this.playerId);
      if (this.playerVM === null) {
        return;
      }
    }
    const player: Player = this.playerVM;

    // 1. cid 变化（切分P/换视频）→ 清屏 + 切换数据控制器
    if (player.danmakuCid !== this.currentCid) {
      this.currentCid = player.danmakuCid;
      this.controller = this.currentCid > 0 ? DanmakuControllerManager.get(this.currentCid) : null;
      this.lastBucket = -1;
      this.model.clearDanmakusOnScreen();
      hilog.info(0x0000, TAG, 'switch cid=%{public}d playerId=%{public}s', this.currentCid, this.playerId);
    }
    if (this.currentCid <= 0 || this.controller === null) {
      return;
    }

    // 2. 弹幕开关（player.danmakuEnabled 由控制栏按钮维护并持久化到 Pref）
    if (player.danmakuEnabled !== this.visible) {
      this.visible = player.danmakuEnabled;
      if (this.visible) {
        this.model.show();
      } else {
        this.model.hide();
      }
    }
    if (!this.visible) {
      return;
    }

    // 3. 全屏互斥：详情页实例在全屏期间暂停（全屏页另有独立渲染层）
    if (this.pauseWhenFullscreen && player.fullscreen) {
      if (!this.model.isPaused()) {
        this.model.pause();
      }
      return;
    }

    // 4. 播放状态：播放中走表，暂停冻结（DFM 内部时钟暂停，弹幕停住）
    if (player.state === PlaybackState.Playing) {
      if (this.model.isPaused()) {
        this.model.resume();
      }
    } else {
      if (!this.model.isPaused()) {
        this.model.pause();
      }
      return;
    }

    // 5. 设置热应用（对比快照，变化才下发，避免重复触发全局重测量）
    this.applySettings(player);

    // 6. 位置驱动：同步真实进度 → 取当前 0.1s 桶 → 逐条添加
    player.syncProgress(); // 直接查询内核进度，保证 100ms 粒度（onProgress 事件密度不足）
    const pos: number = player.positionMs;
    const bucket: number = DanmakuController.calcBucket(pos);
    if (bucket === this.lastBucket) {
      return;
    }
    this.lastBucket = bucket;
    const list: DanmakuItem[] | null = this.controller.getCurrentDanmaku(pos);
    if (list === null) {
      return; // 所在段尚未加载完成（已异步触发请求），下个 tick 再取
    }
    const speed: number = player.speed > 0 ? player.speed : 1;
    for (let i = 0; i < list.length; i++) {
      this.addOne(list[i], speed);
    }
  }

  /** 设置热应用：不透明度/字号缩放/滚动速度（含倍速补偿）/显示区域 */
  private applySettings(player: Player): void {
    if (this.ctx === null) {
      return;
    }
    const opacity: number = Pref.danmakuOpacity.get();
    if (opacity !== this.lastOpacity) {
      this.lastOpacity = opacity;
      this.ctx.setDanmakuTransparency(opacity);
    }
    const fontScale: number = Pref.danmakuFontScale.get();
    if (fontScale !== this.lastFontScale) {
      this.lastFontScale = fontScale;
      this.ctx.setScaleTextSize(fontScale);
    }
    const durationSec: number = Pref.danmakuDuration.get();
    const speed: number = player.speed > 0 ? player.speed : 1;
    if (durationSec !== this.lastDurationSec || speed !== this.lastSpeed) {
      this.lastDurationSec = durationSec;
      this.lastSpeed = speed;
      // DFM 基准 ~3.8s：factor = 基准/期望时长；倍速放大 factor 使弹幕随播放速率加快
      const factor: number = DFM_BASE_DURATION_MS / (durationSec * 1000) * speed;
      this.ctx.setScrollSpeedFactor(factor);
    }
    const area: number = Pref.danmakuShowArea.get();
    if (area !== this.areaRatio) {
      this.areaRatio = area; // @State → 高度重排 → onAreaChange 同步 model 高度
    }
  }

  /**
   * 单条弹幕 → DFM 对象并添加（对齐 PiliPlus addDanmaku 的参数映射）：
   * - mode 4 → 底部固定、5 → 顶部固定、其余 → 右→左滚动（mode 7 已在数据层过滤）
   * - 字号：B站 fontsize(18/25/36) 归一到 15vp 基准（fontsize/25*15），px 单位；
   *   字号缩放（fontScale）由 ctx.setScaleTextSize 全局应用，此处不重复乘
   * - 颜色：十进制 RGB → 0xFFRRGGBB；描边黑色（textShadowColor）
   * - isLive=true：立即参与渲染（官方 Demo 动态添加同款用法）
   * - 顶部/底部固定弹幕按倍速缩短存活时长（视频时间 4s 对应墙钟 4s/speed）
   */
  private addOne(item: DanmakuItem, speed: number): void {
    if (this.ctx === null) {
      return;
    }
    // 屏蔽等级：权重低于设置值的弹幕不显示（PiliPlus danmakuWeight 语义）
    if (item.weight < Pref.danmakuWeight.get()) {
      return;
    }
    let type: number = BaseDanmaku.TYPE_SCROLL_RL;
    if (item.mode === 4) {
      type = BaseDanmaku.TYPE_FIX_BOTTOM;
    } else if (item.mode === 5) {
      type = BaseDanmaku.TYPE_FIX_TOP;
    }
    const d: BaseDanmaku | null = this.ctx.mDanmakuFactory.createDanmakuByContext(type, this.ctx);
    if (d === null) {
      return;
    }
    d.text = item.count > 1 ? `${item.content} ×${item.count}` : item.content;
    d.textSize = item.fontsize / 25 * 15 * this.pxPerVp;
    d.textColor = 0xFF000000 | item.color;
    d.textShadowColor = 0xFF000000; // 黑色描边（DFM 以 shadow 色作描边色）
    d.padding = 5;
    d.priority = 0; // 保持 0：非 0 时会绕过过滤器统计（官方 Demo 注释要求）
    d.isLive = true;
    d.setTime(this.model.getCurrentTime());
    if (type !== BaseDanmaku.TYPE_SCROLL_RL) {
      d.duration = new Duration(Math.round(STATIC_DURATION_MS / speed));
    }
    this.model.addDanmaku(d);
  }
}

// 日志 TAG（规范：统一定义在文件最下方）
const TAG = DanmakuLayer.name ?? 'DanmakuLayer';
