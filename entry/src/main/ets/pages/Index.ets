import { HomePage } from './HomePage';
import { DynamicPage } from './DynamicPage';
import { MinePage } from './MinePage';
import { AppColors } from '../theme/AppTheme';
import { Route } from '../framework/Route';
import { UpdateUtils } from '../common/utils/UpdateUtils';
import { winUtils } from '../services/appearance/WinUtils';
import { IndexViewModel } from '../viewmodel/IndexViewModel';

// Tab 配置：标签文案和系统图标资源
const TAB_LABELS: ResourceStr[] = [
  $r('app.string.main_tab_home'),
  $r('app.string.main_tab_dynamic'),
  $r('app.string.main_tab_mine')
];
const TAB_ICONS: Resource[] = [
  $r('sys.symbol.house'),
  $r('sys.symbol.bell'),
  $r('sys.symbol.person')
];

/**
 * 应用主框架壳（不含 HDS 的通用回退实现）
 *
 * 设备支持 HDS 沉浸光感时由 EntryAbility 加载 pages/HdsIndex；
 * 其余设备（含开鸿等未实现 @hms:hds.* 的 OpenHarmony 发行版）走本页，
 * 保证启动链路上不出现 @kit.UIDesignKit 的静态 import。
 */
@Entry
@Component
struct Index {
  @StorageProp(winUtils.topRectHeight) topRectHeight: number = 0
  @StorageProp(winUtils.bottomRectHeight) bottomRectHeight: number = 0
  navStack: NavPathStack = new NavPathStack();
  @Provide(IndexViewModel.name) vm: IndexViewModel = IndexViewModel.instance;

  aboutToAppear(): void {
    Route.register(this.navStack);
    // 启动时自动检查一次更新（失败静默，不打扰用户）
    UpdateUtils.checkUpdate(true);
  }

  @Builder
  routeBuilder(name: string, param: Object) {
    Route.get(name)?.builder(param)
  }

  build() {
    Navigation(this.navStack) {
      Tabs({ barPosition: BarPosition.End, index: this.vm.idx }) {
        TabContent() {
          HomePage()
        }
        .tabBar(this.tabItemBuilder(0))

        TabContent() {
          DynamicPage()
        }
        .tabBar(this.tabItemBuilder(1))

        TabContent() {
          MinePage()
        }
        .tabBar(this.tabItemBuilder(2))
      }
      .barHeight('auto')
      .barBackgroundColor(AppColors.CARD_BG)
      // 禁用滑动切换子页面：左右滑动手势让给首页内部分区 tabs
      .scrollable(false)
      .onChange((idx: number) => {
        this.vm.idx = idx;
      })
    }
    .hideTitleBar(true)
    .navDestination(this.routeBuilder)
    .mode(NavigationMode.Stack)
  }

  @Builder
  tabItemBuilder(index: number) {
    Column({ space: 2 }) {
      SymbolGlyph(TAB_ICONS[index])
        .fontSize(20)
        .fontColor([this.vm.idx === index ? AppColors.BRAND : AppColors.TEXT_SECONDARY])
      Text(TAB_LABELS[index])
        .fontSize(10)
        .fontColor(this.vm.idx === index ? AppColors.BRAND : AppColors.TEXT_SECONDARY)
    }
  }
}
