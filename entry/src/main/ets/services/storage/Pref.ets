import { preferences } from '@kit.ArkData';
import { Result } from '../../common/result/Result';
import { AppError } from '../../common/result/AppError';
import { Logger } from '../../common/utils/Logger';
import { Callback } from '@kit.BasicServicesKit';
import { ContextUtil } from '../../common/utils/ContextUtil';

const prefRegistry: PrefItem<preferences.ValueType>[] = [];
let p: preferences.Preferences

export interface EnumEntry<T> {
  readonly label: string;
  readonly value: T;
}


interface PrefItemP<T extends preferences.ValueType> {
  key: string;
  def: T;
  title: string;
  desc: string;
  onChange: Callback<preferences.ValueType>;
  entries?: EnumEntry<T>[];
  needInit?: boolean;
}

const emptyCallback = () => {
}

/**
 * 单个设置项（AP-4 / Task 11）
 * - 含 key 与 default，构造时自动注册到 Pref.prefItems
 * - 自身提供 get/put/delete，内部调用 preferences 实例接口
 */
export class PrefItem<T extends preferences.ValueType> {
  readonly key: string;
  readonly def: T;
  readonly title: string;
  readonly desc: string;
  readonly entries: EnumEntry<T>[];
  readonly isEnum: boolean;
  readonly needInit: boolean;
  private onChange: Callback<preferences.ValueType>

  constructor(props: PrefItemP<T>) {
    this.key = props.key;
    this.def = props.def;
    this.title = props.title;
    this.desc = props.desc;
    this.entries = props.entries ?? [];
    this.isEnum = this.entries.length > 0;
    this.needInit = props.needInit ?? true;
    this.onChange = props.onChange;
    prefRegistry.push(this);
    if (this.needInit) {
      p ??= preferences.getPreferencesSync(ContextUtil.context, { name: PREFS_NAME })
      this.onChange(this.get());
    }
  }

  get(): T {
    return p.getSync(this.key, this.def) as T;
  }

  put(value: T): void {
    p.putSync(this.key, this.def)
    p.flushSync();
    this.onChange(value);
  }

  delete(): void {
    p.deleteSync(this.key)
    p.flushSync();
  }

  /**
   * 从枚举类生成 entries 键值对列表。
   * 枚举需为数字枚举或字符串枚举，此方法提取所有非数字键（排除反向映射）。
   */
  static fromEnum<T extends preferences.ValueType>(enumObj: Object): EnumEntry<T>[] {
    const result: EnumEntry<T>[] = [];
    const keys: string[] = Object.keys(enumObj);
    for (const k of keys) {
      const v: T = (enumObj as Record<string, T>)[k];
      if (typeof v === 'number') {
        const numKey: number = Number(k);
        if (!Number.isNaN(numKey) && numKey >= 0) {
          continue;
        }
      }
      result.push({ label: k, value: v });
    }
    return result;
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
  private constructor() {
  }

  /** 全部设置项（PrefItem 构造时自动注册） */
  static get items(): PrefItem<preferences.ValueType>[] {
    return prefRegistry;
  }
  // ---------- 设置项定义（static PrefItem 实例） ----------

  /** 播放：默认清晰度（qn） */
  static readonly DEFAULT_QUALITY: PrefItem<number> = new PrefItem<number>({
    key: 'default_quality',
    def: 80,
    onChange: emptyCallback,
    title: '默认清晰度',
    desc: '播放的默认清晰度'
  });
  /** 播放：默认倍速 */
  static readonly DEFAULT_SPEED: PrefItem<number> = new PrefItem<number>({
    key: 'default_speed',
    def: 1,
    onChange: emptyCallback,
    title: '默认倍速',
    desc: '播放的默认倍速'
  });
  /** 播放：自动连播下一P */
  static readonly AUTO_PLAY_NEXT: PrefItem<boolean> = new PrefItem<boolean>({
    key: 'auto_play_next',
    def: true,
    onChange: emptyCallback,
    title: '自动连播',
    desc: '自动播放下一P'
  });
  /** 播放：弹幕开关 */
  static readonly DANMAKU_ENABLED: PrefItem<boolean> = new PrefItem<boolean>({
    key: 'danmaku_enabled',
    def: true,
    onChange: emptyCallback,
    title: '弹幕开关',
    desc: '是否显示弹幕'
  });
  /** 外观：深色模式（system/light/dark） */
  static readonly DARK_MODE: PrefItem<string> = new PrefItem<string>({
    key: 'dark_mode',
    def: 'system',
    onChange: emptyCallback,
    title: '深色模式',
    desc: '外观主题（跟随系统/浅色/深色）'
  });
  /** 搜索：历史记录开关 */
  static readonly SEARCH_HISTORY_ENABLED: PrefItem<boolean> = new PrefItem<boolean>({
    key: 'search_history_enabled',
    def: true,
    onChange: emptyCallback,
    title: '搜索历史',
    desc: '是否记录搜索历史'
  });
  /** 隐私：屏蔽关键词（逗号分隔） */
  static readonly FILTER_KEYWORDS: PrefItem<string> = new PrefItem<string>({
    key: 'filter_keywords',
    def: '',
    onChange: emptyCallback,
    title: '屏蔽关键词',
    desc: '逗号分隔的关键词列表'
  });
  /** 隐私：黑名单 UP mid（逗号分隔） */
  static readonly FILTER_BLACK_MIDS: PrefItem<string> = new PrefItem<string>({
    key: 'filter_black_mids',
    def: '',
    onChange: emptyCallback,
    title: 'UP黑名单',
    desc: '逗号分隔的UP主mid列表'
  });
  /** 隐私：最低赞播比（0 关闭） */
  static readonly FILTER_MIN_LIKE_RATIO: PrefItem<number> = new PrefItem<number>({
    key: 'filter_min_like_ratio',
    def: 0,
    onChange: emptyCallback,
    title: '最低赞播比',
    desc: '低于此比例的视频将被过滤（0关闭）'
  });
  /** 日志：日志开关 */
  static readonly LOG_ENABLED: PrefItem<boolean> = new PrefItem<boolean>({
    key: 'log_enabled',
    def: false,
    onChange: emptyCallback,
    title: '日志开关',
    desc: '是否启用日志记录'
  });

  /**
   * 导出为 JSON 字符串：schemaVersion + 仅非默认项
   * （直接读取 preferences 的 getAll，再按默认值过滤）
   */
  static exportJson(): string {
    return JSON.stringify(p.getAllSync(), null, 2);
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
      await p.put(item[0], item[1]);
    }
    await p.flush();
    Logger.info('Pref', '用户偏好导入成功');
    return Result.ok<boolean>(true);
  }

  /** 重置：清除所有设置（调用 preferences clear） */
  static async resetAll(): Promise<Result<boolean>> {
    try {
      await p.clear();
      await p.flush();
      return Result.ok<boolean>(true);
    } catch (e) {
      return Result.err<boolean>(AppError.unknown(`重置失败：${JSON.stringify(e)}`));
    }
  }
}

const TAG = Pref.name