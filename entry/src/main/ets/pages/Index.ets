import { HdsNavigation, HdsTabs, HdsTabsController, hdsMaterial } from '@kit.UIDesignKit';
import { SymbolGlyphModifier } from '@kit.ArkUI';
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
import { ImmersiveHelper } from '../common/utils/ImmersiveHelper';

// Tab 配置：标签名称和系统图标资源
const TAB_LABELS: string[] = ['首页', '搜索', '动态', '我的'];
const TAB_ICONS: Resource[] = [
  $r('sys.symbol.house'),
  $r('sys.symbol.magnifyingglass'),
  $r('sys.symbol.bell'),
  $r('sys.symbol.person')
];

/** HDS 底部页签项配置 */
interface HdsTabItem {
  label: string;
  normalIcon: SymbolGlyphModifier;
  selectedIcon: SymbolGlyphModifier;
}

/**
 * 应用主框架壳
 * Navigation 作为主路由（单栏/分栏自适应基础），Tabs 承载 首页/搜索/动态/我的。
 *
 * 沉浸光感（API 23+ / HarmonyOS 6.1.0+）：
 * - 使用 HdsNavigation + HdsTabs HDS 组件
 * - barFloatingStyle.systemMaterialEffect 配置 hdsMaterial 自适应沉浸材质
 * - 系统根据设备算力动态调整材质效果，实现性能与显示效果的最佳平衡
 * - barOverlap(true) 让内容延伸至导航栏下方，透过半透明材质显现沉浸效果
 *
 * 参考：https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ui-design-hds-component-material
 *
 * 兼容回退（API < 23）：使用普通 Navigation + Tabs + 不透明背景色
 */
@Entry
@Component
struct Index {
  navStack: NavPathStack = new NavPathStack();
  @State currentTab: number = 0;
  private useHdsTabs: boolean = false;
  private hdsController: HdsTabsController = new HdsTabsController();
  private hdsTabs: HdsTabItem[] = [];

  aboutToAppear(): void {
    NavService.register(this.navStack);
    this.useHdsTabs = ImmersiveHelper.isHdsSupported;
    // 构建 HDS 页签配置：SymbolGlyphModifier 控制图标与选中/未选中颜色
    this.hdsTabs = TAB_LABELS.map((label: string, index: number): HdsTabItem => {
      return {
        label: label,
        normalIcon: new SymbolGlyphModifier(TAB_ICONS[index])
          .fontColor([AppColors.TEXT_SECONDARY]),
        selectedIcon: new SymbolGlyphModifier(TAB_ICONS[index])
          .fontColor([AppColors.BRAND]),
      };
    });
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
    if (this.useHdsTabs) {
      this.buildHdsNavigation()
    } else {
      this.buildNormalNavigation()
    }
  }

  /**
   * 沉浸光感底部导航栏（API 23+，HarmonyOS 6.1.0+）
   * HdsNavigation + HdsTabs，通过 barFloatingStyle.systemMaterialEffect
   * 配置 hdsMaterial ADAPTIVE 类型 + ADAPTIVE 等级，系统自适应沉浸材质。
   */
  @Builder
  buildHdsNavigation() {
    HdsNavigation(this.navStack) {
      HdsTabs({ controller: this.hdsController }) {
        ForEach(this.hdsTabs, (item: HdsTabItem, index: number) => {
          TabContent() {
            if (index === 0) {
              HomePage()
            } else if (index === 1) {
              SearchPage()
            } else if (index === 2) {
              DynamicPage()
            } else {
              MinePage()
            }
          }
          .tabBar(new BottomTabBarStyle({
            normal: item.normalIcon,
            selected: item.selectedIcon
          }, item.label))
        }, (item: HdsTabItem) => item.label)
      }
      .barOverlap(true)
      .barPosition(BarPosition.End)
      .barFloatingStyle({
        barBottomMargin: 0,
        // 沉浸光感：ADAPTIVE 类型 + ADAPTIVE 等级，系统根据设备算力自适应调整材质效果
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        }
      })
      .onChange((idx: number) => {
        this.currentTab = idx;
      })
    }
    .hideTitleBar(true)
    .navDestination(this.pageMap)
    .mode(NavigationMode.Stack)
  }

  /**
   * 普通底部导航栏（API < 23 回退）
   */
  @Builder
  buildNormalNavigation() {
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
