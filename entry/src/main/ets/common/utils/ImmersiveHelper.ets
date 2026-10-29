import { deviceInfo } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

/** HDS 组件沉浸光感 syscap（HDS Core since API 20，沉浸材质 since API 23） */
const HDS_SYSCAP = 'SystemCapability.UIDesign.HDSComponent.Core';

/**
 * 沉浸光感能力探测
 *
 * 注意：不能用 sdkApiVersion 单独判断。第三方 OpenHarmony 发行版（如开鸿）
 * 会上报 API 23，但系统并未实现 HDS（@hms:hds.* 缺导出），静态 import
 * @kit.UIDesignKit 会直接抛 SyntaxError 导致启动闪退。
 * 因此以 syscap 为准，并且只有真正加载 HDS 页时才会引用该 kit。
 *
 * 参考：https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ui-design-hds-component-material
 */
export class ImmersiveHelper {
  private static pSupported: boolean = false;
  private static pChecked: boolean = false;

  /** HDS 沉浸光感是否受支持（设备声明 HDS syscap 且 API 23+） */
  static get isHdsSupported(): boolean {
    if (!ImmersiveHelper.pChecked) {
      ImmersiveHelper.checkSupport();
    }
    return ImmersiveHelper.pSupported;
  }

  static checkSupport(): boolean {
    if (ImmersiveHelper.pChecked) {
      return ImmersiveHelper.pSupported;
    }
    let supported = false;
    let apiVersion = 0;
    try {
      apiVersion = deviceInfo.sdkApiVersion;
      supported = canIUse(HDS_SYSCAP) && apiVersion >= 23;
    } catch (e) {
      supported = false;
    }
    ImmersiveHelper.pSupported = supported;
    ImmersiveHelper.pChecked = true;
    hilog.info(0x0000, TAG, 'HDS supported=%{public}s, sdkApi=%{public}d', String(supported), apiVersion);
    return supported;
  }
}

const TAG = ImmersiveHelper.name;
