// [API 23+] 弹幕设置面板（播放器控制栏「弹幕」按钮长按唤起）
import { Pref } from '../services/storage/Pref';

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
  /** 关闭回调：父组件（PlayerControlView）隐藏面板并恢复控制栏自动隐藏 */
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
    Column({ space: 13 }) {
      // 标题行：弹幕设置 + 关闭按钮
      Row() {
        Text($r('app.string.danmaku_settings_title'))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
        Blank()
        Stack() {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(14)
            .fontColor([Color.White])
        }
        .width(24)
        .height(24)
        .onClick(() => {
          this.onClose();
        })
      }
      .width('100%')

      // ---- 不透明度（0.1–1.0）：DanmakuLayer → ctx.setDanmakuTransparency ----
      Column({ space: 2 }) {
        Row() {
          Text($r('app.string.danmaku_opacity'))
            .fontSize(12)
            .fontColor('#E6FFFFFF')
          Blank()
          Text(`${Math.round(this.danmakuOpacityValue * 100)}%`)
            .fontSize(12)
            .fontColor('#99FFFFFF')
        }
        .width('100%')

        Slider({ value: this.danmakuOpacityValue, min: 0.1, max: 1.0, step: 0.05 })
          .width('100%')
          .trackColor('#33FFFFFF')
          .selectedColor($r('app.color.brand'))
          .blockColor(Color.White)
          .onChange((value: number, mode: SliderChangeMode) => {
            this.applySlider(value, mode, DanmakuSliderKind.Opacity);
          })
      }
      .width('100%')

      // ---- 弹幕字号缩放（0.5–2.0）：DanmakuLayer → ctx.setScaleTextSize ----
      Column({ space: 2 }) {
        Row() {
          Text($r('app.string.danmaku_font_scale'))
            .fontSize(12)
            .fontColor('#E6FFFFFF')
          Blank()
          Text(`${this.fontScale.toFixed(1)}×`)
            .fontSize(12)
            .fontColor('#99FFFFFF')
        }
        .width('100%')

        Slider({ value: this.fontScale, min: 0.5, max: 2.0, step: 0.1 })
          .width('100%')
          .trackColor('#33FFFFFF')
          .selectedColor($r('app.color.brand'))
          .blockColor(Color.White)
          .onChange((value: number, mode: SliderChangeMode) => {
            this.applySlider(value, mode, DanmakuSliderKind.FontScale);
          })
      }
      .width('100%')

      // ---- 显示区域（0.25–1.0，占播放区高度比例）：DanmakuLayer 高度重排 ----
      Column({ space: 2 }) {
        Row() {
          Text($r('app.string.danmaku_show_area'))
            .fontSize(12)
            .fontColor('#E6FFFFFF')
          Blank()
          Text(`${Math.round(this.showArea * 100)}%`)
            .fontSize(12)
            .fontColor('#99FFFFFF')
        }
        .width('100%')

        Slider({ value: this.showArea, min: 0.25, max: 1.0, step: 0.05 })
          .width('100%')
          .trackColor('#33FFFFFF')
          .selectedColor($r('app.color.brand'))
          .blockColor(Color.White)
          .onChange((value: number, mode: SliderChangeMode) => {
            this.applySlider(value, mode, DanmakuSliderKind.ShowArea);
          })
      }
      .width('100%')

      // ---- 滚动速度（3–15s，越小越快）：DanmakuLayer → ctx.setScrollSpeedFactor ----
      Column({ space: 2 }) {
        Row() {
          Text($r('app.string.danmaku_duration'))
            .fontSize(12)
            .fontColor('#E6FFFFFF')
          Blank()
          Text(`${this.duration.toFixed(1)}s`)
            .fontSize(12)
            .fontColor('#99FFFFFF')
        }
        .width('100%')

        Slider({ value: this.duration, min: 3, max: 15, step: 0.5 })
          .width('100%')
          .trackColor('#33FFFFFF')
          .selectedColor($r('app.color.brand'))
          .blockColor(Color.White)
          .onChange((value: number, mode: SliderChangeMode) => {
            this.applySlider(value, mode, DanmakuSliderKind.Duration);
          })
      }
      .width('100%')

      // ---- 屏蔽等级（0–10，越大屏蔽越多）：DanmakuLayer.addOne 权重过滤 ----
      Column({ space: 2 }) {
        Row() {
          Text($r('app.string.danmaku_weight'))
            .fontSize(12)
            .fontColor('#E6FFFFFF')
          Blank()
          Text(`${Math.round(this.weight)}`)
            .fontSize(12)
            .fontColor('#99FFFFFF')
        }
        .width('100%')

        Slider({ value: this.weight, min: 0, max: 10, step: 1 })
          .width('100%')
          .trackColor('#33FFFFFF')
          .selectedColor($r('app.color.brand'))
          .blockColor(Color.White)
          .onChange((value: number, mode: SliderChangeMode) => {
            this.applySlider(value, mode, DanmakuSliderKind.Weight);
          })
      }
      .width('100%')

      // ---- 合并重复弹幕（开关）：DanmakuController.handleDanmaku 入桶时合并 ----
      Row() {
        Text($r('app.string.danmaku_merge'))
          .fontSize(12)
          .fontColor('#E6FFFFFF')
        Blank()
        Toggle({ type: ToggleType.Switch, isOn: this.merge })
          .selectedColor($r('app.color.brand'))
          .onChange((on: boolean) => {
            this.merge = on;
            Pref.danmakuMerge.put(on);
          })
      }
      .width('100%')
    }
    .width(240)
    .padding(14)
    .backgroundColor('#E61A1A20')
    .borderRadius(14)
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
