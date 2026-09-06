// [API 23+] 弹幕设置面板（播放器控制栏「弹幕设置」按钮点击弹出 Dialog）
import { Pref } from '../services/storage/Pref';
import { AppColors } from '../theme/AppTheme';

/** 滑杆设置项标识（applySlider 分发用） */
enum DanmakuSliderKind {
  Opacity,
  FontScale,
  ShowArea,
  Duration,
  Weight
}

/**
 * 弹幕设置面板：不透明度 / 弹幕字号 / 显示区域 / 滚动速度 / 屏蔽等级 / 合并重复。
 *
 * 样式说明：使用 CustomDialog 默认样式（默认背景/内边距/圆角），本组件只提供内容；
 * 内容整体包裹在 Scroll 中（constraintSize 限高），条目多时可上下滚动。
 *
 * 数据流（本项目「设置直写 Pref」模式，无需组件间通信）：
 * - 滑杆拖动中（Begin/Moving）只更新本地 @State 镜像（刷新右侧数值文案）；
 *   松手/点击轨道（End/Click）时才 Pref.put 持久化——避免拖动期间每帧 flushSync 落盘
 * - 渲染层 DanmakuLayer 每 100ms tick 对比设置快照并热应用：
 *   不透明度/字号/速度/显示区域即时生效
 * - 「合并重复弹幕」在数据入桶时生效（DanmakuController.handleDanmaku），
 *   影响后续加载的弹幕段，对齐 PiliPlus 行为
 */
@Component
export struct DanmakuSettingsPanel {
  /** 关闭回调：父组件（PlayerControlView）恢复控制栏自动隐藏 */
  onClose: () => void = () => {
  };

  // ---- 本地镜像：从 Pref 初始化；拖动中更新文案，松手写回 Pref ----
  // 注意：字段名不能用 opacity——会与 CustomComponent 通用属性 opacity 冲突导致编译错误
  @State private danmakuOpacityValue: number = 1.0;
  @State private fontScale: number = 1.0;
  @State private showArea: number = 0.5;
  @State private duration: number = 7.0;
  @State private weight: number = 0;
  @State private merge: boolean = false;

  aboutToAppear(): void {
    this.danmakuOpacityValue = Pref.danmakuOpacity.get();
    this.fontScale = Pref.danmakuFontScale.get();
    this.showArea = Pref.danmakuShowArea.get();
    this.duration = Pref.danmakuDuration.get();
    this.weight = Pref.danmakuWeight.get();
    this.merge = Pref.danmakuMerge.get();
  }

  build() {
    Scroll(){
      Column({ space: 13 }) {
        // 标题行：弹幕设置 + 关闭按钮（遮罩/返回键也可关闭，见 CustomDialogController）
        Row() {
          Text($r('app.string.danmaku_settings_title'))
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TEXT_PRIMARY)
          Blank()
          Stack() {
            SymbolGlyph($r('sys.symbol.xmark'))
              .fontSize(14)
              .fontColor([AppColors.TEXT_SECONDARY])
          }
          .width(24)
          .height(24)
          .onClick(() => {
            this.onClose();
          })
        }
        .width('100%')
        // ---- 不透明度（0.1–1.0）：DanmakuLayer → ctx.setDanmakuTransparency ----
        this.SliderRow($r('app.string.danmaku_opacity'),
          `${Math.round(this.danmakuOpacityValue * 100)}%`,
          this.danmakuOpacityValue, 0.1, 1.0, 0.05,
          (value: number, mode: SliderChangeMode) => {
            this.applySlider(value, mode, DanmakuSliderKind.Opacity);
          })

        // ---- 弹幕字号缩放（0.5–2.0）：DanmakuLayer → ctx.setScaleTextSize ----
        this.SliderRow($r('app.string.danmaku_font_scale'),
          `${this.fontScale.toFixed(1)}×`,
          this.fontScale, 0.5, 2.0, 0.1,
          (value: number, mode: SliderChangeMode) => {
            this.applySlider(value, mode, DanmakuSliderKind.FontScale);
          })

        // ---- 显示区域（0.25–1.0，占播放区高度比例）：DanmakuLayer 高度重排 ----
        this.SliderRow($r('app.string.danmaku_show_area'),
          `${Math.round(this.showArea * 100)}%`,
          this.showArea, 0.25, 1.0, 0.05,
          (value: number, mode: SliderChangeMode) => {
            this.applySlider(value, mode, DanmakuSliderKind.ShowArea);
          })

        // ---- 滚动速度（3–15s，越小越快）：DanmakuLayer → ctx.setScrollSpeedFactor ----
        this.SliderRow($r('app.string.danmaku_duration'),
          `${this.duration.toFixed(1)}s`,
          this.duration, 3, 15, 0.5,
          (value: number, mode: SliderChangeMode) => {
            this.applySlider(value, mode, DanmakuSliderKind.Duration);
          })

        // ---- 屏蔽等级（0–10，越大屏蔽越多）：DanmakuLayer.addOne 权重过滤 ----
        this.SliderRow($r('app.string.danmaku_weight'),
          `${Math.round(this.weight)}`,
          this.weight, 0, 10, 1,
          (value: number, mode: SliderChangeMode) => {
            this.applySlider(value, mode, DanmakuSliderKind.Weight);
          })

        // ---- 合并重复弹幕（开关）：DanmakuController.handleDanmaku 入桶时合并 ----
        Row() {
          Text($r('app.string.danmaku_merge'))
            .fontSize(14)
            .fontColor(AppColors.TEXT_PRIMARY)
          Blank()
          Toggle({ type: ToggleType.Switch, isOn: this.merge })
            .selectedColor(AppColors.BRAND)
            .onChange((on: boolean) => {
              this.merge = on;
              Pref.danmakuMerge.put(on);
            })
        }
        .width('100%')
      }
      .width('100%')
    }
    .padding(30)
    .scrollBar(BarState.Off)
  }

  /** 滑杆设置行：标签 + 当前值 + Slider（统一样式，减少重复代码） */
  @Builder
  private SliderRow(label: Resource, valueText: string, value: number, min: number, max: number,
    step: number, onChange: (value: number, mode: SliderChangeMode) => void) {
    Column({ space: 2 }) {
      Row() {
        Text(label)
          .fontSize(14)
          .fontColor(AppColors.TEXT_PRIMARY)
        Blank()
        Text(valueText)
          .fontSize(12)
          .fontColor(AppColors.TEXT_SECONDARY)
      }
      .width('100%')

      Slider({ value: value, min: min, max: max, step: step })
        .width('100%')
        .selectedColor(AppColors.BRAND)
        .onChange((v: number, mode: SliderChangeMode) => {
          onChange(v, mode);
        })
    }
    .width('100%')
  }

  /**
   * 滑杆变更分发（kind 区分设置项）：
   * - Begin/Moving：仅更新镜像（刷新数值文案，不落盘）
   * - End/Click：更新镜像 + Pref.put（渲染层下个 tick 热应用）
   */
  private applySlider(value: number, mode: SliderChangeMode, kind: DanmakuSliderKind): void {
    const commit: boolean = mode === SliderChangeMode.End || mode === SliderChangeMode.Click;
    switch (kind) {
      case DanmakuSliderKind.Opacity:
        this.danmakuOpacityValue = value;
        if (commit) {
          Pref.danmakuOpacity.put(value);
        }
        break;
      case DanmakuSliderKind.FontScale:
        this.fontScale = value;
        if (commit) {
          Pref.danmakuFontScale.put(value);
        }
        break;
      case DanmakuSliderKind.ShowArea:
        this.showArea = value;
        if (commit) {
          Pref.danmakuShowArea.put(value);
        }
        break;
      case DanmakuSliderKind.Duration:
        this.duration = value;
        if (commit) {
          Pref.danmakuDuration.put(value);
        }
        break;
      case DanmakuSliderKind.Weight:
        this.weight = value;
        if (commit) {
          Pref.danmakuWeight.put(value);
        }
        break;
      default:
        break;
    }
  }
}

/**
 * 弹幕设置弹窗（@CustomDialog 包装 DanmakuSettingsPanel）：
 * - 使用默认 Dialog 样式（不传 customStyle），背景/圆角/内边距由系统提供
 * - 面板右上角 X → controller.close() + onDismissed 回调；
 *   点击遮罩/返回键关闭 → 走 CustomDialogController 的 cancel 回调（由父组件统一处理）
 */
@CustomDialog
export struct DanmakuSettingsDialog {
  controller?: CustomDialogController;
  /** 弹窗关闭回调：父组件恢复控制栏自动隐藏 */
  onDismissed: () => void = () => {
  };

  build() {
    DanmakuSettingsPanel({
      onClose: () => {
        this.controller?.close();
        this.onDismissed();
      }
    })
  }
}
