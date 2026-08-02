import { deviceInfo } from '@kit.BasicServicesKit';
import { Logger } from './Logger';

/**
 * 沉浸光感辅助工具
 *
 * HDS 组件沉浸光感材质能力 since 6.1.0(23)：
 * - HdsTabs 通过 barFloatingStyle.systemMaterialEffect 设置沉浸光感
 * - hdsMaterial.MaterialType.ADAPTIVE + MaterialLevel.ADAPTIVE 系统自适应
 * - 系统根据设备算力动态调整材质效果，实现性能与显示效果的最佳平衡
 *
 * 参考：https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ui-design-hds-component-material
 *
 * 兼容回退：API < 23 时 isHdsSupported 返回 false，UI 使用普通 Navigation + Tabs 回退。
 */
export class ImmersiveHelper {
  private static pSupported: boolean = false;
  private static pChecked: boolean = false;

  /** HDS 沉浸光感是否受支持（API 23+，HarmonyOS 6.1.0+） */
  static get isHdsSupported(): boolean {
    if (!ImmersiveHelper.pChecked) {
      ImmersiveHelper.checkSupport();
    }
    return ImmersiveHelper.pSupported;
  }

  /** 检测设备 HDS 沉浸光感支持情况 */
  static checkSupport(): boolean {
    if (ImmersiveHelper.pChecked) {
      return ImmersiveHelper.pSupported;
    }
    try {
      // HDS 组件沉浸光感材质能力 since 6.1.0(23)
      ImmersiveHelper.pSupported = deviceInfo.sdkApiVersion >= 23;
    } catch (e) {
      ImmersiveHelper.pSupported = false;
    }
    ImmersiveHelper.pChecked = true;
    Logger.info('Immersive', `HDS supported=${ImmersiveHelper.pSupported}, sdkApi=${deviceInfo.sdkApiVersion}`);
    return ImmersiveHelper.pSupported;
  }
}
