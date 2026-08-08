import { bundleManager, common, ConfigurationConstant } from '@kit.AbilityKit';
import { Result } from '../common/result/Result';
import { AppError } from '../common/result/AppError';
import { Pref } from '../services/storage/Pref';

/**
 * 设置中心 ViewModel（P1 Task 11）
 * 读写 Pref 静态设置项；导入/导出/重置纯逻辑，文件选择/保存由页面完成。
 */
@Observed
export class SettingsViewModel {
  tipText: string = '';
  isBusy: boolean = false;
  /** 应用版本信息（关于） */
  appVersion: string = '1.0.0';

  init(context: common.Context): void {
    this.loadVersion();
  }

  /** 读取应用版本（bundleManager） */
  private async loadVersion(): Promise<void> {
    try {
      const info = await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
      this.appVersion = `${info.versionName} (${info.versionCode})`;
    } catch (e) {
      this.appVersion = '1.0.0';
    }
  }

  // ---------- 播放 ----------

  get defaultQuality(): number {
    return Pref.DEFAULT_QUALITY.get();
  }

  setDefaultQuality(qn: number): void {
    Pref.DEFAULT_QUALITY.put(qn);
  }

  get defaultSpeed(): number {
    return Pref.DEFAULT_SPEED.get();
  }

  setDefaultSpeed(speed: number): void {
    Pref.DEFAULT_SPEED.put(speed);
  }

  get autoPlayNext(): boolean {
    return Pref.AUTO_PLAY_NEXT.get();
  }

  setAutoPlayNext(enabled: boolean): void {
    Pref.AUTO_PLAY_NEXT.put(enabled);
  }

  get danmakuEnabled(): boolean {
    return Pref.DANMAKU_ENABLED.get();
  }

  setDanmakuEnabled(enabled: boolean): void {
    Pref.DANMAKU_ENABLED.put(enabled);
  }

  // ---------- 外观 ----------

  get darkMode(): string {
    return Pref.DARK_MODE.get();
  }

  /** 切换深色模式并立即应用（system/light/dark） */
  setDarkMode(mode: string, context: common.Context): void {
    Pref.DARK_MODE.put(mode);
    this.applyDarkMode(context);
  }

  private applyDarkMode(context: common.Context): void {
    try {
      const mode = this.darkMode;
      let cm = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
      if (mode === 'light') {
        cm = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
      } else if (mode === 'dark') {
        cm = ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
      }
      context.getApplicationContext().setColorMode(cm);
    } catch (e) {
      this.tipText = `应用主题失败：${JSON.stringify(e)}`;
    }
  }

  // ---------- 搜索 ----------

  get searchHistoryEnabled(): boolean {
    return Pref.SEARCH_HISTORY_ENABLED.get();
  }

  setSearchHistoryEnabled(enabled: boolean): void {
    Pref.SEARCH_HISTORY_ENABLED.put(enabled);
  }

  // ---------- 隐私与过滤 ----------

  get filterKeywords(): string {
    return Pref.FILTER_KEYWORDS.get();
  }

  setFilterKeywords(value: string): void {
    Pref.FILTER_KEYWORDS.put(value);
  }

  get filterBlackMids(): string {
    return Pref.FILTER_BLACK_MIDS.get();
  }

  setFilterBlackMids(value: string): void {
    Pref.FILTER_BLACK_MIDS.put(value);
  }

  get filterMinLikeRatio(): number {
    return Pref.FILTER_MIN_LIKE_RATIO.get();
  }

  setFilterMinLikeRatio(value: number): void {
    Pref.FILTER_MIN_LIKE_RATIO.put(value);
  }

  // ---------- 日志 ----------

  get logEnabled(): boolean {
    return Pref.LOG_ENABLED.get();
  }

  setLogEnabled(enabled: boolean): void {
    Pref.LOG_ENABLED.put(enabled);
  }

  // ---------- 导入 / 导出 / 重置 ----------

  /** 导出：生成 JSON 字符串 */
  exportJson(): string {
    return Pref.exportJson();
  }

  /** 导入：解析 JSON 并写回 */
  async importJson(json: string): Promise<Result<boolean>> {
    return await Pref.importJson(json);
  }

  /** 重置全部设置 */
  async resetAll(): Promise<boolean> {
    if (this.isBusy) {
      return false;
    }
    this.isBusy = true;
    const r = await Pref.resetAll();
    this.isBusy = false;
    if (!r.isOk) {
      this.tipText = r.error.message;
      return false;
    }
    this.tipText = '已重置全部设置';
    return true;
  }

  get errorMessage(): string {
    return this.tipText.length > 0 ? this.tipText : AppError.unknown('').message;
  }
}
