import { Route } from '../framework/Route';
import { PublishDynamicViewModel } from '../player/PublishDynamicViewModel';
import { AppColors } from '../theme/AppTheme';

/**
 * 发布动态页（P2 Task 18）：纯文字动态发布。
 */
@Component
export struct PublishDynamicPage {
  @State vm: PublishDynamicViewModel = new PublishDynamicViewModel();
  @State content: string = '';

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
        Text('发布动态')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY)
          .layoutWeight(1)
        Button(this.vm.isPublishing ? '发布中…' : '发布')
          .height(32)
          .fontSize(13)
          .backgroundColor(AppColors.BRAND)
          .fontColor(Color.White)
          .enabled(!this.vm.isPublishing)
          .onClick(() => {
            this.publish();
          })
      }
      .width('100%')
      .padding({ left: 8, right: 12, top: 8, bottom: 8 })

      TextArea({ text: $$this.content, placeholder: '分享新鲜事…' })
        .width('100%')
        .height(220)
        .fontSize(15)
        .backgroundColor(AppColors.CARD_BG)
        .borderRadius(10)
        .padding(12)
        .margin({ left: 12, right: 12 })

      Text(`${this.content.length} / 1000`)
        .fontSize(11)
        .fontColor(AppColors.TEXT_SECONDARY)
        .width('100%')
        .textAlign(TextAlign.End)
        .padding({ left: 16, right: 16, top: 4 })

      if (this.vm.tipText.length > 0) {
        Text(this.vm.tipText)
          .fontSize(13)
          .fontColor(this.vm.isSuccess ? AppColors.BRAND : AppColors.BRAND)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding(12)
      }

      if (this.vm.isSuccess) {
        Button('返回')
          .width(160)
          .backgroundColor(AppColors.CARD_BG)
          .fontColor(AppColors.TEXT_PRIMARY)
          .onClick(() => {
            Route.pop();
          })
      }

      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.PAGE_BG)
    .alignItems(HorizontalAlign.Start)
  }

  private async publish(): Promise<void> {
    const ok = await this.vm.publish(this.content);
    if (ok) {
      this.content = '';
    }
  }
}
