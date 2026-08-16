// [API 23+] 播放器控制层
import { AVVolumePanel } from '@kit.AudioKit';
import { Player } from '../player/Player';
import { PlayerRepository } from '../repository/PlayerRepository';
import { PlaybackState } from '../player/PlayerTypes';
import { FormatUtils } from '../common/utils/FormatUtils';
import { SystemAudioHelper } from '../common/utils/SystemAudioHelper';

/** 手势类型：垂直=左亮度/右音量，水平=进度拖拽 */
enum PlayerGestureType {
  None,
  Brightness,
  Volume,
  Seek
}

/** Hub 展示模式 */
enum HubMode {
  Volume,
  Brightness,
  Seek
}

/**
 * 播放器控制层（播放优化版 v2）
 *
 * 图层优先级（Stack 底→顶）：
 * 1. AVVolumePanel（隐藏，驱动系统音量）
 * 2. Hub（音量/亮度/进度预览，居中，HitTestMode.None 不拦截触控）
 * 3. 手势监听层（全屏：单击切控制层、双击播放/暂停、垂直调音量亮度、水平拖进度）
 * 4. 控制层（最顶层：进度条、播放/暂停、全屏按钮）
 *
 */
@Component
export struct PlayerControlView {
  /** 播放器业务 id（如 bvid），经 PlayerRepository.get(id) 获取共享的 Player 实例 */
  @Prop playerId: string = ''
  @State playerVM: Player =
    PlayerRepository.get(this.playerId) ?? PlayerRepository.create(this.playerId)
  @State private posMs: number = 0;
  @State private durMs: number = 0;
  @State private playing: boolean = false;
  @State private vol: number = 0;
  @State private bri: number = 0.5;
  @State private controlsVisible: boolean = true;
  @State private dragging: boolean = false;
  @State private dragValue: number = 0;
  /** Hub 显示状态 */
  @State private hubVisible: boolean = false;
  @State private hubMode: HubMode = HubMode.Volume;
  /** AVVolumePanel 绑定的系统音量档位（绝对值，min..max）。更新此值即驱动系统音量变化 */
  @State private panelVolumeLevel: number = 0;
  private hideTimer: number = -1;
  private hubTimer: number = -1;
  private uiTimer: number = -1;
  private gestureType: PlayerGestureType = PlayerGestureType.None;
  /** 手势基础值：亮度/音量起始值，或水平 seek 的基准位置（ms） */
  private gestureBase: number = 0;
  /** 手势所在半边：true=右半屏（音量），false=左半屏（亮度） */
  private gestureVolumeSide: boolean = false;
  /** 屏幕尺寸（vp），用于手势灵敏度分母与 seek 行程 */
  private screenW: number = 1200;
  private screenH: number = 2400;
  /** 本组件注册的系统音量监听（aboutToDisappear 时反注册） */
  private volumeListener: (() => void) | null = null;

  aboutToAppear(): void {
    // 同步一次真实系统音量，保证面板档位与 Hub 初始值正确
    this.playerVM.syncSystemVolume();
    this.panelVolumeLevel = SystemAudioHelper.currentVolume;
    // 显式注册系统音量监听：硬件音量键/外部变化 → Hub 显示监听到的实际值
    this.volumeListener = (): void => {
      this.panelVolumeLevel = SystemAudioHelper.currentVolume;
      this.vol = this.playerVM.systemVolume;
      this.showVolumeHub();
    };
    SystemAudioHelper.addVolumeListener(this.volumeListener);
    this.startUiTimer();
    this.syncUi();
  }

  aboutToDisappear(): void {
    if (this.volumeListener !== null) {
      SystemAudioHelper.removeVolumeListener(this.volumeListener);
      this.volumeListener = null;
    }
    if (this.hideTimer >= 0) {
      clearTimeout(this.hideTimer);
      this.hideTimer = -1;
    }
    if (this.hubTimer >= 0) {
      clearTimeout(this.hubTimer);
      this.hubTimer = -1;
    }
    if (this.uiTimer >= 0) {
      clearInterval(this.uiTimer);
      this.uiTimer = -1;
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // ===== 1. 隐藏的系统音量面板组件（最底层）=====
      AVVolumePanel({
        volumeLevel: this.panelVolumeLevel,
        volumeParameter: {
          position: { x: -1, y: -1 }
        }
      })
        .width(0)
        .height(0)
        .hitTestBehavior(HitTestMode.None)

      // ===== 2. Hub（音量/亮度/进度预览，居中，不拦截触控）=====
      if (this.hubVisible) {
        Row({ space: 10 }) {
          if (this.hubMode === HubMode.Volume) {
            SymbolGlyph(this.volumeIcon())
              .fontSize(18)
              .fontColor([Color.White])
          } else if (this.hubMode === HubMode.Brightness) {
            SymbolGlyph($r('sys.symbol.sun_max'))
              .fontSize(18)
              .fontColor([Color.White])
          }
          Column({ space: 4 }) {
            Text(this.hubText())
              .fontSize(13)
              .fontColor(Color.White)
            // 细进度条：直观展示当前值/目标进度
            Progress({
              value: Math.round(this.hubRatio() * 100),
              total: 100,
              type: ProgressType.Linear
            })
              .width(110)
              .height(4)
              .color(Color.White)
              .backgroundColor('#66FFFFFF')
          }
          .alignItems(HorizontalAlign.Start)
        }
        .padding({
          left: 16,
          right: 16,
          top: 10,
          bottom: 10
        })
        .backgroundColor('#99000000')
        .borderRadius(12)
        .hitTestBehavior(HitTestMode.None)
      }

      // ===== 3. 手势监听层（全屏：单击/双击/垂直/水平）=====
      Row() {
        // 左半屏：亮度 + 水平进度
        Column()
          .layoutWeight(1)
          .height('100%')
          .gesture(
            GestureGroup(GestureMode.Exclusive,
              TapGesture({ count: 2 })
                .onAction(() => {
                  this.playerVM.togglePlay();
                  this.resetHideTimer();
                }),
              TapGesture({ count: 1 })
                .onAction(() => {
                  this.toggleControls();
                }),
              PanGesture({ direction: PanDirection.All })
                .onActionStart(() => {
                  this.onPanStart(false);
                })
                .onActionUpdate((event: GestureEvent) => {
                  this.onPanUpdate(event);
                })
                .onActionEnd(() => {
                  this.onPanEnd(true);
                })
                .onActionCancel(() => {
                  this.onPanEnd(false);
                })
            )
          )
        // 右半屏：音量 + 水平进度
        Column()
          .layoutWeight(1)
          .height('100%')
          .gesture(
            GestureGroup(GestureMode.Exclusive,
              TapGesture({ count: 2 })
                .onAction(() => {
                  this.playerVM.togglePlay();
                  this.resetHideTimer();
                }),
              TapGesture({ count: 1 })
                .onAction(() => {
                  this.toggleControls();
                }),
              PanGesture({ direction: PanDirection.All })
                .onActionStart(() => {
                  this.onPanStart(true);
                })
                .onActionUpdate((event: GestureEvent) => {
                  this.onPanUpdate(event);
                })
                .onActionEnd(() => {
                  this.onPanEnd(true);
                })
                .onActionCancel(() => {
                  this.onPanEnd(false);
                })
            )
          )
      }
      .width('100%')
      .height('100%')

      // ===== 4. 控制层（最顶层：进度条、播放/暂停、全屏按钮）=====
      if (this.controlsVisible) {
        // 底部控制条（仅包裹内容高度，不占满全屏）
        Row({ space: 8 }) {
          // 播放/暂停
          Stack() {
            SymbolGlyph(this.playing ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'))
              .fontSize(16)
              .fontColor([Color.White])
          }
          .width(28)
          .height(28)
          .onClick(() => {
            this.playerVM.togglePlay();
            this.resetHideTimer();
          })

          Text(FormatUtils.durationMs(this.displayPosition()))
            .fontSize(11)
            .fontColor(Color.White)

          Slider({
            value: this.displayPosition(),
            min: 0,
            max: this.durMs > 0 ? this.durMs : 100
          })
            .layoutWeight(1)
            .trackColor('#66FFFFFF')
            .selectedColor($r('app.color.brand'))
            .blockColor(Color.White)
            .onChange((value: number, mode: SliderChangeMode) => {
              if (mode === SliderChangeMode.Begin || mode === SliderChangeMode.Moving) {
                this.dragging = true;
                this.dragValue = value;
                this.resetHideTimer();
              }
              if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
                this.dragging = false;
                this.playerVM.seekTo(value);
                this.resetHideTimer();
              }
            })

          Text(FormatUtils.durationMs(this.durMs))
            .fontSize(11)
            .fontColor(Color.White)

          // 全屏按钮
          Stack() {
            SymbolGlyph(this.playerVM.fullscreen
              ? $r('sys.symbol.arrow_down_right_and_arrow_up_left')
              : $r('sys.symbol.arrow_up_left_and_arrow_down_right'))
              .fontSize(18)
              .fontColor([Color.White])
          }
          .width(28)
          .height(28)
          .onClick(() => {
            this.playerVM.toggleFullscreen();
            this.resetHideTimer();
          })
        }
        .width('100%')
        .padding({ left: 12, right: 12, bottom: 10 })
        .alignItems(VerticalAlign.Center)
        .position({ x: 0, y: '100%' })
        .translate({ y: '-100%' })
        // 空白区域透传给手势层；按钮与 Slider 自身仍可交互
        .hitTestBehavior(HitTestMode.None)
      }
    }
    .width('100%')
    .height('100%')
    .onAreaChange((_old: Area, newArea: Area) => {
      const w = newArea.width as number;
      const h = newArea.height as number;
      if (w > 0) {
        this.screenW = w;
      }
      if (h > 0) {
        this.screenH = h;
      }
    })
  }

  /**
   * 250ms UI 同步：播放中从内核同步真实进度，并把控制器状态拷贝到本地镜像，
   * 保证进度条/时间/按钮/音量/亮度实时刷新。
   */
  private syncUi(): void {
    if (!this.dragging && this.playerVM.state === PlaybackState.Playing) {
      this.playerVM.syncProgress();
    }
    this.posMs = this.playerVM.positionMs;
    this.durMs = this.playerVM.durationMs;
    this.playing = this.playerVM.state === PlaybackState.Playing;
    this.vol = this.playerVM.systemVolume;
    const b = this.playerVM.brightness;
    if (b >= 0) {
      this.bri = b;
    }
  }

  private startUiTimer(): void {
    if (this.uiTimer >= 0) {
      return;
    }
    this.uiTimer = setInterval(() => {
      this.syncUi();
    }, 250);
  }

  /** 手势开始：记录基准值（音量先同步系统真实值，亮度先读取窗口亮度） */
  private async onPanStart(isVolumeSide: boolean): Promise<void> {
    this.gestureVolumeSide = isVolumeSide;
    this.gestureType = PlayerGestureType.None;
    if (isVolumeSide) {
      this.playerVM.syncSystemVolume();
      this.gestureBase = this.playerVM.systemVolume;
      this.panelVolumeLevel = SystemAudioHelper.currentVolume;
    } else {
      await this.playerVM.getBrightness();
      this.gestureBase = this.playerVM.brightness >= 0 ? this.playerVM.brightness : 0.5;
    }
  }

  /** 手势更新：首次回调根据主轴确定类型（水平=进度，垂直=亮度/音量），随后按类型处理 */
  private onPanUpdate(event: GestureEvent): void {
    if (this.gestureType === PlayerGestureType.None) {
      const dx = event.offsetX;
      const dy = event.offsetY;
      if (Math.abs(dx) >= Math.abs(dy)) {
        this.gestureType = PlayerGestureType.Seek;
        this.gestureBase = this.posMs;
      } else {
        this.gestureType = this.gestureVolumeSide
          ? PlayerGestureType.Volume
          : PlayerGestureType.Brightness;
      }
    }
    if (this.gestureType === PlayerGestureType.Seek) {
      this.updateSeekGesture(event);
    } else if (this.gestureType === PlayerGestureType.Volume) {
      this.updateVolumeGesture(event);
    } else if (this.gestureType === PlayerGestureType.Brightness) {
      this.updateBrightnessGesture(event);
    }
  }

  /**
   * 水平滑动设置进度：只更新预览（dragValue + Hub），不立即 seek；
   * 手指松开时由 onPanEnd 真正执行 seek。
   */
  private updateSeekGesture(event: GestureEvent): void {
    const dur = this.durMs > 0 ? this.durMs : 0;
    if (dur <= 0 || this.screenW <= 0) {
      return;
    }
    const ratio = event.offsetX / this.screenW;
    const target = Math.max(0, Math.min(dur, this.gestureBase + ratio * dur));
    this.dragging = true;
    this.dragValue = target;
    this.showSeekHub();
  }

  private updateVolumeGesture(event: GestureEvent): void {
    const level = this.screenH * 1.5;
    const delta = -event.offsetY / level;
    const next = Math.max(0, Math.min(1, this.gestureBase + delta));
    this.applyVolumeNormalized(next);
    this.showVolumeHub();
  }

  private updateBrightnessGesture(event: GestureEvent): void {
    const level = this.screenH * 3;
    const delta = -event.offsetY / level;
    const next = Math.max(0, Math.min(1, this.gestureBase + delta));
    this.playerVM.setBrightness(next);
    this.bri = next;
    this.showBrightnessHub();
  }

  /** 手势结束：水平滑动提交 seek；取消则不提交 */
  private onPanEnd(commitSeek: boolean): void {
    const t = this.gestureType;
    this.gestureType = PlayerGestureType.None;
    if (t === PlayerGestureType.Seek) {
      this.dragging = false;
      if (commitSeek) {
        this.playerVM.seekTo(this.dragValue);
        this.resetHideTimer();
      }
    }
  }

  private displayPosition(): number {
    if (this.dragging) {
      return this.dragValue;
    }
    return this.posMs;
  }

  private toggleControls(): void {
    this.controlsVisible = !this.controlsVisible;
    if (this.controlsVisible) {
      this.resetHideTimer();
    }
  }

  private resetHideTimer(): void {
    if (this.hideTimer >= 0) {
      clearTimeout(this.hideTimer);
    }
    this.hideTimer = setTimeout(() => {
      if (this.playerVM.state === PlaybackState.Playing) {
        this.controlsVisible = false;
      }
    }, 3000);
  }

  /**
   * 将归一化音量(0..1)转为系统绝对档位并更新 AVVolumePanel 的 volumeLevel；
   * 同时立即回写 controller.systemVolume 与本地镜像，Hub 即时显示
   * （随后被 streamVolumeChange 监听到的真实值校正）。
   */
  private applyVolumeNormalized(normalized: number): void {
    const min = SystemAudioHelper.minVolume;
    const max = SystemAudioHelper.maxVolume;
    const range = max - min;
    if (range <= 0) {
      return;
    }
    const clamped = Math.max(0, Math.min(1, normalized));
    const target = Math.round(min + clamped * range);
    this.playerVM.systemVolume = clamped;
    this.vol = clamped;
    if (target === this.panelVolumeLevel) {
      return;
    }
    this.panelVolumeLevel = target;
  }

  private showVolumeHub(): void {
    this.hubMode = HubMode.Volume;
    this.showHub();
  }

  private showBrightnessHub(): void {
    this.hubMode = HubMode.Brightness;
    this.showHub();
  }

  private showSeekHub(): void {
    this.hubMode = HubMode.Seek;
    this.showHub();
  }

  private showHub(): void {
    this.hubVisible = true;
    if (this.hubTimer >= 0) {
      clearTimeout(this.hubTimer);
    }
    this.hubTimer = setTimeout(() => {
      this.hubVisible = false;
    }, 800);
  }

  /** Hub 文案 */
  private hubText(): string {
    if (this.hubMode === HubMode.Seek) {
      return `${FormatUtils.durationMs(this.dragValue)} / ${FormatUtils.durationMs(this.durMs)}`;
    }
    if (this.hubMode === HubMode.Volume) {
      return `音量 ${Math.round(this.vol * 100)}%`;
    }
    return `亮度 ${Math.round(this.bri * 100)}%`;
  }

  /** Hub 进度条比例（0..1） */
  private hubRatio(): number {
    if (this.hubMode === HubMode.Seek) {
      return this.durMs > 0 ? this.dragValue / this.durMs : 0;
    }
    if (this.hubMode === HubMode.Volume) {
      return this.vol;
    }
    return this.bri;
  }

  /** 音量 Hub 图标（静音态用静音图标） */
  private volumeIcon(): Resource {
    return this.vol === 0 ? $r('sys.symbol.speaker_slash') : $r('sys.symbol.speaker');
  }
}
