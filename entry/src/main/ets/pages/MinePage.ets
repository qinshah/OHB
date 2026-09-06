import { AccountProfile } from '../models/LoginModels';
import { Route } from '../framework/Route';
import { UserSpaceParam } from './RouteParams';
import { MineViewModel } from '../viewmodel/MineViewModel';
import { AppColors } from '../theme/AppTheme';
import { UpdateUtils } from '../common/utils/UpdateUtils';
import { Pref } from '../services/storage/Pref';
import ConfigurationConstant from '@ohos.app.ability.ConfigurationConstant';

/**
 * 我的页（Task 4/10）：参考 B 站原版布局（裁剪广告/推广区块）：
 * - 头部右上角主题色功能图标（扫码登录 / 深浅色切换）
 * - 用户信息卡：头像 / 昵称 / 等级 / B币·硬币 / 空间入口
 * - 统计行：动态 · 关注 · 粉丝
 * - 功能宫格：历史记录 / 我的收藏 / 稍后再看
 * - 账号管理（多账户切换）→ 检查更新 → 设置
 */
@Component
export struct MinePage {
  @State vm: MineViewModel = new MineViewModel();
  /** 当前深色模式（驱动头部日/月图标切换） */
  @State isDark: boolean = false;

  aboutToAppear(): void {
    this.vm.init();
    this.isDark = Pref.colorMode.get() === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    if (this.vm.isLoggedIn) {
      this.vm.refreshProfile();
    }
  }

  aboutToDisappear(): void {
    this.vm.dispose();
  }

  /** 深浅色切换：写入 colorMode 偏好，应用级立即生效 */
  private toggleColorMode(): void {
    const next: number = this.isDark
      ? ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
      : ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    Pref.colorMode.put(next);
    this.isDark = !this.isDark;
  }

  /** 统计列（关注/粉丝未拉取到时显示 —） */
  @Builder
  StatColumn(value: string, labelRes: Resource) {
    Column({ space: 2 }) {
      Text(value)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TEXT_PRIMARY)
      Text(labelRes)
        .fontSize(12)
        .fontColor(AppColors.TEXT_SECONDARY)
    }
    .layoutWeight(1)
  }

  /** 功能宫格项（图标用 B 站原版蓝色） */
  @Builder
  FeatureItem(icon: Resource, labelRes: Resource, onTap: () => void) {
    Column({ space: 6 }) {
      SymbolGlyph(icon)
        .fontSize(26)
        .fontColor([MINE_ICON_BLUE])
      Text(labelRes)
        .fontSize(12)
        .fontColor(AppColors.TEXT_PRIMARY)
    }
    // layoutWeight(1)：Row 内三等分（width('100%') 会撑满整行把后两项挤出屏幕）
    .layoutWeight(1)
    .padding({ top: 16, bottom: 16 })
    .backgroundColor(AppColors.CARD_BG)
    .borderRadius(12)
    .onClick(() => {
      onTap();
    })
  }

  /** 通用设置行（左侧图标 + 文案 + 右箭头） */
  @Builder
  SettingRow(icon: Resource, labelRes: Resource, onTap: () => void) {
    Row({ space: 10 }) {
      SymbolGlyph(icon)
        .fontSize(18)
        .fontColor([MINE_ICON_BLUE])
      Text(labelRes)
        .fontSize(14)
        .fontColor(AppColors.TEXT_PRIMARY)
      Blank()
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(16)
        .fontColor([AppColors.TEXT_SECONDARY])
    }
    .width('100%')
    .padding(14)
    .backgroundColor(AppColors.CARD_BG)
    .borderRadius(12)
    .onClick(() => {
      onTap();
    })
  }

  build() {
    Scroll() {
      Column() {
        // 头部右上角功能图标（主题色）：扫码登录 + 深浅色切换
        Row({ space: 18 }) {
          Blank()
          // 扫码登录：已登录时也保留（可加新账号）
          SymbolGlyph($r('sys.symbol.qrcode'))
            .fontSize(22)
            .fontColor([AppColors.BRAND])
            .onClick(() => {
              Route.push(Route.login);
            })
          SymbolGlyph(this.isDark ? $r('sys.symbol.sun_max') : $r('sys.symbol.moon'))
            .fontSize(22)
            .fontColor([AppColors.BRAND])
            .onClick(() => {
              this.toggleColorMode();
            })
        }
        .width('100%')
        .padding({ top: 8, bottom: 8, right: 16 })

        // 用户信息卡
        if (this.vm.isLoggedIn && this.vm.current !== null) {
          Row({ space: 12 }) {
            Image(this.vm.current.face)
              .width(64)
              .height(64)
              .borderRadius(32)
              .alt($r('app.media.startIcon'))
            Column({ space: 4 }) {
              Row({ space: 6 }) {
                Text(this.vm.current.uname)
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(AppColors.TEXT_PRIMARY)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                // 等级徽章
                Text(`LV${this.vm.current.level}`)
                  .fontSize(10)
                  .fontColor(AppColors.BRAND)
                  .padding({ left: 6, right: 6, top: 1, bottom: 1 })
                  .borderRadius(6)
                  .backgroundColor('#1AFB7299')
              }
              // B币 / 硬币
              Row({ space: 10 }) {
                Text($r('app.string.mine_bcoin'))
                  .fontSize(12)
                  .fontColor(AppColors.TEXT_SECONDARY)
                Text(`${this.vm.current.money}`)
                  .fontSize(12)
                  .fontColor(AppColors.TEXT_PRIMARY)
                Text($r('app.string.mine_coin'))
                  .fontSize(12)
                  .fontColor(AppColors.TEXT_SECONDARY)
                Text(`${this.vm.current.coin}`)
                  .fontSize(12)
                  .fontColor(AppColors.TEXT_PRIMARY)
              }
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            // 空间入口
            Row({ space: 2 }) {
              Text($r('app.string.mine_space'))
                .fontSize(13)
                .fontColor(AppColors.TEXT_SECONDARY)
              SymbolGlyph($r('sys.symbol.chevron_right'))
                .fontSize(12)
                .fontColor([AppColors.TEXT_SECONDARY])
            }
            .onClick(() => {
              const param: UserSpaceParam = { mid: Number(this.vm.current?.mid ?? 0) };
              Route.push(Route.userSpace, param);
            })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        } else {
          Column({ space: 12 }) {
            Text($r('app.string.mine_not_logged_in'))
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.TEXT_PRIMARY)
            Text($r('app.string.mine_login_hint'))
              .fontSize(13)
              .fontColor(AppColors.TEXT_SECONDARY)
            Button($r('app.string.mine_scan_login'))
              .width(180)
              .backgroundColor(AppColors.BRAND)
              .fontColor(Color.White)
              .onClick(() => {
                Route.push(Route.login);
              })
          }
          .width('100%')
          .padding(24)
          .backgroundColor(AppColors.CARD_BG)
          .borderRadius(12)
        }

        // 统计行：动态 / 关注 / 粉丝（未获取显示 —）
        Row() {
          this.StatColumn('—', $r('app.string.mine_stat_dynamic'))
          this.StatColumn(this.vm.following >= 0 ? `${this.vm.following}` : '—',
            $r('app.string.mine_stat_following'))
          this.StatColumn(this.vm.follower >= 0 ? `${this.vm.follower}` : '—',
            $r('app.string.mine_stat_follower'))
        }
        .width('100%')
        .padding({ top: 14, bottom: 14 })
        .backgroundColor(AppColors.CARD_BG)
        .borderRadius(12)
        .margin({ top: 12 })

        // 功能宫格：历史记录 / 我的收藏 / 稍后再看
        Row({ space: 8 }) {
          this.FeatureItem($r('sys.symbol.clock_arrow_2_circlepath'),
            $r('app.string.mine_entry_history'), (): void => {
              Route.push(Route.history);
            })
          this.FeatureItem($r('sys.symbol.star'), $r('app.string.mine_entry_favorites'), (): void => {
            Route.push(Route.favorites);
          })
          this.FeatureItem($r('sys.symbol.clock'), $r('app.string.mine_entry_watch_later'), (): void => {
            Route.push(Route.watchLater);
          })
        }
        .width('100%')
        .margin({ top: 12 })

        // 账号管理（多账户切换 / 添加账户）
        if (this.vm.accounts.length > 0) {
          Column({ space: 8 }) {
            Text($r('app.string.mine_section_accounts'))
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.TEXT_SECONDARY)
              .width('100%')
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
                  Text(acc.mid === this.vm.current?.mid
                    ? $r('app.string.mine_current_account')
                    : $r('app.string.mine_switch_hint'))
                    .fontSize(11)
                    .fontColor(acc.mid === this.vm.current?.mid ? AppColors.BRAND : AppColors.TEXT_SECONDARY)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                Text($r('app.string.mine_logout'))
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

            Row({ space: 2 }) {
              Text($r('app.string.mine_add_account'))
                .fontSize(14)
                .fontColor(AppColors.BRAND)
              SymbolGlyph($r('sys.symbol.plus'))
                .fontSize(12)
                .fontColor([AppColors.BRAND])
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .padding(12)
            .backgroundColor(AppColors.CARD_BG)
            .borderRadius(10)
            .onClick(() => {
              Route.push(Route.login);
            })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .margin({ top: 16 })
        }

        // 检查更新 / 设置（文字左侧带蓝色图标，对齐 B 站"更多服务"样式）
        Column({ space: 8 }) {
          this.SettingRow($r('sys.symbol.arrow_down_circle'), $r('app.string.mine_check_update'), (): void => {
            // 手动检查：有结果提示（已是最新 / 失败 / 发现新版本弹窗）
            UpdateUtils.checkUpdate(false);
          })
          this.SettingRow($r('sys.symbol.gearshape'), $r('app.string.mine_settings'), (): void => {
            Route.push(Route.settings);
          })
        }
        .width('100%')
        .margin({ top: 16 })

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
    .align(Alignment.TopStart)
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.PAGE_BG)
    .scrollBar(BarState.Off)
  }
}

// B 站原版"我的"页功能图标蓝（对齐截图宫格/更多服务图标色）
const MINE_ICON_BLUE: string = '#5090F2';
