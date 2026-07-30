import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Logger } from '../common/utils/Logger';
import { CryptoUtil } from '../common/utils/CryptoUtil';

/**
 * Cookie 管理（Task 2）：内存 + preferences 持久化，按账户隔离命名空间。
 * 非登录态下维护 buvid3 游客 Cookie。
 */
export class CookieManager {
  private static readonly PREF_NAME: string = 'ohb_cookie_store';
  private static readonly GUEST_MID: string = 'guest';
  private static instance: CookieManager | null = null;

  private pref: preferences.Preferences | null = null;
  /** 当前命名空间（mid 或 guest）下的 cookie 表 */
  private cookies: Map<string, string> = new Map();
  private currentNamespace: string = CookieManager.GUEST_MID;

  static getInstance(): CookieManager {
    if (CookieManager.instance === null) {
      CookieManager.instance = new CookieManager();
    }
    return CookieManager.instance;
  }

  init(context: common.Context): void {
    if (this.pref !== null) {
      return;
    }
    this.pref = preferences.getPreferencesSync(context, { name: CookieManager.PREF_NAME });
    this.loadNamespace(CookieManager.GUEST_MID);
    this.ensureBuvid3();
  }

  /** 切换命名空间（登录/切号/登出时调用） */
  switchNamespace(mid: string): void {
    const ns = mid.length > 0 ? mid : CookieManager.GUEST_MID;
    if (ns === this.currentNamespace) {
      return;
    }
    this.loadNamespace(ns);
  }

  get namespace(): string {
    return this.currentNamespace;
  }

  private nsKey(): string {
    return `cookies_${this.currentNamespace}`;
  }

  private loadNamespace(ns: string): void {
    this.currentNamespace = ns;
    this.cookies.clear();
    if (this.pref === null) {
      return;
    }
    const raw = this.pref.getSync(this.nsKey(), '') as string;
    if (raw.length > 0) {
      try {
        const obj = JSON.parse(raw) as Record<string, string>;
        const keys = Object.keys(obj);
        for (let i = 0; i < keys.length; i++) {
          this.cookies.set(keys[i], obj[keys[i]]);
        }
      } catch (e) {
        Logger.error('CookieManager', `parse cookies fail: ${JSON.stringify(e)}`);
      }
    }
  }

  private persist(): void {
    if (this.pref === null) {
      return;
    }
    const obj: Record<string, string> = {};
    this.cookies.forEach((v, k) => {
      obj[k] = v;
    });
    this.pref.putSync(this.nsKey(), JSON.stringify(obj));
    this.pref.flush();
  }

  set(name: string, value: string): void {
    this.cookies.set(name, value);
    this.persist();
  }

  /** 批量写入（登录成功后写 cookie_info.cookies） */
  setAll(entries: Map<string, string>): void {
    entries.forEach((v, k) => {
      this.cookies.set(k, v);
    });
    this.persist();
  }

  get(name: string): string {
    return this.cookies.get(name) ?? '';
  }

  /** 组装 Cookie 请求头 */
  buildCookieHeader(): string {
    const parts: string[] = [];
    this.cookies.forEach((v, k) => {
      if (v.length > 0) {
        parts.push(`${k}=${v}`);
      }
    });
    return parts.join('; ');
  }

  /** 从 Set-Cookie 响应头提取（多值以逗号/换行拼接的情况做基础拆分） */
  absorbSetCookie(setCookie: string): void {
    if (setCookie.length === 0) {
      return;
    }
    const segments = setCookie.split('\n');
    for (let i = 0; i < segments.length; i++) {
      const seg = segments[i].trim();
      if (seg.length === 0) {
        continue;
      }
      const firstPair = seg.split(';')[0];
      const eq = firstPair.indexOf('=');
      if (eq > 0) {
        const name = firstPair.substring(0, eq).trim();
        const value = firstPair.substring(eq + 1).trim();
        if (name.length > 0 && name !== 'expires' && name !== 'Max-Age') {
          this.cookies.set(name, value);
        }
      }
    }
    this.persist();
  }

  /** CSRF（bili_jct） */
  get csrf(): string {
    return this.get('bili_jct');
  }

  clear(): void {
    this.cookies.clear();
    this.ensureBuvid3();
    this.persist();
  }

  /** 游客 buvid3：大写 UUID + 5 位随机数 + infoc */
  private ensureBuvid3(): void {
    if (this.cookies.get('buvid3') !== undefined && this.get('buvid3').length > 0) {
      return;
    }
    const hex = CryptoUtil.randomHex(16).toUpperCase();
    const uuid = `${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}`;
    const rand5 = Math.floor(Math.random() * 90000) + 10000;
    this.cookies.set('buvid3', `${uuid}${rand5}infoc`);
  }
}
