import { Route } from '../framework/Route';
import { DanmakuMessage } from '../models/LiveModels';
import { LiveRoomViewModel } from '../viewmodel/LiveRoomViewModel';
import { Player } from '../player/Player';
import { PlayerRepository } from '../repository/PlayerRepository';
import { PlaybackState } from '../player/PlayerTypes';
import { AppColors } from '../theme/AppTheme';

/**
 * 直播间（P2 Task 15）：直播流播放（PlayerController）+ WebSocket 弹幕收发 + 屏蔽词。
 * 播放器经 PlayerRepository 管理（key=live_roomId）。
 */
@Component
export struct LiveRoomPage {
  @Prop roomId: number = 0;
  @Prop title: string = '';
  @State vm: LiveRoomViewModel = new LiveRoomViewModel();
  @State inputText: string = '';
  @State danmakuCount: number = 0;
  @State showShieldPanel: boolean = false;
  @State shieldInput: string = '';
  @State playing: boolean = false;
  private cntlr: Player = PlayerRepository.create(this.roomId.toString());
  private scroller: Scroller = new Scroller();
  private uiTimer: number = -1;

  aboutToAppear(): void {
    // 经 PlayerRepository 以 roomId 创建/复用播放器
    const key = `live_${this.roomId}`;
    if (this.cntlr.id !== key) {
      PlayerRepository.remove(this.cntlr.id);
      this.cntlr = PlayerRepository.create(key);
    }
    this.cntlr.attachUIContext(this.getUIContext());
    this.vm.init(this.roomId);
    this.vm.load().then(() => {
      if (this.vm.playInfo !== null) {
        this.cntlr.load(this.vm.playInfo.playUrl, Player.defaultHeaders());
      }
    });
    this.startUiTimer();
  }

  aboutToDisappear(): void {
    this.stopUiTimer();
    this.vm.release();
    PlayerRepository.remove(`live_${this.roomId}`);
  }

  private startUiTimer(): void {
    if (this.uiTimer >= 0) {
      return;
    }
    this.uiTimer = setInterval(() => {
      if (this.cntlr.state === PlaybackState.Playing) {
        this.cntlr.syncProgress();
      }
      this.playing = this.cntlr.state === PlaybackState.Playing;
      if (this.danmakuCount !== this.vm.danmaku.length) {
        this.danmakuCount = this.vm.danmaku.length;
        this.scroller.scrollEdge(Edge.Bottom);
      }
    }, 500);
  }

  private stopUiTimer(): void {
    if (this.uiTimer >= 0) {
      clearInterval(this.uiTimer);
      this.uiTimer = -1;
    }
  }

  build() {
    Column() {
      // ===== 播放区 =====
      Stack() {
        // TODO 视频
        // .width('100%')
        // .height('100%')
        // .backgroundColor(Color.Black)

        // 返回 + 标题
        Row({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(20)
            .fontColor([Color.White])
            .padding(6)
            .onClick(() => {
              Route.pop();
            })
          Text(this.vm.playInfo?.title ?? this.title)
            .fontSize(14)
            .fontColor(Color.White)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          Text(this.vm.playInfo !== null ? `${this.vm.playInfo.online}观看` : '')
            .fontSize(11)
            .fontColor(Color.White)
        }
        .width('100%')
        .padding({ left: 6, right: 12, top: 6 })
        .backgroundColor('#33000000')

        // 播放/暂停
        if (this.playing) {
          Stack() {
            SymbolGlyph($r('sys.symbol.pause_fill'))
              .fontSize(20)
              .fontColor([Color.White])
          }
          .width(40)
          .height(40)
          .borderRadius(20)
          .backgroundColor('#66000000')
          .onClick(() => {
            this.cntlr.togglePlay();
          })
        }
      }
      .width('100%')
      .aspectRatio(16 / 9)
      .backgroundColor(Color.Black)

      // ===== 弹幕区 =====
      Scroll(this.scroller) {
        Column({ space: 4 }) {
          ForEach(this.vm.danmaku, (msg: DanmakuMessage) => {
            Row({ space: 6 }) {
              Text(msg.uname)
                .fontSize(12)
                .fontColor(AppColors.BRAND)
                .maxLines(1)
              Text(msg.text)
                .fontSize(13)
                .fontColor(AppColors.TEXT_PRIMARY)
                .layoutWeight(1)
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)
          }, (msg: DanmakuMessage) => `${msg.ts}_${msg.uid}_${msg.text}`)
        }
        .width('100%')
        .padding(10)
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)

      // ===== 底部输入 =====
      Row({ space: 8 }) {
        TextInput({ text: $$this.inputText, placeholder: '发个友善的弹幕见证当下' })
          .layoutWeight(1)
          .height(36)
          .fontSize(13)
          .backgroundColor(AppColors.CARD_BG)
          .borderRadius(18)
          .padding({ left: 14, right: 14 })
          .onSubmit(() => {
            this.sendDanmaku();
          })
        Button('发送')
          .height(36)
          .fontSize(13)
          .backgroundColor(AppColors.BRAND)
          .fontColor(Color.White)
          .enabled(!this.vm.isSending)
          .onClick(() => {
            this.sendDanmaku();
          })
        Text('屏蔽')
          .fontSize(12)
          .fontColor(AppColors.TEXT_SECONDARY)
          .onClick(() => {
            this.showShieldPanel = true;
          })
      }
      .width('100%')
      .padding({
        left: 10,
        right: 10,
        top: 8,
        bottom: 8
      })
      .backgroundColor(AppColors.PAGE_BG)

      // 屏蔽词面板
      if (this.showShieldPanel) {
        this.ShieldPanel()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.PAGE_BG)
  }

  @Builder
  ShieldPanel() {
    Column({ space: 10 }) {
      Row() {
        Text('弹幕屏蔽词')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TEXT_PRIMARY)
        Blank()
        Text('关闭')
          .fontSize(13)
          .fontColor(AppColors.TEXT_SECONDARY)
          .onClick(() => {
            this.showShieldPanel = false;
          })
      }
      .width('100%')

      Row({ space: 8 }) {
        TextInput({ text: $$this.shieldInput, placeholder: '输入要屏蔽的关键词' })
          .layoutWeight(1)
          .height(34)
          .fontSize(13)
          .backgroundColor(AppColors.CARD_BG)
          .borderRadius(17)
          .padding({ left: 12, right: 12 })
        Button('添加')
          .height(34)
          .fontSize(12)
          .backgroundColor(AppColors.BRAND)
          .fontColor(Color.White)
          .onClick(() => {
            this.vm.addShieldWord(this.shieldInput);
            this.shieldInput = '';
          })
      }
      .width('100%')

      if (this.vm.shieldWords.length === 0) {
        Text('暂无屏蔽词')
          .fontSize(12)
          .fontColor(AppColors.TEXT_SECONDARY)
      } else {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.vm.shieldWords, (word: string) => {
            Text(`${word} ×`)
              .fontSize(12)
              .fontColor(AppColors.TEXT_PRIMARY)
              .backgroundColor(AppColors.CARD_BG)
              .borderRadius(12)
              .padding({
                left: 10,
                right: 10,
                top: 4,
                bottom: 4
              })
              .margin({ right: 8, bottom: 8 })
              .onClick(() => {
                this.vm.removeShieldWord(word);
              })
          }, (word: string) => word)
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor(AppColors.CARD_BG)
    .borderRadius(12)
    .margin(10)
    .shadow({ radius: 12, color: '#22000000' })
  }

  private async sendDanmaku(): Promise<void> {
    const text = this.inputText.trim();
    if (text.length === 0) {
      return;
    }
    const ok = await this.vm.send(text);
    if (ok) {
      this.inputText = '';
      this.scroller.scrollEdge(Edge.Bottom);
    }
  }
}
