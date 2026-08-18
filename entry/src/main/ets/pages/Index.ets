import { HdsNavigation, HdsTabs, HdsTabsController, hdsMaterial, HdsAnimationMode } from '@kit.UIDesignKit';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import { HomePage } from './HomePage';
import { DynamicPage } from './DynamicPage';
import { MinePage } from './MinePage';
import { AppColors } from '../theme/AppTheme';
import { Route } from '../framework/Route';
import { ImmersiveHelper } from '../common/utils/ImmersiveHelper';
import { winUtils } from '../services/appearance/WinUtils';
import { IndexViewModel } from '../viewmodel/IndexViewModel';

// Tab 配置：标签名称和系统图标资源
const TAB_LABELS: string[] = ['首页', '动态', '我的'];
const TAB_ICONS: Resource[] = [
  $r('sys.symbol.house'),
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
 * - barOverlap(true) 让内容延伸至导航栏下方，透过半透明材质显现沉浸效果
 *
 * 参考：https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ui-design-hds-component-material
 *
 * 兼容回退（API < 23）：使用普通 Navigation + Tabs + 不透明背景色
 */
@Entry
@Component
struct Index {
  @StorageProp(winUtils.topRectHeight) topRectHeight: number = 0
  @StorageProp(winUtils.bottomRectHeight) bottomRectHeight: number = 0
  navStack: NavPathStack = new NavPathStack();
  @Provide(IndexViewModel.name) vm: IndexViewModel = IndexViewModel.instance;
  private useHdsTabs: boolean = ImmersiveHelper.isHdsSupported;
  private hdsTabs: HdsTabItem[] = TAB_LABELS.map((label: string, index: number): HdsTabItem => {
    return {
      label: label,
      normalIcon: new SymbolGlyphModifier(TAB_ICONS[index])
        .fontColor([AppColors.TEXT_SECONDARY]),
      selectedIcon: new SymbolGlyphModifier(TAB_ICONS[index])
        .fontColor([AppColors.BRAND]),
    };
  });

  aboutToAppear(): void {
    Route.register(this.navStack);
  }

  @Builder
  routeBuilder(name: string, param: Object) {
    NavDestination() {
      Route.get(name)?.builder(param)
    }
    .hideTitleBar(true)
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
   * 配置 hdsMaterial 类型 + 等级，系统自适应沉浸材质。
   */
  @Builder
  buildHdsNavigation() {
    HdsNavigation(this.navStack) {
      HdsTabs({ controller: this.vm.cntlr }) {
        ForEach(this.hdsTabs, (item: HdsTabItem, index: number) => {
          TabContent() {
            if (index === 0) {
              HomePage()
            } else if (index === 1) {
              DynamicPage()
            } else if (index === 2) {
              MinePage()
            }
          }
          .tabBar(
            new BottomTabBarStyle({ normal: item.normalIcon, selected: item.selectedIcon }, item.label)
              .labelStyle({
                unselectedColor: AppColors.TEXT_SECONDARY,
                selectedColor: AppColors.BRAND
              })
          )
        }, (item: HdsTabItem) => item.label,)
      }
      .barOverlap(true)
      .barPosition(BarPosition.End)
      .barFloatingStyle({
        adaptToHandedness: true,
        barBottomMargin: this.bottomRectHeight / 2,
        // lightColor: AppColors.BRAND,
        gradientMask: { maskColor: Color.Transparent },
        // 沉浸光感：类型 + 等级，系统根据设备算力自适应调整材质效果
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.EXQUISITE
        }
      })
      .onChange((idx: number) => {
        this.vm.idx = idx;
      })
    }
    .onAreaChange((_old: Area, area: Area) => {
      this.vm.areaWidth = Number(area.width) / 1;
    })
    .padding({ top: this.topRectHeight })
    .hideTitleBar(true)
    .navDestination(this.routeBuilder)
    .mode(NavigationMode.Stack)
  }

  /**
   * 普通底部导航栏（API < 23 回退）
   */
  @Builder
  buildNormalNavigation() {
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
