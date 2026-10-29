import { HdsAnimationMode, HdsNavigation, HdsTabs, HdsTabsController, hdsMaterial } from '@kit.UIDesignKit';
import { SymbolGlyphModifier } from '@kit.ArkUI';
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

/** HDS 底部页签项配置 */
interface HdsTabItem {
  label: ResourceStr;
  normalIcon: SymbolGlyphModifier;
  selectedIcon: SymbolGlyphModifier;
}

/**
 * 应用主框架壳（HDS 沉浸光感版）
 *
 * 仅当 ImmersiveHelper.isHdsSupported 为 true 时由 EntryAbility 加载；
 * 本文件是唯一静态引用 @kit.UIDesignKit 的启动入口，因此未实现 HDS 的
 * 设备（开鸿等）不会加载到它，也就不会触发模块链接期 SyntaxError。
 */
@Entry
@Component
export struct HdsIndex {
  @StorageProp(winUtils.topRectHeight) topRectHeight: number = 0
  @StorageProp(winUtils.bottomRectHeight) bottomRectHeight: number = 0
  navStack: NavPathStack = new NavPathStack();
  @Provide(IndexViewModel.name) vm: IndexViewModel = IndexViewModel.instance;
  private cntlr: HdsTabsController = new HdsTabsController();
  private hdsTabs: HdsTabItem[] = TAB_LABELS.map((label: ResourceStr, index: number): HdsTabItem => {
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
    // 启动时自动检查一次更新（失败静默，不打扰用户）
    UpdateUtils.checkUpdate(true);
    // 列表滚动驱动底部栏收起/展开（仅 HDS 页具备此能力）
    this.vm.setTabAnimator((show: boolean) => {
      if (show) {
        this.cntlr.applyShowAnimation(HdsAnimationMode.SCROLL_ANIMATION)
      } else {
        this.cntlr.applyHideAnimation(HdsAnimationMode.SCROLL_ANIMATION)
      }
    });
  }

  aboutToDisappear(): void {
    this.vm.setTabAnimator(undefined);
  }

  @Builder
  routeBuilder(name: string, param: Object) {
    Route.get(name)?.builder(param)
  }

  build() {
    Column() {
      HdsNavigation(this.navStack) {
        HdsTabs({ controller: this.cntlr }) {
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
          }, (_item: HdsTabItem, index: number) => index.toString(),)
        }
        .barOverlap(true)
        .barPosition(BarPosition.End)
        // 禁用滑动切换子页面：左右滑动手势让给首页内部分区 tabs
        .scrollable(false)
        .barFloatingStyle({
          adaptToHandedness: true,
          barBottomMargin: this.bottomRectHeight / 2,
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
      .padding({ top: this.topRectHeight })
      .hideTitleBar(true)
      .navDestination(this.routeBuilder)
      .mode(NavigationMode.Stack)
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
  }
}
