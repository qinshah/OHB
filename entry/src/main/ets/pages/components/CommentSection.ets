import { DataStatus } from '../../common/state/DataState';
import { FormatUtils } from '../../common/utils/FormatUtils';
import { CommentItem } from '../../models/CommentModels';
import { CommentViewModel } from '../../viewmodel/CommentViewModel';
import { AppColors } from '../../theme/AppTheme';

/**
 * 评论组件（P2 Task 14）：主评论分页、点赞、楼中楼展开、发表评论。
 * 可复用：视频详情（type=1 / oid=aid）、动态详情（type=17 / oid=动态id字符串）。
 */
@Component
export struct CommentSection {
  @ObjectLink vm: CommentViewModel;
  @State inputText: string = '';
  @State replyTarget: CommentItem | null = null;

  build() {
    Column({ space: 8 }) {
      // 标题
      Row() {
        Text('评论')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TEXT_PRIMARY)
        Blank()
        Text(`${this.vm.items.length}条`)
          .fontSize(12)
          .fontColor(AppColors.TEXT_SECONDARY)
      }
      .width('100%')

      // 输入区
      Row({ space: 8 }) {
        TextInput({
          text: $$this.inputText,
          placeholder: this.replyTarget !== null
            ? `回复 ${this.replyTarget.member.uname}`
            : '友善评论，理性发言'
        })
          .layoutWeight(1)
          .height(36)
          .fontSize(13)
          .backgroundColor(AppColors.CARD_BG)
          .borderRadius(18)
          .padding({ left: 14, right: 14 })
          .onSubmit(() => {
            this.submit();
          })
        Button(this.vm.isPosting ? '发送中…' : '发送')
          .height(36)
          .fontSize(13)
          .backgroundColor(AppColors.BRAND)
          .fontColor(Color.White)
          .enabled(!this.vm.isPosting)
          .onClick(() => {
            this.submit();
          })
      }
      .width('100%')

      if (this.replyTarget !== null) {
        Row() {
          Text(`回复 ${this.replyTarget.member.uname}`)
            .fontSize(12)
            .fontColor(AppColors.BRAND)
          Blank()
          Text('取消')
            .fontSize(12)
            .fontColor(AppColors.TEXT_SECONDARY)
            .onClick(() => {
              this.replyTarget = null;
            })
        }
        .width('100%')
      }

      if (this.vm.tipText.length > 0) {
        Text(this.vm.tipText)
          .fontSize(12)
          .fontColor(AppColors.BRAND)
          .width('100%')
      }

      // 状态区
      if (this.vm.state.status === DataStatus.Loading) {
        Row({ space: 8 }) {
          LoadingProgress()
            .width(22)
            .height(22)
            .color(AppColors.BRAND)
          Text('评论加载中…')
            .fontSize(12)
            .fontColor(AppColors.TEXT_SECONDARY)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding(12)
      } else if (this.vm.state.status === DataStatus.Error) {
        Text(this.vm.errorMessage)
          .fontSize(12)
          .fontColor(AppColors.TEXT_SECONDARY)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding(12)
          .onClick(() => {
            this.vm.loadFirst();
          })
      } else if (this.vm.state.status === DataStatus.Empty) {
        Text('还没有评论，快来抢沙发')
          .fontSize(12)
          .fontColor(AppColors.TEXT_SECONDARY)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding(12)
      } else {
        ForEach(this.vm.items, (item: CommentItem) => {
          this.CommentRow(item)
        }, (item: CommentItem) => `${item.rpid}`)

        // 加载更多
        if (!this.vm.isEnd) {
          Text(this.vm.isLoadingMore ? '加载中…' : '加载更多评论')
            .fontSize(12)
            .fontColor(AppColors.TEXT_SECONDARY)
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding(10)
            .onClick(() => {
              this.vm.loadMore();
            })
        }
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: 12, bottom: 12 })
  }

  @Builder
  CommentRow(item: CommentItem) {
    Column({ space: 6 }) {
      Row({ space: 8 }) {
        Image(item.member.avatar)
          .width(32)
          .height(32)
          .borderRadius(16)
          .alt($r('app.media.startIcon'))
        Column({ space: 2 }) {
          Row({ space: 6 }) {
            Text(item.member.uname)
              .fontSize(13)
              .fontColor(AppColors.TEXT_PRIMARY)
              .fontWeight(FontWeight.Medium)
            if (item.member.isUp) {
              Text('UP')
                .fontSize(10)
                .fontColor(Color.White)
                .backgroundColor(AppColors.BRAND)
                .borderRadius(6)
                .padding({ left: 5, right: 5, top: 1, bottom: 1 })
            }
          }
          Text(FormatUtils.relativeTime(item.pubTs))
            .fontSize(11)
            .fontColor(AppColors.TEXT_SECONDARY)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        // 点赞
        Row({ space: 4 }) {
          Text(item.liked === 1 ? '👍' : '👍🏻')
            .fontSize(13)
          Text(`${item.likeCount}`)
            .fontSize(12)
            .fontColor(item.liked === 1 ? AppColors.BRAND : AppColors.TEXT_SECONDARY)
        }
        .padding(6)
        .onClick(() => {
          this.vm.toggleLike(item);
          this.vm.refresh();
        })
      }
      .width('100%')

      Text(item.content)
        .fontSize(14)
        .fontColor(AppColors.TEXT_PRIMARY)
        .width('100%')
        .lineHeight(20)

      // 操作行
      Row({ space: 14 }) {
        Text('回复')
          .fontSize(12)
          .fontColor(AppColors.TEXT_SECONDARY)
          .onClick(() => {
            this.replyTarget = item;
          })
        if (item.replyCount > 0) {
          Text(item.repliesLoaded ? '收起回复' : `${item.replyCount}条回复`)
            .fontSize(12)
            .fontColor(AppColors.TEXT_SECONDARY)
            .onClick(() => {
              if (!item.repliesLoaded) {
                this.vm.loadSubReplies(item);
                this.vm.refresh();
              } else {
                item.repliesLoaded = false;
                this.vm.refresh();
              }
            })
        }
      }
      .width('100%')

      // 楼中楼
      if (item.repliesLoaded) {
        Column({ space: 6 }) {
          ForEach(item.replies, (sub: CommentItem) => {
            Row({ space: 6 }) {
              Text(sub.member.uname)
                .fontSize(12)
                .fontColor(AppColors.TEXT_SECONDARY)
                .maxLines(1)
              Text(sub.content)
                .fontSize(13)
                .fontColor(AppColors.TEXT_PRIMARY)
                .layoutWeight(1)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(`${sub.likeCount}`)
                .fontSize(11)
                .fontColor(sub.liked === 1 ? AppColors.BRAND : AppColors.TEXT_SECONDARY)
                .onClick(() => {
                  this.vm.toggleLike(sub);
                  this.vm.refresh();
                })
            }
            .width('100%')
          }, (sub: CommentItem) => `${sub.rpid}`)
          if (item.replyHasMore) {
            Text('加载更多回复')
              .fontSize(12)
              .fontColor(AppColors.TEXT_SECONDARY)
              .onClick(() => {
                this.vm.loadMoreReplies(item);
                this.vm.refresh();
              })
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 40 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: 10, bottom: 10 })
    .border({ width: { bottom: 1 }, color: AppColors.DIVIDER })
  }

  private async submit(): Promise<void> {
    const text = this.inputText.trim();
    if (text.length === 0) {
      return;
    }
    let root = 0;
    let parent = 0;
    if (this.replyTarget !== null) {
      root = this.replyTarget.rpid;
      parent = this.replyTarget.rpid;
    }
    const ok = await this.vm.postComment(text, root, parent);
    if (ok) {
      this.inputText = '';
      this.replyTarget = null;
    }
  }
}
