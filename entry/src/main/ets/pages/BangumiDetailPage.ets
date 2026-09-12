import { DataStatus } from '../common/state/DataState';
import { Route } from '../framework/Route';
import { FormatUtils } from '../common/utils/FormatUtils';
import { BangumiDetail, BangumiEpisode, BangumiItem } from '../models/BangumiModels';
import { BangumiDetailViewModel } from '../viewmodel/BangumiDetailViewModel';
import { EmptyView, ErrorView, LoadingView } from '../common/components/StateViews';
import { AppColors } from '../theme/AppTheme';

/** 封面遮罩（顶透明 → 底部压暗，保证播放按钮与文字可读） */
const BANNER_SCRIM_CLEAR: string = '#00000000';
const BANNER_SCRIM_SOLID: string = '#99000000';

/**
 * 番剧详情页：季信息、追番、选集。
 *
 * 播放不在本页内实现——剧集统一「复用视频页」：
 * 点封面播放条或任意一集 → Route.push(Route.video, bvid)，
 * 由视频页负责渲染节点/控制栏/弹幕/全屏（见 VideoPage + VideoDetailVM）。
 * 普通视频接口对番剧分集的 bvid 同样有效（view/playurl 均返回正常数据）。
 */
@Component
export struct BangumiDetailPage {
  @Prop seasonId: number = 0;
  @State vm: BangumiDetailViewModel = new BangumiDetailViewModel();

  aboutToAppear(): void {
    this.vm.load(this.seasonId);
  }

  /** 重试 / 其他季切换后刷新，以 VM 记录的最新季号为准 */
  private reload(): void {
    this.vm.load(this.vm.seasonId > 0 ? this.vm.seasonId : this.seasonId);
  }

  /** 复用视频页播放指定剧集 */
  private playEpisode(ep: BangumiEpisode): void {
    if (ep.bvid.length === 0) {
      return;
    }
    Route.push(Route.video, ep.bvid);
  }

  /** 播放条默认点击第 1 集 */
  private playFirst(): void {
    const d = this.vm.detail;
    if (d === null || d.episodes.length === 0) {
      return;
    }
    this.playEpisode(d.episodes[0]);
  }

  build() {
    NavDestination() {
      Column() {
        // ===== 播放条：季封面 + 播放按钮（点击进入视频页）=====
        Stack() {
          if (this.vm.detail !== null) {
            Image(this.vm.detail.cover)
              .width('100%')
              .height('100%')
              .objectFit(ImageFit.Cover)
              .alt($r('app.media.startIcon'))

            Column()
              .width('100%')
              .height('100%')
              .linearGradient({
                angle: 180,
                colors: [[BANNER_SCRIM_CLEAR, 0.0], [BANNER_SCRIM_CLEAR, 0.35], [BANNER_SCRIM_SOLID, 1.0]]
              })

            if (this.vm.detail.episodes.length > 0) {
              Column({ space: 6 }) {
                Stack() {
                  SymbolGlyph($r('sys.symbol.play_fill'))
                    .fontSize(26)
                    .fontColor([Color.White])
                }
                .width(56)
                .height(56)
                .borderRadius(28)
                .backgroundColor('#66000000')
                Text($r('app.string.bangumi_detail_play'))
                  .fontSize(12)
                  .fontColor(Color.White)
              }
              .onClick(() => {
                this.playFirst();
              })
            }
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
              this.reload();
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
                  Text($r('app.string.bangumi_detail_total_ep', this.vm.detail.total))
                    .fontSize(12)
                    .fontColor(AppColors.TEXT_SECONDARY)
                  Text($r('app.string.bangumi_detail_views_count', FormatUtils.count(this.vm.detail.viewCount)))
                    .fontSize(12)
                    .fontColor(AppColors.TEXT_SECONDARY)
                  Text($r('app.string.bangumi_detail_follow_count', FormatUtils.count(this.vm.detail.followCount)))
                    .fontSize(12)
                    .fontColor(AppColors.TEXT_SECONDARY)
                  Text(this.vm.detail.isFollow
                    ? $r('app.string.bangumi_detail_followed')
                    : $r('app.string.bangumi_detail_follow'))
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

              // 选集（点击进入视频页播放）
              Text($r('app.string.bangumi_detail_episodes', this.vm.detail.episodes.length))
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppColors.TEXT_PRIMARY)
                .width('100%')
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(this.vm.detail.episodes, (ep: BangumiEpisode) => {
                  Text(ep.title)
                    .fontSize(12)
                    .fontColor(AppColors.TEXT_PRIMARY)
                    .backgroundColor(AppColors.CARD_BG)
                    .borderRadius(12)
                    .padding({
                      left: 12,
                      right: 12,
                      top: 6,
                      bottom: 6
                    })
                    .margin({ right: 8, bottom: 8 })
                    .onClick(() => {
                      this.playEpisode(ep);
                    })
                }, (ep: BangumiEpisode) => `${ep.epId}`)
              }
              .width('100%')

              // 其他季
              if (this.vm.detail.seasons.length > 0) {
                Text($r('app.string.bangumi_detail_other_seasons'))
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
                    })
                }, (season: BangumiItem) => `${season.seasonId}`)
              }

              EmptyView({ tip: $r('app.string.bangumi_detail_end') })
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
    .hideTitleBar(true)
  }
}
