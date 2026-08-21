import { DataStatus } from '../common/state/DataState';
import { Route } from '../framework/Route';
import { FormatUtils } from '../common/utils/FormatUtils';
import { DynamicKind } from '../models/DynamicItem';
import { DynamicDetailViewModel } from '../viewmodel/DynamicDetailViewModel';
import { CommentViewModel } from '../viewmodel/CommentViewModel';
import { CommentSection } from '../components/CommentSection';
import { EmptyView, ErrorView, LoadingView } from '../common/components/StateViews';
import { AppColors } from '../theme/AppTheme';
import { UserSpaceParam } from './RouteParams';

/**
 * 动态详情页（P2 Task 18）：详情展示、点赞、评论。
 */
@Component
export struct DynamicDetailPage {
  @Prop dynId: string = '';
  @State vm: DynamicDetailViewModel = new DynamicDetailViewModel();
  @State commentVm: CommentViewModel = new CommentViewModel();
  @State commentLoaded: boolean = false;

  aboutToAppear(): void {
    this.vm.load(this.dynId);
  }

  build() {
    Column() {
      Row() {
        Text('‹')
          .fontSize(24)
          .fontColor(AppColors.TEXT_PRIMARY)
          .width(32)
          .onClick(() => {
            Route.pop();
          })
        Text('动态详情')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY)
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 8, right: 12, top: 8, bottom: 4 })

      if (this.vm.state.status === DataStatus.Loading) {
        LoadingView()
          .layoutWeight(1)
      } else if (this.vm.state.status === DataStatus.Error) {
        ErrorView({
          message: this.vm.errorMessage,
          retryable: true,
          onRetry: () => {
            this.vm.load(this.dynId);
          }
        })
          .layoutWeight(1)
      } else if (this.vm.item !== null) {
        Scroll() {
          Column({ space: 10 }) {
            // 作者行
            Row({ space: 8 }) {
              Image(this.vm.item.upFace)
                .width(40)
                .height(40)
                .borderRadius(20)
                .alt($r('app.media.startIcon'))
                .onClick(() => {
                  const item = this.vm.item;
                  if (item !== null) {
                    const p: UserSpaceParam = { mid: item.upMid };
                    Route.push(Route.userSpace, p);
                  }
                })
              Column({ space: 2 }) {
                Text(this.vm.item.upName)
                  .fontSize(15)
                  .fontColor(AppColors.TEXT_PRIMARY)
                  .fontWeight(FontWeight.Medium)
                Text(FormatUtils.relativeTime(this.vm.item.pubTs))
                  .fontSize(11)
                  .fontColor(AppColors.TEXT_SECONDARY)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }
            .width('100%')

            // 正文
            if (this.vm.item.text.length > 0) {
              Text(this.vm.item.text)
                .fontSize(15)
                .fontColor(AppColors.TEXT_PRIMARY)
                .width('100%')
                .lineHeight(22)
            }

            // 图片
            if (this.vm.item.images.length > 0) {
              Grid() {
                ForEach(this.vm.item.images, (img: string) => {
                  GridItem() {
                    Image(img)
                      .width('100%')
                      .aspectRatio(1)
                      .objectFit(ImageFit.Cover)
                      .borderRadius(6)
                  }
                }, (img: string) => img)
              }
              .columnsTemplate('1fr 1fr 1fr')
              .columnsGap(4)
              .rowsGap(4)
              .width('100%')
            }

            // 视频
            if (this.vm.item.kind === DynamicKind.Video && this.vm.item.videoBvid.length > 0) {
              Row({ space: 8 }) {
                Image(this.vm.item.videoCover)
                  .width(120)
                  .height(72)
                  .borderRadius(6)
                  .objectFit(ImageFit.Cover)
                  .alt($r('app.media.startIcon'))
                Column({ space: 4 }) {
                  Text(this.vm.item.videoTitle)
                    .fontSize(14)
                    .fontColor(AppColors.TEXT_PRIMARY)
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(FormatUtils.duration(this.vm.item.videoDuration))
                    .fontSize(11)
                    .fontColor(AppColors.TEXT_SECONDARY)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
              }
              .width('100%')
              .padding(8)
              .backgroundColor(AppColors.CARD_BG)
              .borderRadius(10)
              .onClick(() => {
                const item = this.vm.item;
                if (item !== null && item.videoBvid.length > 0) {
                  Route.push(Route.video, item.videoBvid);
                }
              })
            }

            // 互动条
            Row() {
              Row({ space: 4 }) {
                Text(this.vm.item.isLiked ? '❤️' : '🤍')
                  .fontSize(16)
                Text(`${this.vm.item.likeCount}`)
                  .fontSize(12)
                  .fontColor(this.vm.item.isLiked ? AppColors.BRAND : AppColors.TEXT_SECONDARY)
              }
              .padding({ left: 8, right: 8, top: 6, bottom: 6 })
              .backgroundColor(AppColors.CARD_BG)
              .borderRadius(16)
              .onClick(() => {
                this.vm.toggleLike();
              })
              Text(`${this.vm.item.commentCount}评论`)
                .fontSize(12)
                .fontColor(AppColors.TEXT_SECONDARY)
                .margin({ left: 16 })
              Text(`${this.vm.item.forwardCount}转发`)
                .fontSize(12)
                .fontColor(AppColors.TEXT_SECONDARY)
                .margin({ left: 16 })
            }
            .width('100%')

            if (this.vm.tipText.length > 0) {
              Text(this.vm.tipText)
                .fontSize(12)
                .fontColor(AppColors.BRAND)
                .width('100%')
            }

            // 评论
            if (!this.commentLoaded) {
              Text('加载评论…')
                .fontSize(12)
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

  private loadComment(): void {
    if (this.commentLoaded) {
      return;
    }
    this.commentLoaded = true;
    // 动态评论 type=17，oid 使用字符串动态 id（超出 number 精度）
    this.commentVm.init(17, this.dynId);
  }
}
