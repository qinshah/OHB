import { DataStatus } from '../common/state/DataState';
import { Route } from '../framework/Route';
import { FormatUtils } from '../common/utils/FormatUtils';
import { BangumiDetail, BangumiEpisode, BangumiItem } from '../models/BangumiModels';
import { BangumiDetailViewModel } from '../viewmodel/BangumiDetailViewModel';
import { PlaybackState } from '../player/PlayerTypes';
import { EmptyView, ErrorView, LoadingView } from '../common/components/StateViews';
import { AppColors } from '../theme/AppTheme';

/**
 * 番剧详情页（P2 Task 20）：详情、追番、选集播放。
 */
@Component
export struct BangumiDetailPage {
  @Prop seasonId: number = 0;
  @State vm: BangumiDetailViewModel = new BangumiDetailViewModel();
  @State playing: boolean = false;
  @State posMs: number = 0;
  @State durMs: number = 0;
  private xcController: XComponentController = new XComponentController();
  private bound: boolean = false;
  private uiTimer: number = -1;

  aboutToAppear(): void {
    // 先经 PlayerRepository 以 seasonId 绑定/创建播放器
    this.vm.attachCntlr(this.seasonId);
    this.vm.cntlr.attachUIContext(this.getUIContext());
    this.vm.load(this.seasonId);
    this.startUiTimer();
  }

  aboutToDisappear(): void {
    this.stopUiTimer();
    this.vm.release();
  }

  private startUiTimer(): void {
    if (this.uiTimer >= 0) {
      return;
    }
    this.uiTimer = setInterval(() => {
      if (this.vm.cntlr.state === PlaybackState.Playing) {
        this.vm.cntlr.syncProgress();
      }
      this.playing = this.vm.cntlr.state === PlaybackState.Playing;
      this.posMs = this.vm.cntlr.positionMs;
      this.durMs = this.vm.cntlr.durationMs;
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
      // 播放区
      Stack() {
        // TODO 视频
        // width('100%')
        //   .height('100%')
        //   .backgroundColor(Color.Black)

        // 返回
        Stack() {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(20)
            .fontColor([Color.White])
            .padding(6)
        }
        .width(38)
        .height(38)
        .borderRadius(19)
        .backgroundColor('#66000000')
        .position({ x: 8, y: 8 })
        .onClick(() => {
          Route.pop();
        })

        // 播放控制
        if (this.vm.playError.length === 0) {
          Column({ space: 8 }) {
            Stack() {
              SymbolGlyph(this.playing ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'))
                .fontSize(20)
                .fontColor([Color.White])
            }
            .width(44)
            .height(44)
            .borderRadius(22)
            .backgroundColor('#66000000')
            .onClick(() => {
              this.vm.cntlr.togglePlay();
            })

            Text(`${FormatUtils.durationMs(this.posMs)} / ${FormatUtils.durationMs(this.durMs)}`)
              .fontSize(11)
              .fontColor(Color.White)
          }
          .justifyContent(FlexAlign.End)
          .width('100%')
          .padding({ right: 12, bottom: 8 })
          .alignItems(HorizontalAlign.End)
        }
      }
      .width('100%')
      .aspectRatio(16 / 9)
      .backgroundColor(Color.Black)

      if (this.vm.state.status === DataStatus.Loading) {
        LoadingView()
          .layoutWeight(1)
      } else if (this.vm.state.status === DataStatus.Error) {
        ErrorView({
          message: this.vm.errorMessage,
          retryable: true,
          onRetry: () => {
            this.vm.load(this.seasonId);
          }
        })
          .layoutWeight(1)
      } else if (this.vm.detail !== null) {
        Scroll() {
          Column({ space: 10 }) {
            // 信息头
            Row({ space: 10 }) {
              Image(this.vm.detail.cover)
                .width(96)
                .height(128)
                .borderRadius(8)
                .objectFit(ImageFit.Cover)
                .alt($r('app.media.startIcon'))
              Column({ space: 6 }) {
                Text(this.vm.detail.title)
                  .fontSize(17)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(AppColors.TEXT_PRIMARY)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(`全${this.vm.detail.total}话`)
                  .fontSize(12)
                  .fontColor(AppColors.TEXT_SECONDARY)
                Text(`${FormatUtils.count(this.vm.detail.viewCount)}播放`)
                  .fontSize(12)
                  .fontColor(AppColors.TEXT_SECONDARY)
                Text(`${FormatUtils.count(this.vm.detail.followCount)}追番`)
                  .fontSize(12)
                  .fontColor(AppColors.TEXT_SECONDARY)
                Text(this.vm.detail.isFollow ? '已追番' : '+ 追番')
                  .fontSize(13)
                  .fontColor(this.vm.detail.isFollow ? AppColors.TEXT_SECONDARY : Color.White)
                  .backgroundColor(this.vm.detail.isFollow ? AppColors.CARD_BG : AppColors.BRAND)
                  .borderRadius(14)
                  .padding({
                    left: 16,
                    right: 16,
                    top: 5,
                    bottom: 5
                  })
                  .border({ width: 1, color: AppColors.DIVIDER })
                  .onClick(() => {
                    this.vm.toggleFollow();
                  })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }
            .width('100%')

            if (this.vm.detail.evaluate.length > 0) {
              Text(this.vm.detail.evaluate)
                .fontSize(13)
                .fontColor(AppColors.TEXT_SECONDARY)
                .width('100%')
                .lineHeight(19)
            }

            if (this.vm.tipText.length > 0) {
              Text(this.vm.tipText)
                .fontSize(12)
                .fontColor(AppColors.BRAND)
                .width('100%')
            }

            if (this.vm.playError.length > 0) {
              Text(this.vm.playError)
                .fontSize(12)
                .fontColor(AppColors.TEXT_SECONDARY)
                .width('100%')
            }

            // 选集
            Text(`选集（${this.vm.detail.episodes.length}）`)
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.TEXT_PRIMARY)
              .width('100%')
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.vm.detail.episodes, (ep: BangumiEpisode) => {
                Text(ep.title)
                  .fontSize(12)
                  .fontColor(this.vm.currentEpisode?.epId === ep.epId ? Color.White : AppColors.TEXT_PRIMARY)
                  .backgroundColor(this.vm.currentEpisode?.epId === ep.epId ? AppColors.BRAND : AppColors.CARD_BG)
                  .borderRadius(12)
                  .padding({
                    left: 12,
                    right: 12,
                    top: 6,
                    bottom: 6
                  })
                  .margin({ right: 8, bottom: 8 })
                  .onClick(() => {
                    this.vm.selectEpisode(ep);
                    this.bound = false;
                  })
              }, (ep: BangumiEpisode) => `${ep.epId}`)
            }
            .width('100%')

            // 其他季
            if (this.vm.detail.seasons.length > 0) {
              Text('其他季')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppColors.TEXT_PRIMARY)
                .width('100%')
              ForEach(this.vm.detail.seasons, (season: BangumiItem) => {
                Text(season.title)
                  .fontSize(13)
                  .fontColor(AppColors.TEXT_PRIMARY)
                  .width('100%')
                  .padding(8)
                  .backgroundColor(AppColors.CARD_BG)
                  .borderRadius(8)
                  .onClick(() => {
                    this.vm.load(season.seasonId);
                    this.bound = false;
                  })
              }, (season: BangumiItem) => `${season.seasonId}`)
            }

            EmptyView({ tip: '没有更多内容了' })
              .height(80)
          }
          .width('100%')
          .padding(12)
          .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.PAGE_BG)
  }
}
