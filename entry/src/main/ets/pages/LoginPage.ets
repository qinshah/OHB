import { LoginViewModel } from '../viewmodel/LoginViewModel';
import { Route } from '../framework/Route';
import { AppColors } from '../theme/AppTheme';

/**
 * 扫码登录页（Task 4）：二维码 + 轮询状态机 + 过期刷新。
 */
@Component
export struct LoginPage {
  @State vm: LoginViewModel = new LoginViewModel();

  aboutToAppear(): void {
    this.vm.setOnSuccess(() => {
      // 登录成功稍作停留后返回
      setTimeout(() => {
        Route.pop();
      }, 800);
    });
    this.vm.start();
  }

  aboutToDisappear(): void {
    this.vm.dispose();
  }

  build() {
    NavDestination() {
      Column({ space: 20 }) {
        // 二维码区域
        Column({ space: 16 }) {
          if (this.vm.isLoadingQr) {
            Column({ space: 12 }) {
              LoadingProgress()
                .width(40)
                .height(40)
                .color(AppColors.BRAND)
              Text('正在获取二维码…')
                .fontSize(13)
                .fontColor(AppColors.TEXT_SECONDARY)
            }
            .width(220)
            .height(220)
            .justifyContent(FlexAlign.Center)
          } else if (this.vm.qrUrl.length > 0) {
            Stack() {
              QRCode(this.vm.qrUrl)
                .width(220)
                .height(220)
                .backgroundColor(Color.White)
                .padding(8)
                .borderRadius(12)
              if (this.vm.isExpired) {
                Column() {
                  Text('已过期')
                    .fontSize(14)
                    .fontColor(Color.White)
                }
                .width(220)
                .height(220)
                .backgroundColor('#B3000000')
                .justifyContent(FlexAlign.Center)
                .borderRadius(12)
                .onClick(() => {
                  this.vm.start();
                })
              }
            }
          } else {
            Column({ space: 12 }) {
              Text(this.vm.errorText.length > 0 ? this.vm.errorText : '获取失败')
                .fontSize(13)
                .fontColor(AppColors.TEXT_SECONDARY)
              Button('重试')
                .backgroundColor(AppColors.BRAND)
                .fontColor(Color.White)
                .onClick(() => {
                  this.vm.start();
                })
            }
            .width(220)
            .height(220)
            .justifyContent(FlexAlign.Center)
          }

          // 状态与倒计时
          Text(this.vm.statusText)
            .fontSize(14)
            .fontColor(this.vm.isSuccess ? AppColors.BRAND : AppColors.TEXT_PRIMARY)
            .textAlign(TextAlign.Center)
          if (!this.vm.isLoadingQr && !this.vm.isSuccess && this.vm.countdown > 0) {
            Text(`二维码有效期 ${this.vm.countdown}s`)
              .fontSize(12)
              .fontColor(AppColors.TEXT_SECONDARY)
          }
          if (this.vm.isExpired) {
            Button('刷新二维码')
              .backgroundColor(AppColors.BRAND)
              .fontColor(Color.White)
              .onClick(() => {
                this.vm.start();
              })
          }

          Text('打开哔哩哔哩 App → 我的 → 扫一扫')
            .fontSize(12)
            .fontColor(AppColors.TEXT_SECONDARY)
            .margin({ top: 8 })
        }
        .width('100%')
        .padding(16)
        .backgroundColor(AppColors.CARD_BG)
        .borderRadius(16)
        .margin({ left: 24, right: 24 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppColors.PAGE_BG)
    }
    .title('扫码登录')
  }
}
