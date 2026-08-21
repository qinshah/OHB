// [API 23+] 视频详情页
import { DataStatus } from '../common/state/DataState';
import { Route } from '../framework/Route';
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
import { VideoNodeController } from '../player/VideoNodeController';
import { VideoListTile } from '../common/components/VideoListTile';

/**
 * 视频详情页（TabView 布局）
 * - 播放区固定顶部（视频渲染节点经 VideoNodeController 管理，可与全屏页共享迁移）
 * - 详情头部（标题/UP/互动/简介/分P）固定在 Tabs 上方
 * - Tabs 切换「推荐」与「评论」
 */
@Component
export default struct VideoDetailPage {
  @Prop bvid: string = '';
  @State vm: VideoDetailVM = new VideoDetailVM();
  @State descExpanded: boolean = false;
  @State commentLoaded: boolean = false;
  @State currentTab: number = 0;
  /**
   * 视频渲染节点控制器：与全屏页共享同一 XComponent 节点（Surface 不销毁）。
   * 注意：在 aboutToAppear 中获取（而非 @State 初始化表达式），
   * 保证 bvid 已从路由参数同步就绪，避免拿到空 id 的控制器导致 Surface 绑不上（黑屏）。
   */
  private nodeController: VideoNodeController | null = null;
  /**
   * 容器重建序号：全屏页完全销毁归还节点时 +1，
   * ForEach key 随之变化 → NodeContainer 销毁重建 → makeNode 重新挂载节点。
   * （实测详情页容器在全屏期间可能解绑，rebuild 通知不到，
   * 必须重建容器才能重新 makeNode 取回游离态节点）
   */
  @State containerSeq: number = 0;
  /** 评论 ViewModel（type=1 视频评论） */
  @State commentVm: CommentViewModel = new CommentViewModel();

  aboutToAppear(): void {
    // aboutToAppear 时 @Prop 一定已同步：此时按 bvid 获取节点控制器
    this.nodeController = VideoNodeController.get(this.bvid);
    // 注册容器重建回调：全屏页 onDisAppear 归还节点时触发（见 requestRestore）
    if (this.nodeController !== null) {
      this.nodeController.setRestoreListener(() => {
        this.containerSeq++;
      });
    }
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

  /** 取本页的节点控制器（保证非空；闭包内使用规避可空类型限制） */
  private nc(): VideoNodeController {
    return VideoNodeController.get(this.bvid);
  }

  aboutToDisappear(): void {
    // 注销容器重建回调（controller 生命周期可能长于本页，防悬空回调）
    if (this.nodeController !== null) {
      this.nodeController.setRestoreListener(null);
    }
    this.vm.playerVM.setAspectRatioReady(null);
    this.vm.playerVM.setSystemVolumeChange(null);
    this.vm.playerVM.detachMediaSession();
    this.vm.release();
    // 页面彻底关闭：销毁渲染节点并注销控制器（全屏页此时已归还节点）
    VideoNodeController.remove(this.bvid);
  }

  build() {
    NavDestination() {
      Column() {
        // ===== 播放区 =====
        Stack() {
          // 渲染节点容器：与全屏页共享同一节点，全屏切换时节点迁移、Surface 不销毁。
          // ForEach key 绑定 containerSeq：全屏页归还节点时 seq++ → key 变化 →
          // 容器销毁重建 → makeNode 重新挂载节点（覆盖容器已解绑、rebuild
          // 通知不到的场景）。this.nc() 保证返回非空控制器。
          ForEach([this.containerSeq], (seq: number) => {
            NodeContainer(this.nc())
              .width('100%')
              .height('100%')
          }, (seq: number) => `nc_${seq}`)

          // 控制层
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

          // 返回键
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
            Route.pop();
          })
        }
        .width('100%')
        // 播放器容器固定 16:9（不跟随视频宽高比）：
        // - 修复「点互动按钮触发 rebuild 后视频画面才顺带更新宽高比」的问题
        //   （旧写法深读 @State vm.playerVM.aspectRatio，嵌套 @Observed 变更不触发刷新，
        //   仅在无关状态更新时被连带读取）
        // - 避免竖屏视频（宽高比 < 1）时容器过高，挤压下方 Tabs 空间
        // - 视频画面本身由内核 videoScaleType=FIT（contain）在 16:9 容器内等比缩放留黑边
        .aspectRatio(16 / 9)
        .backgroundColor(Color.Black)

        // ===== Tabs：推荐 / 评论 =====
        Tabs({ barPosition: BarPosition.Start, index: this.currentTab }) {
          TabContent() {
            this.RelatedTab()
          }
          .tabBar(this.tabBarItem(0, '推荐', ''))

          TabContent() {
            this.CommentTab()
          }
          .tabBar(
            this.tabBarItem(1, '评论', ` ${FormatUtils.count(this.vm.detail?.reply ?? 0)}`))
        }
        .barWidth('100%')
        .barHeight(44)
        .barBackgroundColor(AppColors.PAGE_BG)
        .onChange((index: number) => {
          this.currentTab = index;
          if (index === 1 && !this.commentLoaded) {
            this.loadComment();
          }
        })
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppColors.PAGE_BG)
    }
    // 从全屏页返回时不做主动节点操作（对齐官方最佳实践）：
    // 全屏页容器销毁时框架会自动 rebuild，详情页容器届时 makeNode 拿回节点。
    // 若在此处（全屏页容器仍存活时）restoreToHost，会引发多容器 makeNode 竞争，
    // 节点被全屏页容器抢回并随其销毁 → 黑屏。
    .onShown(() => {
    })
  }

  @Builder
  tabBarItem(index: number, label: string, badge: string) {
    Text(`${label}${badge}`)
      .fontSize(14)
      .fontWeight(this.currentTab === index ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(this.currentTab === index ? AppColors.BRAND : AppColors.TEXT_SECONDARY)
      .padding({ left: 16, right: 16 })
  }

  @Builder
  DetailHeader() {
    Column({ space: 10 }) {
      // 标题 + 播放数据
      Text(this.vm.detail!.title)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.TEXT_PRIMARY)
        .width('100%')
      Row({ space: 12 }) {
        Text(`${FormatUtils.count(this.vm.detail!.view)}播放`)
          .fontSize(12)
          .fontColor(AppColors.TEXT_SECONDARY)
        Text(`${FormatUtils.count(this.vm.detail!.danmaku)}弹幕`)
          .fontSize(12)
          .fontColor(AppColors.TEXT_SECONDARY)
        Text(FormatUtils.relativeTime(this.vm.detail!.pubdate))
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
        Image(this.vm.detail!.ownerFace)
          .width(40)
          .height(40)
          .borderRadius(20)
          .alt($r('app.media.startIcon'))
          .onClick(() => {
            const d = this.vm.detail;
            if (d !== null) {
              const p: UserSpaceParam = { mid: d.ownerMid };
              Route.push(Route.userSpace, p);
            }
          })
        Text(this.vm.detail!.ownerName)
          .fontSize(15)
          .fontColor(AppColors.TEXT_PRIMARY)
          .layoutWeight(1)
          .onClick(() => {
            const d = this.vm.detail;
            if (d !== null) {
              const p: UserSpaceParam = { mid: d.ownerMid };
              Route.push(Route.userSpace, p);
            }
          })
      }
      .width('100%')
      .padding(10)
      .backgroundColor(AppColors.CARD_BG)
      .borderRadius(10)

      // 互动操作栏
      Row() {
        this.ActionItem(this.vm.liked ? '❤️' : '🤍', `${this.vm.detail!.like}`,
          this.vm.liked ? AppColors.BRAND : AppColors.TEXT_SECONDARY, () => {
            this.vm.like();
          })
        this.ActionItem('🪙', `${this.vm.detail!.coin}`,
          this.vm.coined ? AppColors.BRAND : AppColors.TEXT_SECONDARY, () => {
            this.vm.coin();
          })
        this.ActionItem(this.vm.favorited ? '⭐' : '☆', `${this.vm.detail!.favorite}`,
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
        Text(this.vm.detail!.desc.length > 0 ? this.vm.detail!.desc : '暂无简介')
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

      // 分P列表
      if (this.vm.detail!.pages.length > 1) {
        this.PageList()
      }
    }
  }

  @Builder
  PageList() {
    Column({ space: 6 }) {
      Text(`分P（${this.vm.detail!.pages.length}）`)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.TEXT_PRIMARY)
        .width('100%')
      ForEach(this.vm.detail!.pages, (p: VideoPageItem, index: number) => {
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
    .width('100%')
  }

  @Builder
  RelatedTab() {
    List() {
      ListItem() {
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
          // ===== 详情头部（标题/UP/互动/简介/分P）=====
          this.DetailHeader()
        }
      }

      ListItem() {
        // 相关视频
        Text('相关推荐')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TEXT_PRIMARY)
          .width('100%')
      }.padding({ top: 20, bottom: 10 })

      if (this.vm.relatedState.status === DataStatus.Loading) {
        ListItem() {
          LoadingProgress()
            .width(28)
            .height(28)
            .color(AppColors.BRAND)
            .margin({ top: 8 })
        }
      } else if (this.vm.relatedState.status === DataStatus.Data) {
        ForEach(this.vm.related, (item: VideoCard) => {
          ListItem() {
            VideoListTile({
              card: item,
              onCardClick: (bvid: string) => {
                Route.push(Route.video, bvid);
              }
            })
          }
          .padding({ top: 6, bottom: 6 })
          .height(100) // TODO 一多高度
        }, (item: VideoCard) => item.bvid)
      }
    }
    .width('100%').height('100%')
    .padding({ left: 8, right: 8 })
    .scrollBar(BarState.Off)
  }

  @Builder
  CommentTab() {
    Scroll() {
      Column({ space: 10 }) {
        if (!this.commentLoaded) {
          Row({ space: 8 }) {
            LoadingProgress()
              .width(22)
              .height(22)
              .color(AppColors.BRAND)
            Text('加载评论…')
              .fontSize(13)
              .fontColor(AppColors.TEXT_SECONDARY)
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding(24)
        } else {
          CommentSection({ vm: this.commentVm })
            .width('100%')
        }
      }
      .width('100%')
      .padding(12)
    }
    .scrollBar(BarState.Off)
    .width('100%')
    .height('100%')
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