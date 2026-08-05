import { AccountProfile } from '../models/LoginModels';
import { NavService } from '../common/navigation/NavService';
import { MineViewModel } from '../viewmodel/MineViewModel';
import { AppColors } from '../theme/AppTheme';
import { RouteNames } from './RouteNames';

/**
 * 我的页（Task 4/10）：当前账户、多账户列表与切换、退出登录。
 */
@Component
export struct MinePage {
  @State vm: MineViewModel = new MineViewModel();

  aboutToAppear(): void {
    this.vm.init();
    if (this.vm.isLoggedIn) {
      this.vm.refreshProfile();
    }
  }

  aboutToDisappear(): void {
    this.vm.dispose();
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        // 账户头部
        if (this.vm.isLoggedIn && this.vm.current !== null) {
          Row({ space: 12 }) {
            Image(this.vm.current.face)
              .width(64)
              .height(64)
              .borderRadius(32)
              .alt($r('app.media.startIcon'))
            Column({ space: 4 }) {
              Text(this.vm.current.uname)
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppColors.TEXT_PRIMARY)
              Text(`LV${this.vm.current.level} · mid ${this.vm.current.mid}`)
                .fontSize(12)
                .fontColor(AppColors.TEXT_SECONDARY)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')
          .padding(16)
          .backgroundColor(AppColors.CARD_BG)
          .borderRadius(12)
        } else {
          Column({ space: 12 }) {
            Text('未登录')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.TEXT_PRIMARY)
            Text('登录后可同步关注、收藏、动态')
              .fontSize(13)
              .fontColor(AppColors.TEXT_SECONDARY)
            Button('扫码登录')
              .width(180)
              .backgroundColor(AppColors.BRAND)
              .fontColor(Color.White)
              .onClick(() => {
                NavService.push(RouteNames.LOGIN);
              })
          }
          .width('100%')
          .padding(24)
          .backgroundColor(AppColors.CARD_BG)
          .borderRadius(12)
        }

        // 多账户管理
        if (this.vm.accounts.length > 0) {
          Column({ space: 4 }) {
            Text('账户管理')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.TEXT_SECONDARY)
              .width('100%')
              .margin({ bottom: 4 })
            ForEach(this.vm.accounts, (acc: AccountProfile) => {
              Row({ space: 10 }) {
                Image(acc.face)
                  .width(40)
                  .height(40)
                  .borderRadius(20)
                  .alt($r('app.media.startIcon'))
                Column({ space: 2 }) {
                  Text(acc.uname)
                    .fontSize(15)
                    .fontColor(AppColors.TEXT_PRIMARY)
                  Text(acc.mid === this.vm.current?.mid ? '当前账户' : '点击切换')
                    .fontSize(11)
                    .fontColor(acc.mid === this.vm.current?.mid ? AppColors.BRAND : AppColors.TEXT_SECONDARY)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                Text('退出')
                  .fontSize(12)
                  .fontColor(AppColors.TEXT_SECONDARY)
                  .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                  .borderRadius(10)
                  .border({ width: 1, color: AppColors.DIVIDER })
                  .onClick(() => {
                    this.vm.logout(acc.mid);
                  })
              }
              .width('100%')
              .padding(10)
              .backgroundColor(AppColors.CARD_BG)
              .borderRadius(10)
              .onClick(() => {
                if (acc.mid !== this.vm.current?.mid) {
                  this.vm.switchAccount(acc.mid);
                }
              })
            }, (acc: AccountProfile) => acc.mid)

            Text('+ 添加账户')
              .fontSize(14)
              .fontColor(AppColors.BRAND)
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding(12)
              .backgroundColor(AppColors.CARD_BG)
              .borderRadius(10)
              .onClick(() => {
                NavService.push(RouteNames.LOGIN);
              })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }

        // P2 功能入口（直播/番剧/音乐/收藏/历史/稍后再看/发布动态/话题广场）
        Column({ space: 6 }) {
          Text('功能')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TEXT_SECONDARY)
            .width('100%')
          Grid() {
            ForEach(FEATURE_ENTRIES, (entry: MineFeatureEntry) => {
              GridItem() {
                Column({ space: 4 }) {
                  Text(entry.icon)
                    .fontSize(22)
                  Text(entry.label)
                    .fontSize(12)
                    .fontColor(AppColors.TEXT_PRIMARY)
                }
                .width('100%')
                .padding({ top: 14, bottom: 14 })
                .backgroundColor(AppColors.CARD_BG)
                .borderRadius(10)
                .onClick(() => {
                  NavService.push(entry.route, entry.param);
                })
              }
            }, (entry: MineFeatureEntry) => entry.route)
          }
          .columnsTemplate('1fr 1fr 1fr 1fr')
          .columnsGap(8)
          .rowsGap(8)
          .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        Text('OHB · 鸿蒙第三方 Bilibili 客户端 V1')
          .fontSize(11)
          .fontColor(AppColors.TEXT_SECONDARY)
          .width('100%')
          .textAlign(TextAlign.Center)
          .margin({ top: 8 })
      }
      .width('100%')
      .padding(12)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.PAGE_BG)
  }
}

/** 我的页功能入口 */
interface MineFeatureEntry {
  label: string;
  icon: string;
  route: string;
  param?: Object;
}

const FEATURE_ENTRIES: MineFeatureEntry[] = [
  { label: '直播', icon: '📺', route: RouteNames.LIVE },
  { label: '番剧', icon: '🎬', route: RouteNames.BANGUMI },
  { label: '音乐', icon: '🎵', route: RouteNames.MUSIC },
  { label: '收藏', icon: '⭐', route: RouteNames.FAVORITES },
  { label: '历史', icon: '🕘', route: RouteNames.HISTORY },
  { label: '稍后再看', icon: '▶️', route: RouteNames.WATCH_LATER },
  { label: '发布动态', icon: '✏️', route: RouteNames.PUBLISH_DYNAMIC },
  { label: '话题广场', icon: '🏷️', route: RouteNames.TOPIC }
];
