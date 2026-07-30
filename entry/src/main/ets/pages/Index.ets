import { HomePage } from './HomePage';
import { SearchPage } from './SearchPage';
import { SearchResultPage } from './SearchResultPage';
import { DynamicPage } from './DynamicPage';
import { MinePage } from './MinePage';
import { LoginPage } from './LoginPage';
import { VideoDetailPage } from './VideoDetailPage';
import { AppColors } from '../theme/AppTheme';
import { RouteNames } from './RouteNames';
import { NavService } from '../common/navigation/NavService';

// Tab配置：标签名称和系统图标资源
const TAB_LABELS: string[] = ['首页', '搜索', '动态', '我的'];
const TAB_ICONS: Resource[] = [
  $r('sys.symbol.house'),
  $r('sys.symbol.magnifyingglass'),
  $r('sys.symbol.bell'),
  $r('sys.symbol.person')
];

/**
 * 应用主框架壳（Task 1/10）
 * Navigation 作为主路由（单栏/分栏自适应基础），Tabs 承载 首页/搜索/动态/我的。
 */
@Entry
@Component
struct Index {
  navStack: NavPathStack = new NavPathStack();
  @State currentTab: number = 0;

  aboutToAppear(): void {
    NavService.register(this.navStack);
  }

  @Builder
  pageMap(name: string, param: Object) {
    if (name === RouteNames.VIDEO_DETAIL) {
      NavDestination() {
        VideoDetailPage({ bvid: param as string })
      }
      .hideTitleBar(true)
    } else if (name === RouteNames.LOGIN) {
      NavDestination() {
        LoginPage()
      }
      .hideTitleBar(true)
    } else if (name === RouteNames.SEARCH_RESULT) {
      NavDestination() {
        SearchResultPage({ keyword: param as string })
      }
      .hideTitleBar(true)
    }
  }

  build() {
    Navigation(this.navStack) {
      Tabs({ barPosition: BarPosition.End, index: this.currentTab }) {
        TabContent() {
          HomePage()
        }
        .tabBar(this.tabItemBuilder(0))

        TabContent() {
          SearchPage()
        }
        .tabBar(this.tabItemBuilder(1))

        TabContent() {
          DynamicPage()
        }
        .tabBar(this.tabItemBuilder(2))

        TabContent() {
          MinePage()
        }
        .tabBar(this.tabItemBuilder(3))
      }
      .barHeight('auto')
      .barBackgroundColor(AppColors.CARD_BG)
      .onChange((idx: number) => {
        this.currentTab = idx;
      })
    }
    .hideTitleBar(true)
    .navDestination(this.pageMap)
    .mode(NavigationMode.Stack)
  }

  @Builder
  tabItemBuilder(index: number) {
    Column({ space: 2 }) {
      SymbolGlyph(TAB_ICONS[index])
        .fontSize(20)
        .fontColor([this.currentTab === index ? AppColors.BRAND : AppColors.TEXT_SECONDARY])
      Text(TAB_LABELS[index])
        .fontSize(10)
        .fontColor(this.currentTab === index ? AppColors.BRAND : AppColors.TEXT_SECONDARY)
    }
  }
}
