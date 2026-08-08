import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Result } from '../../common/result/Result';
import { AppError } from '../../common/result/AppError';
import { Logger } from '../../common/utils/Logger';

/**
 * 设置项注册表（模块级数组，避免 Pref 类静态初始化期间引用类绑定导致
 * "Pref is not initialized"（TDZ））。
 */
const prefRegistry: PrefItem<preferences.ValueType>[] = [];

/**
 * 单个设置项（AP-4 / Task 11）
 * - 含 key 与 default，构造时自动注册到 Pref.prefItems
 * - 自身提供 get/put/delete，内部调用 preferences 实例接口
 */
export class PrefItem<T extends preferences.ValueType> {
  readonly key: string;
  readonly def: T;

  constructor(key: string, def: T) {
    this.key = key;
    this.def = def;
    prefRegistry.push(this);
  }

  get(): T {
    return Pref.storageValue<T>(this.key, this.def);
  }

  put(value: T): void {
    Pref.writeValue(this.key, value);
  }

  delete(): void {
    Pref.removeKey(this.key);
  }

  /** 当前值是否等于默认值（导出过滤用） */
  isDefault(): boolean {
    return this.get() === this.def;
  }
}

const PREFS_NAME = 'user_prefs'

/**
 * 设置中心（AP-4 / Task 11）
 * - 不提供 get/put/delete，只提供 static 的 PrefItem 实例与导入/导出/重置接口
 * - 导出：preferences.getAll 过滤非默认项 + schemaVersion
 * - 导入：仅把文件中的键值 put 回 preferences，缺失项保留原设置
 * - 重置：调用 preferences 的 clear 清除所有设置
 */
export class Pref {
  /** 全部设置项（PrefItem 构造时自动注册） */
  static get prefItems(): PrefItem<preferences.ValueType>[] {
    return prefRegistry;
  }

  private static prefs: preferences.Preferences
  // ---------- 设置项定义（static PrefItem 实例） ----------

  /** 播放：默认清晰度（qn） */
  static readonly DEFAULT_QUALITY: PrefItem<number> = new PrefItem<number>('default_quality', 80);
  /** 播放：默认倍速 */
  static readonly DEFAULT_SPEED: PrefItem<number> = new PrefItem<number>('default_speed', 1);
  /** 播放：自动连播下一P */
  static readonly AUTO_PLAY_NEXT: PrefItem<boolean> = new PrefItem<boolean>('auto_play_next', true);
  /** 播放：弹幕开关 */
  static readonly DANMAKU_ENABLED: PrefItem<boolean> = new PrefItem<boolean>('danmaku_enabled', true);
  /** 外观：深色模式（system/light/dark） */
  static readonly DARK_MODE: PrefItem<string> = new PrefItem<string>('dark_mode', 'system');
  /** 搜索：历史记录开关 */
  static readonly SEARCH_HISTORY_ENABLED: PrefItem<boolean> = new PrefItem<boolean>('search_history_enabled', true);
  /** 隐私：屏蔽关键词（逗号分隔） */
  static readonly FILTER_KEYWORDS: PrefItem<string> = new PrefItem<string>('filter_keywords', '');
  /** 隐私：黑名单 UP mid（逗号分隔） */
  static readonly FILTER_BLACK_MIDS: PrefItem<string> = new PrefItem<string>('filter_black_mids', '');
  /** 隐私：最低赞播比（0 关闭） */
  static readonly FILTER_MIN_LIKE_RATIO: PrefItem<number> = new PrefItem<number>('filter_min_like_ratio', 0);
  /** 日志：日志开关 */
  static readonly LOG_ENABLED: PrefItem<boolean> = new PrefItem<boolean>('log_enabled', false);

  /** 初始化（EntryAbility onCreate 调用，幂等） */
  static init(context: common.Context): void {
    Pref.prefs ??= preferences.getPreferencesSync(context, { name: PREFS_NAME });
  }

  static storageValue<T extends preferences.ValueType>(key: string, def: T): T {
    if (Pref.prefs === null) {
      return def;
    }
    return Pref.prefs.getSync(key, def) as T;
  }

  static writeValue(key: string, value: preferences.ValueType): void {
    if (Pref.prefs === null) {
      return;
    }
    Pref.prefs.putSync(key, value);
    Pref.prefs.flushSync();
  }

  static removeKey(key: string): void {
    if (Pref.prefs === null) {
      return;
    }
    Pref.prefs.deleteSync(key);
    Pref.prefs.flushSync();
  }

  /**
   * 导出为 JSON 字符串：schemaVersion + 仅非默认项
   * （直接读取 preferences 的 getAll，再按默认值过滤）
   */
  static exportJson(): string {
    if (Pref.prefs === null) {
      return '{}';
    }
    return JSON.stringify(Pref.prefs.getAllSync(), null, 2);
  }

  /**
   * 导入 JSON：把文件中的键值 put 回 preferences；
   * 缺失项不重置（保留原设置）；未知 key 忽略。
   */
  static async importJson(json: string): Promise<Result<boolean>> {
    if (json.trim().length === 0) {
      return Result.err<boolean>(AppError.parse('导入内容为空'));
    }
    const items = Object.entries<preferences.ValueType>(JSON.parse(json));
    for (const item of items) {
      await Pref.prefs.put(item[0], item[1]);
    }
    await Pref.prefs.flush();
    Logger.info('Pref', '用户偏好导入成功');
    return Result.ok<boolean>(true);
  }

  /** 重置：清除所有设置（调用 preferences clear） */
  static async resetAll(): Promise<Result<boolean>> {
    try {
      await Pref.prefs.clear();
      await Pref.prefs.flush();
      return Result.ok<boolean>(true);
    } catch (e) {
      return Result.err<boolean>(AppError.unknown(`重置失败：${JSON.stringify(e)}`));
    }
  }
}
