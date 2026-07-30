import { AppColors } from '../../theme/AppTheme';

/** 加载中视图 */
@Component
export struct LoadingView {
  tip: string = '加载中…';

  build() {
    Column({ space: 12 }) {
      LoadingProgress()
        .width(40)
        .height(40)
        .color(AppColors.BRAND)
      Text(this.tip)
        .fontSize(13)
        .fontColor(AppColors.TEXT_SECONDARY)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}

/** 错误视图 */
@Component
export struct ErrorView {
  message: string = '加载失败';
  retryable: boolean = true;
  onRetry: () => void = () => {
  };

  build() {
    Column({ space: 12 }) {
      Text('出错了')
        .fontSize(16)
        .fontColor(AppColors.TEXT_PRIMARY)
      Text(this.message)
        .fontSize(13)
        .fontColor(AppColors.TEXT_SECONDARY)
        .textAlign(TextAlign.Center)
      if (this.retryable) {
        Button('点击重试')
          .backgroundColor(AppColors.BRAND)
          .fontColor(Color.White)
          .onClick(() => {
            this.onRetry();
          })
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding(24)
  }
}

/** 空视图 */
@Component
export struct EmptyView {
  tip: string = '暂无内容';

  build() {
    Column({ space: 12 }) {
      Text('这里空空如也')
        .fontSize(16)
        .fontColor(AppColors.TEXT_PRIMARY)
      Text(this.tip)
        .fontSize(13)
        .fontColor(AppColors.TEXT_SECONDARY)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}
