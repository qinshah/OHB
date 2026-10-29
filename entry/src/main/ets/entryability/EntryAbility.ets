import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { AccountManager } from '../services/account/AccountManager';
import { DisplayHelper } from '../common/utils/DisplayHelper';
import { ImmersiveHelper } from '../common/utils/ImmersiveHelper';
import { SystemAudioHelper } from '../common/utils/SystemAudioHelper';
import { WinUtil } from '../services/appearance/WinUtils';
import { WindowTestHook } from '../services/appearance/WindowTestHook';
import { ContextUtil } from '../common/utils/ContextUtil';
import BuildProfile from 'BuildProfile';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // 初始化ContextUtil
    ContextUtil.init(this.context);
    // 初始化多用户与认证框架（Cookie 持久化 + 登录态恢复，AP-5）
    AccountManager.getInstance().init(this.context);
    // 初始化系统音量调节与监听（AudioKit）
    SystemAudioHelper.init();
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    // 缓存主窗口实例给 DisplayHelper（路由感知全屏/方向管理）
    DisplayHelper.init(this.context);

    // HDS 组件为 HMS 能力，部分 OpenHarmony 发行版（开鸿等）未实现，
    // 此时绝不能加载静态引用 @kit.UIDesignKit 的页面
    const page = EntryAbility.pickShell(this.launchWant);
    hilog.info(DOMAIN, 'EntryAbility', 'shell=%{public}s hds=%{public}s',
      page, `${ImmersiveHelper.isHdsSupported}`);
    windowStage.loadContent(page, (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
      // 内容加载后才可取 UIContext：在此开始监听窗口尺寸/安全区
      WinUtil.init(windowStage);
      // 调试构建：按启动参数把窗口调整到目标尺寸（发布构建忽略）
      WindowTestHook.apply(this.launchWant, windowStage);
    });
  }

  /**
   * 选择入口壳：默认按 HDS syscap 判定；调试构建可用 `--ps ohbShell index|hds` 强制，
   * 以便在同一台设备上对两套壳跑同一份尺寸矩阵。
   */
  private static pickShell(want: Want): string {
    const forced = BuildProfile.DEBUG ? String(want.parameters?.['ohbShell'] ?? '') : '';
    if (forced === 'index') {
      return 'pages/Index';
    }
    if (forced === 'hds') {
      return 'pages/HdsIndex';
    }
    return ImmersiveHelper.isHdsSupported ? 'pages/HdsIndex' : 'pages/Index';
  }

  onWindowStageDestroy(): void {    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
