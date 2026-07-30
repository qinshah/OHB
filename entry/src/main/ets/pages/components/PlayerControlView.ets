import { PlayerController } from '../../player/PlayerController';
import { PlaybackState } from '../../player/PlayerTypes';
import { FormatUtils } from '../../common/utils/FormatUtils';

/**
 * 播放器控制层（Task 5）
 * - 中央播放/暂停、底部进度条（可拖拽 seek）、时间、全屏按钮
 * - 左侧纵向滑动调亮度、右侧纵向滑动调音量
 * - 点击切换控制层显隐
 */
@Component
export struct PlayerControlView {
  @ObjectLink controller: PlayerController;
  @State private controlsVisible: boolean = true;
  @State private dragging: boolean = false;
  @State private dragValue: number = 0;
  @State private volumeHint: string = '';
  @State private hintVisible: boolean = false;
  private hideTimer: number = -1;

  build() {
    Stack() {
      // 手势层：左亮度 / 右音量 / 中点击显隐
      Row() {
        Column()
          .layoutWeight(1)
          .height('100%')
          .gesture(
            PanGesture({ direction: PanDirection.Vertical })
              .onActionStart(async () => {
                await this.controller.getBrightness();
              })
              .onActionUpdate((event: GestureEvent) => {
                const delta = -event.offsetY / 300;
                const base = this.controller.brightness >= 0 ? this.controller.brightness : 0.5;
                const next = Math.max(0, Math.min(1, base + delta));
                this.controller.setBrightness(next);
                this.showHint(`亮度 ${Math.round(next * 100)}%`);
              })
          )
        Column()
          .layoutWeight(1)
          .height('100%')
          .gesture(
            PanGesture({ direction: PanDirection.Vertical })
              .onActionUpdate((event: GestureEvent) => {
                const delta = -event.offsetY / 300;
                const next = Math.max(0, Math.min(1, this.controller.volume + delta));
                this.controller.setVolume(next);
                this.showHint(`音量 ${Math.round(next * 100)}%`);
              })
          )
      }
      .width('100%')
      .height('100%')
      .onClick(() => {
        this.toggleControls();
      })

      // 缓冲指示
      if (this.controller.isPreparing || this.controller.state === PlaybackState.Preparing) {
        Column({ space: 8 }) {
          LoadingProgress()
            .width(42)
            .height(42)
            .color(Color.White)
          Text('加载中…')
            .fontSize(12)
            .fontColor(Color.White)
        }
      }

      // 音量/亮度提示
      if (this.hintVisible) {
        Text(this.volumeHint)
          .fontSize(13)
          .fontColor(Color.White)
          .backgroundColor('#99000000')
          .borderRadius(8)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      }

      // 控制层
      if (this.controlsVisible) {
        // 中央播放/暂停
        Text(this.controller.state === PlaybackState.Playing ? '❚❚' : '▶')
          .fontSize(36)
          .fontColor(Color.White)
          .textAlign(TextAlign.Center)
          .width(64)
          .height(64)
          .borderRadius(32)
          .backgroundColor('#66000000')
          .onClick(() => {
            this.controller.togglePlay();
            this.resetHideTimer();
          })

        // 底部控制条
        Column() {
          Row({ space: 8 }) {
            Text(this.controller.state === PlaybackState.Playing ? '❚❚' : '▶')
              .fontSize(16)
              .fontColor(Color.White)
              .width(28)
              .textAlign(TextAlign.Center)
              .onClick(() => {
                this.controller.togglePlay();
                this.resetHideTimer();
              })
            Text(FormatUtils.durationMs(this.displayPosition()))
              .fontSize(11)
              .fontColor(Color.White)
            Slider({
              value: this.displayPosition(),
              min: 0,
              max: this.controller.durationMs > 0 ? this.controller.durationMs : 100
            })
              .layoutWeight(1)
              .trackColor('#66FFFFFF')
              .selectedColor($r('app.color.brand'))
              .blockColor(Color.White)
              .onChange((value: number, mode: SliderChangeMode) => {
                if (mode === SliderChangeMode.Begin || mode === SliderChangeMode.Moving) {
                  this.dragging = true;
                  this.dragValue = value;
                }
                if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
                  this.dragging = false;
                  this.controller.seekTo(value);
                  this.resetHideTimer();
                }
              })
            Text(FormatUtils.durationMs(this.controller.durationMs))
              .fontSize(11)
              .fontColor(Color.White)
            Text('⛶')
              .fontSize(18)
              .fontColor(Color.White)
              .width(28)
              .textAlign(TextAlign.Center)
              .onClick(() => {
                this.controller.toggleFullscreen();
                this.resetHideTimer();
              })
          }
          .width('100%')
          .padding({ left: 12, right: 12, bottom: 10 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.End)
      }
    }
    .width('100%')
    .height('100%')
  }

  private displayPosition(): number {
    if (this.dragging) {
      return this.dragValue;
    }
    return this.controller.positionMs;
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
      if (this.controller.state === PlaybackState.Playing) {
        this.controlsVisible = false;
      }
    }, 3000);
  }

  private showHint(text: string): void {
    this.volumeHint = text;
    this.hintVisible = true;
    setTimeout(() => {
      this.hintVisible = false;
    }, 800);
  }
}
