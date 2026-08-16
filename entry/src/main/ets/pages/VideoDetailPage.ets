// [API 23+] 视频详情页
import { DataStatus } from '../common/state/DataState';
import { NavService } from '../common/navigation/NavService';
import { FormatUtils } from '../common/utils/FormatUtils';
import { VideoDetailVM } from '../viewmodel/VideoDetailVM';
import { ErrorView, LoadingView } from '../common/components/StateViews';
import { AppColors } from '../theme/AppTheme';
import { PlayerControlView } from '../components/PlayerControlView';
import { CommentSection } from '../components/CommentSection';
import { CommentViewModel } from '../viewmodel/CommentViewModel';
import { VideoCard } from '../models/VideoCard';
import { VideoCardView } from '../common/components/VideoCardView';
import { common } from '@kit.AbilityKit';
import { UserSpaceParam } from './RouteParams';
import { RouteNames } from './RouteNames';

/**
 * 视频详情页（Task 9 重构）：播放器 + 标题 + UP主 + 简介（V1 基础布局）。
 */
@Component
export struct VideoDetailPage {
  @Prop bvid: string = '';
  @State vm: VideoDetailVM = new VideoDetailVM();
  @State descExpanded: boolean = false;
  private xcController: XComponentController = new XComponentController();
  /** 评论 ViewModel（type=1 视频评论） */
  @State commentVm: CommentViewModel = new CommentViewModel();
  /** 评论是否已加载 */
  private commentLoaded: boolean = false;

  aboutToAppear(): void {
    // 先经 PlayerRepository 以 bvid 绑定/创建播放器（PlayerControlView、全屏页通过 get(bvid) 共享同一实例）
    this.vm.attachPlayer(this.bvid);
    this.vm.playerVM.attachUIContext(this.getUIContext());
    if (this.bvid.length > 0) {
      this.vm.load(this.bvid).then(() => {
        const ctx = this.getUIContext().getHostContext();
        if (ctx !== undefined && this.vm.detail !== null) {
          this.vm.playerVM.attachMediaSession(ctx as common.Context, this.vm.detail.title, this.vm.detail.ownerName);
        }
      });
    }
  }

  aboutToDisappear(): void {
    this.vm.playerVM.setAspectRatioReady(null);
    this.vm.playerVM.setSystemVolumeChange(null);
    this.vm.playerVM.detachMediaSession();
    this.vm.release();
  }

  build() {
    Column() {
      // ===== 播放区 =====
      Stack() {
        // 视频
        if (!this.vm.playerVM.fullscreen) {
          XComponent({
            type: XComponentType.SURFACE,
            controller: this.xcController
          })
            .onLoad(() => {
              this.vm.bindXComponent(this.xcController.getXComponentSurfaceId())
            })
            .width('100%')
            .height('100%')
            .backgroundColor(Color.Black)
        }

        // 控制层（经 playerId=bvid 从 PlayerRepository 获取同一播放器）
        PlayerControlView({ playerId: this.bvid })
          .width('100%')
          .height('100%')

        // 播放地址错误覆盖层
        if (this.vm.playError.length > 0) {
          Column({ space: 10 }) {
            Text(this.vm.playError)
              .fontSize(13)
              .fontColor(Color.White)
            Button('重试')
              .backgroundColor(AppColors.BRAND)
              .fontColor(Color.White)
              .onClick(() => {
                this.vm.retryPlayUrl();
              })
          }
          .width('100%')
          .height('100%')
          .backgroundColor('#B3000000')
          .justifyContent(FlexAlign.Center)
        }

        // 返回键：SDK SymbolGlyph 图标，不用 ‹
        Stack() {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(22)
            .fontColor([Color.White])
            .padding(8)
        }
        .width(40)
        .height(40)
        .borderRadius(20)
        .backgroundColor('#66000000')
        .position({ x: 8, y: 8 })
        .hitTestBehavior(HitTestMode.Block)
        .onClick(() => {
          NavService.pop();
        })
      }
      .width('100%')
      // 视频宽高比未就绪时回退 16:9
      .aspectRatio(this.vm.playerVM.aspectRatio > 0 ? this.vm.playerVM.aspectRatio : 16 / 9)
      .backgroundColor(Color.Black)

      // ===== 详情区 =====
      if (this.vm.detailState.status === DataStatus.Loading) {
        LoadingView()
          .layoutWeight(1)
      } else if (this.vm.detailState.status === DataStatus.Error) {
        ErrorView({
          message: this.vm.detailState.error?.message ?? '详情加载失败',
          retryable: true,
          onRetry: () => {
            this.vm.load(this.bvid);
          }
        })
          .layoutWeight(1)
      } else if (this.vm.detail !== null) {
        Scroll() {
          Column({ space: 12 }) {
            // 标题 + 播放数据
            Text(this.vm.detail.title)
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.TEXT_PRIMARY)
              .width('100%')
            Row({ space: 12 }) {
              Text(`${FormatUtils.count(this.vm.detail.view)}播放`)
                .fontSize(12)
                .fontColor(AppColors.TEXT_SECONDARY)
              Text(`${FormatUtils.count(this.vm.detail.danmaku)}弹幕`)
                .fontSize(12)
                .fontColor(AppColors.TEXT_SECONDARY)
              Text(FormatUtils.relativeTime(this.vm.detail.pubdate))
                .fontSize(12)
                .fontColor(AppColors.TEXT_SECONDARY)
              if (this.vm.playUrlInfo !== null) {
                Text(this.vm.playUrlInfo.qualityDesc)
                  .fontSize(12)
                  .fontColor(AppColors.BRAND)
              }
            }
            .width('100%')

            // UP 主行
            Row({ space: 10 }) {
              Image(this.vm.detail.ownerFace)
                .width(40)
                .height(40)
                .borderRadius(20)
                .alt($r('app.media.startIcon'))
                .onClick(() => {
                  const d = this.vm.detail;
                  if (d !== null) {
                    const p: UserSpaceParam = { mid: d.ownerMid };
                    NavService.push(RouteNames.USER_SPACE, p);
                  }
                })
              Text(this.vm.detail.ownerName)
                .fontSize(15)
                .fontColor(AppColors.TEXT_PRIMARY)
                .layoutWeight(1)
                .onClick(() => {
                  const d = this.vm.detail;
                  if (d !== null) {
                    const p: UserSpaceParam = { mid: d.ownerMid };
                    NavService.push(RouteNames.USER_SPACE, p);
                  }
                })
            }
            .width('100%')
            .padding(10)
            .backgroundColor(AppColors.CARD_BG)
            .borderRadius(10)

            // 互动操作栏（P2 Task 13）
            Row() {
              this.ActionItem(this.vm.liked ? '❤️' : '🤍', `${this.vm.detail.like}`,
                this.vm.liked ? AppColors.BRAND : AppColors.TEXT_SECONDARY, () => {
                  this.vm.like();
                })
              this.ActionItem('🪙', `${this.vm.detail.coin}`,
                this.vm.coined ? AppColors.BRAND : AppColors.TEXT_SECONDARY, () => {
                  this.vm.coin();
                })
              this.ActionItem(this.vm.favorited ? '⭐' : '☆', `${this.vm.detail.favorite}`,
                this.vm.favorited ? AppColors.BRAND : AppColors.TEXT_SECONDARY, () => {
                  this.vm.favorite(0);
                })
              this.ActionItem(this.vm.watchLaterAdded ? '✅' : '⏱️', '稍后再看',
                this.vm.watchLaterAdded ? AppColors.BRAND : AppColors.TEXT_SECONDARY, () => {
                  this.vm.addWatchLater();
                })
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceAround)
            .padding({ top: 4, bottom: 4 })

            if (this.vm.actionTip.length > 0) {
              Text(this.vm.actionTip)
                .fontSize(12)
                .fontColor(AppColors.BRAND)
                .width('100%')
            }

            // 简介
            Column({ space: 4 }) {
              Text(this.vm.detail.desc.length > 0 ? this.vm.detail.desc : '暂无简介')
                .fontSize(13)
                .fontColor(AppColors.TEXT_SECONDARY)
                .width('100%')
                .maxLines(this.descExpanded ? 100 : 2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .onClick(() => {
                  this.descExpanded = !this.descExpanded;
                })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            // 分P列表（P2 Task 13：可切换）
            if (this.vm.detail.pages.length > 1) {
              Text(`分P（${this.vm.detail.pages.length}）`)
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppColors.TEXT_PRIMARY)
                .width('100%')
              ForEach(this.vm.detail.pages, (p: VideoPageItem, index: number) => {
                Row() {
                  Text(`P${p.page}`)
                    .fontSize(13)
                    .fontColor(AppColors.BRAND)
                    .width(36)
                  Text(p.part)
                    .fontSize(13)
                    .fontColor(AppColors.TEXT_PRIMARY)
                    .layoutWeight(1)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(FormatUtils.duration(p.duration))
                    .fontSize(12)
                    .fontColor(AppColors.TEXT_SECONDARY)
                }
                .width('100%')
                .padding({ top: 6, bottom: 6 })
                .backgroundColor(this.vm.detail!.cid === p.cid ? AppColors.BRAND : Color.Transparent)
                .borderRadius(8)
                .onClick(() => {
                  const d = this.vm.detail;
                  if (d !== null && d.cid !== p.cid) {
                    this.vm.switchPage(d.pages[index], index);
                  }
                })
              }, (p: VideoPageItem) => `${p.page}`)
            }

            // 相关视频（P2 Task 13）
            Text('相关推荐')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.TEXT_PRIMARY)
              .width('100%')
            if (this.vm.relatedState.status === DataStatus.Loading) {
              LoadingProgress()
                .width(28)
                .height(28)
                .color(AppColors.BRAND)
                .margin({ top: 8 })
            } else if (this.vm.relatedState.status === DataStatus.Data) {
              WaterFlow() {
                ForEach(this.vm.related, (item: VideoCard) => {
                  FlowItem() {
                    VideoCardView({
                      card: item,
                      onCardClick: (bvid: string) => {
                        NavService.push(RouteNames.VIDEO_DETAIL, bvid);
                      }
                    })
                  }
                }, (item: VideoCard) => item.bvid)
              }
              .columnsTemplate('1fr 1fr')
              .columnsGap(8)
              .rowsGap(8)
              .width('100%')
            }

            // 评论（P2 Task 14）
            if (!this.commentLoaded) {
              Text('加载评论…')
                .fontSize(13)
                .fontColor(AppColors.TEXT_SECONDARY)
                .width('100%')
                .textAlign(TextAlign.Center)
                .padding(12)
                .onClick(() => {
                  this.loadComment();
                })
            } else {
              CommentSection({ vm: this.commentVm })
                .width('100%')
            }
          }
          .width('100%')
          .padding(12)
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.PAGE_BG)
  }

  @Builder
  ActionItem(icon: string, label: string, color: ResourceColor, onTap: () => void) {
    Column({ space: 2 }) {
      Text(icon)
        .fontSize(18)
      Text(label)
        .fontSize(10)
        .fontColor(color)
    }
    .padding({
      left: 8,
      right: 8,
      top: 6,
      bottom: 6
    })
    .onClick(() => {
      onTap();
    })
  }

  private loadComment(): void {
    if (this.commentLoaded || this.vm.detail === null) {
      return;
    }
    this.commentLoaded = true;
    this.commentVm.init(1, this.vm.detail.aid);
  }
}

/** 分P展示项（与 VideoDetail.pages 元素同构） */
interface VideoPageItem {
  cid: number;
  part: string;
  page: number;
  duration: number;
}
