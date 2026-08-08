import { common } from '@kit.AbilityKit';
import { Logger } from '../common/utils/Logger';

/**
 * 应用主题（AP-6）：品牌色与语义色。
 *
 * 踩坑记录：$r 资源引用只能在组件（@Component）上下文中解析，
 * 写在普通类的静态字段里会在运行期解析失败（ResourceManager ref id not found），
 * 导致使用它的页面渲染中断（白屏）。因此默认内联十六进制；
 * 深/浅色通过 AppColors.refresh() 在启动与配置变更时用 resourceManager 按当前主题解析。
 */
export class AppColors {
  static BRAND: ResourceColor = '#FB7299';
  static PAGE_BG: ResourceColor = '#F4F5F7';
  static CARD_BG: ResourceColor = '#FFFFFF';
  static TEXT_PRIMARY: ResourceColor = '#18191C';
  static TEXT_SECONDARY: ResourceColor = '#9499A0';
  static DIVIDER: ResourceColor = '#E3E5E7';

  /** 按当前系统主题（深/浅色）从 resources 解析语义色 */
  static refresh(context: common.Context): void {
    try {
      const rm = context.resourceManager;
      AppColors.BRAND = rm.getColorByNameSync('brand');
      AppColors.PAGE_BG = rm.getColorByNameSync('page_bg');
      AppColors.CARD_BG = rm.getColorByNameSync('card_bg');
      AppColors.TEXT_PRIMARY = rm.getColorByNameSync('text_primary');
      AppColors.TEXT_SECONDARY = rm.getColorByNameSync('text_secondary');
      AppColors.DIVIDER = rm.getColorByNameSync('divider');
    } catch (e) {
      Logger.error('Theme', `refresh colors fail: ${JSON.stringify(e)}`);
    }
  }
}