import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Result } from '../../common/result/Result';
import { AppError } from '../../common/result/AppError';
import { Logger } from '../../common/utils/Logger';

/** 设置值类型（preferences ValueType 子集） */
export type PrefValue = string | number | boolean;

/** 设置导出包络 */
interface ExportPayload {
  schemaVersion: number;
  items: Record<string, PrefValue>;
}

/** 设置 schema 版本 */
const SCHEMA_VERSION: number = 1;

/**
 * 设置项注册表（模块级数组，避免 Pref 类静态初始化期间引用类绑定导致
 * "Pref is not initialized"（TDZ））。
 */
const prefRegistry: PrefItem[] = [];

/**
 * 单个设置项（AP-4 / Task 11）
 * - 含 key 与 default，构造时自动注册到 Pref.prefItems
 * - 自身提供 get/put/delete，内部调用 preferences 实例接口
 */
export class PrefItem {
  readonly key: string;
  readonly def: PrefValue;

  constructor(key: string, def: PrefValue) {
    this.key = key;
    this.def = def;
    prefRegistry.push(this);
  }

  get(): PrefValue {
    return Pref.storageValue(this.key, this.def);
  }

  getString(): string {
    return this.get() as string;
  }

  getNumber(): number {
    return this.get() as number;
  }

  getBool(): boolean {
    return this.get() as boolean;
  }

  put(value: PrefValue): void {
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

/**
 * 设置中心（AP-4 / Task 11）
 * - 不提供 get/put/delete，只提供 static 的 PrefItem 实例与导入/导出/重置接口
 * - 导出：preferences.getAll 过滤非默认项 + schemaVersion
 * - 导入：仅把文件中的键值 put 回 preferences，缺失项保留原设置
 * - 重置：调用 preferences 的 clear 清除所有设置
 */
export class Pref {
  /** 全部设置项（PrefItem 构造时自动注册） */
  static get prefItems(): PrefItem[] {
    return prefRegistry;
  }

  private static pref: preferences.Preferences | null = null;

  // ---------- 设置项定义（static PrefItem 实例） ----------

  /** 播放：默认清晰度（qn） */
  static readonly DEFAULT_QUALITY: PrefItem = new PrefItem('default_quality', 80);
  /** 播放：默认倍速 */
  static readonly DEFAULT_SPEED: PrefItem = new PrefItem('default_speed', 1);
  /** 播放：自动连播下一P */
  static readonly AUTO_PLAY_NEXT: PrefItem = new PrefItem('auto_play_next', true);
  /** 播放：弹幕开关 */
  static readonly DANMAKU_ENABLED: PrefItem = new PrefItem('danmaku_enabled', true);
  /** 外观：深色模式（system/light/dark） */
  static readonly DARK_MODE: PrefItem = new PrefItem('dark_mode', 'system');
  /** 搜索：历史记录开关 */
  static readonly SEARCH_HISTORY_ENABLED: PrefItem = new PrefItem('search_history_enabled', true);
  /** 隐私：屏蔽关键词（逗号分隔） */
  static readonly FILTER_KEYWORDS: PrefItem = new PrefItem('filter_keywords', '');
  /** 隐私：黑名单 UP mid（逗号分隔） */
  static readonly FILTER_BLACK_MIDS: PrefItem = new PrefItem('filter_black_mids', '');
  /** 隐私：最低赞播比（0 关闭） */
  static readonly FILTER_MIN_LIKE_RATIO: PrefItem = new PrefItem('filter_min_like_ratio', 0);
  /** 日志：日志开关 */
  static readonly LOG_ENABLED: PrefItem = new PrefItem('log_enabled', false);

  /** 初始化（EntryAbility onCreate 调用，幂等） */
  static init(context: common.Context): void {
    if (Pref.pref !== null) {
      return;
    }
    Pref.pref = preferences.getPreferencesSync(context, { name: 'ohb_settings' });
  }

  static storageValue(key: string, def: PrefValue): PrefValue {
    if (Pref.pref === null) {
      return def;
    }
    return Pref.pref.getSync(key, def) as PrefValue;
  }

  static writeValue(key: string, value: PrefValue): void {
    if (Pref.pref === null) {
      return;
    }
    Pref.pref.putSync(key, value);
    Pref.pref.flushSync();
  }

  static removeKey(key: string): void {
    if (Pref.pref === null) {
      return;
    }
    Pref.pref.deleteSync(key);
    Pref.pref.flushSync();
  }

  /** 全量读取（preferences.getAllSync） */
  static getAll(): Record<string, PrefValue> {
    if (Pref.pref === null) {
      return {};
    }
    return Pref.pref.getAllSync() as Record<string, PrefValue>;
  }

  /**
   * 导出为 JSON 字符串：schemaVersion + 仅非默认项
   * （直接读取 preferences 的 getAll，再按默认值过滤）
   */
  static exportJson(): string {
    const all = Pref.getAll();
    const items: Record<string, PrefValue> = {};
    for (let i = 0; i < Pref.prefItems.length; i++) {
      const item = Pref.prefItems[i];
      if (all[item.key] !== undefined && !item.isDefault()) {
        items[item.key] = item.get();
      }
    }
    const payload: ExportPayload = {
      schemaVersion: SCHEMA_VERSION,
      items: items
    };
    return JSON.stringify(payload);
  }

  /**
   * 导入 JSON：把文件中的键值 put 回 preferences；
   * 缺失项不重置（保留原设置）；未知 key 忽略。
   */
  static importJson(json: string): Result<boolean> {
    if (json.trim().length === 0) {
      return Result.err<boolean>(AppError.parse('导入内容为空'));
    }
    let payload: ExportPayload;
    try {
      payload = JSON.parse(json) as ExportPayload;
    } catch (e) {
      return Result.err<boolean>(AppError.parse(`设置文件解析失败：${JSON.stringify(e)}`));
    }
    if (payload === null || payload === undefined || payload.items === undefined) {
      return Result.err<boolean>(AppError.parse('设置文件缺少 items 字段'));
    }
    const items = payload.items;
    const known: Map<string, PrefItem> = new Map();
    for (let i = 0; i < Pref.prefItems.length; i++) {
      known.set(Pref.prefItems[i].key, Pref.prefItems[i]);
    }
    const keys = Object.keys(items);
    let applied = 0;
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      const item = known.get(key);
      if (item !== undefined) {
        Pref.writeValue(key, items[key]);
        applied++;
      }
    }
    Logger.info('Pref', `import applied ${applied} keys, schemaVersion=${payload.schemaVersion ?? 0}`);
    return Result.ok<boolean>(true);
  }

  /** 重置：清除所有设置（调用 preferences clear） */
  static async resetAll(): Promise<Result<boolean>> {
    if (Pref.pref === null) {
      return Result.err<boolean>(AppError.unknown('设置存储未初始化'));
    }
    try {
      await Pref.pref.clear();
      return Result.ok<boolean>(true);
    } catch (e) {
      return Result.err<boolean>(AppError.unknown(`重置失败：${JSON.stringify(e)}`));
    }
  }
}
