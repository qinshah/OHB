import { common } from '@kit.AbilityKit';
import { AccountProfile, AuthCredential } from '../../models/LoginModels';
import { PrefsStorage } from '../storage/PrefsStorage';
import { SecureStorage } from '../storage/SecureStorage';
import { CookieManager } from '../../network/CookieManager';
import { Logger } from '../../common/utils/Logger';

/**
 * 多用户与认证框架（AP-5 / Task 4）
 * - 多账户列表 + 当前激活账户
 * - 凭证（Token/Cookie）经 SecureStorage 加密托管，不落明文
 * - 账户切换时切换 Cookie 与用户级设置命名空间
 */
export class AccountManager {
  private static readonly PREF: string = 'ohb_accounts';
  private static readonly KEY_LIST: string = 'account_list';
  private static readonly KEY_CURRENT: string = 'current_mid';
  private static instance: AccountManager | null = null;

  private storage: PrefsStorage | null = null;
  private accounts: AccountProfile[] = [];
  private currentMid: string = '';
  /** 账户变更监听（UI 刷新用） */
  private listeners: Array<() => void> = [];

  static getInstance(): AccountManager {
    if (AccountManager.instance === null) {
      AccountManager.instance = new AccountManager();
    }
    return AccountManager.instance;
  }

  init(context: common.Context): void {
    if (this.storage !== null) {
      return;
    }
    this.storage = new PrefsStorage(context, AccountManager.PREF);
    CookieManager.getInstance().init(context);
    this.loadAccounts();
    // 启动恢复登录态（自动登录）
    this.restoreSession();
  }

  addListener(l: () => void): void {
    this.listeners.push(l);
  }

  removeListener(l: () => void): void {
    const idx = this.listeners.indexOf(l);
    if (idx >= 0) {
      this.listeners.splice(idx, 1);
    }
  }

  private notify(): void {
    for (let i = 0; i < this.listeners.length; i++) {
      this.listeners[i]();
    }
  }

  private loadAccounts(): void {
    if (this.storage === null) {
      return;
    }
    const raw = this.storage.getString(AccountManager.KEY_LIST, '[]');
    try {
      const arr = JSON.parse(raw) as AccountProfile[];
      this.accounts = arr;
    } catch (e) {
      this.accounts = [];
    }
    this.currentMid = this.storage.getString(AccountManager.KEY_CURRENT, '');
  }

  private persistAccounts(): void {
    if (this.storage === null) {
      return;
    }
    this.storage.putString(AccountManager.KEY_LIST, JSON.stringify(this.accounts));
    this.storage.putString(AccountManager.KEY_CURRENT, this.currentMid);
  }

  /** 用户级设置命名空间（每账户按 mid 分区，AP-5） */
  userPrefName(mid: string): string {
    return mid.length > 0 ? `ohb_user_${mid}` : 'ohb_user_guest';
  }

  currentUserPrefName(): string {
    return this.userPrefName(this.currentMid);
  }

  // ---------- 会话 ----------

  /** 启动恢复：有当前账户则切换其数据空间（Cookie 已按命名空间持久化） */
  private restoreSession(): void {
    if (this.currentMid.length > 0) {
      const found = this.findProfile(this.currentMid);
      if (found !== null) {
        CookieManager.getInstance().switchNamespace(this.currentMid);
        Logger.info('Account', `restore session mid=${this.currentMid}`);
        return;
      }
      this.currentMid = '';
    }
    CookieManager.getInstance().switchNamespace('');
  }

  /** 登录成功：保存档案 + 凭证，切换为当前账户 */
  login(credential: AuthCredential, profile: AccountProfile): void {
    const mid = credential.mid;
    // 1. 档案列表去重更新
    const idx = this.accounts.findIndex((a: AccountProfile) => a.mid === mid);
    if (idx >= 0) {
      this.accounts[idx] = profile;
    } else {
      this.accounts.push(profile);
    }
    this.currentMid = mid;
    this.persistAccounts();

    // 2. 凭证加密托管（不落明文）
    SecureStorage.put(this.tokenAlias(mid), credential.accessToken);
    SecureStorage.put(this.refreshAlias(mid), credential.refreshToken);
    SecureStorage.put(this.expireAlias(mid), `${credential.expiresAt}`);

    // 3. 切换 Cookie 命名空间并写入登录 Cookie + access_key
    const cm = CookieManager.getInstance();
    cm.switchNamespace(mid);
    cm.setAll(credential.cookies);
    cm.set('access_key', credential.accessToken);
    cm.set('refresh_token', credential.refreshToken);

    this.notify();
    Logger.info('Account', `login success mid=${mid} name=${profile.uname}`);
  }

  /** 切换当前账户（数据空间隔离：Cookie + 用户设置） */
  switchTo(mid: string): boolean {
    const found = this.findProfile(mid);
    if (found === null) {
      return false;
    }
    this.currentMid = mid;
    this.persistAccounts();
    CookieManager.getInstance().switchNamespace(mid);
    this.notify();
    Logger.info('Account', `switch to mid=${mid}`);
    return true;
  }

  /** 退出登录：清除当前账户认证信息 */
  logout(mid: string): void {
    SecureStorage.remove(this.tokenAlias(mid));
    SecureStorage.remove(this.refreshAlias(mid));
    SecureStorage.remove(this.expireAlias(mid));

    const idx = this.accounts.findIndex((a: AccountProfile) => a.mid === mid);
    if (idx >= 0) {
      this.accounts.splice(idx, 1);
    }
    const cm = CookieManager.getInstance();
    cm.switchNamespace(mid);
    cm.clear();

    if (this.currentMid === mid) {
      this.currentMid = this.accounts.length > 0 ? this.accounts[0].mid : '';
      cm.switchNamespace(this.currentMid);
    }
    this.persistAccounts();
    this.notify();
    Logger.info('Account', `logout mid=${mid}`);
  }

  // ---------- 查询 ----------

  get isLoggedIn(): boolean {
    return this.currentMid.length > 0 && this.findProfile(this.currentMid) !== null;
  }

  get current(): AccountProfile | null {
    return this.findProfile(this.currentMid);
  }

  get accountList(): AccountProfile[] {
    return this.accounts;
  }

  currentAccessToken(): string {
    if (this.currentMid.length === 0) {
      return '';
    }
    return SecureStorage.get(this.tokenAlias(this.currentMid));
  }

  private findProfile(mid: string): AccountProfile | null {
    if (mid.length === 0) {
      return null;
    }
    const idx = this.accounts.findIndex((a: AccountProfile) => a.mid === mid);
    return idx >= 0 ? this.accounts[idx] : null;
  }

  /** 更新当前账户档案（登录后拉取 nav 信息刷新昵称/头像） */
  updateCurrentProfile(profile: AccountProfile): void {
    const idx = this.accounts.findIndex((a: AccountProfile) => a.mid === profile.mid);
    if (idx >= 0) {
      this.accounts[idx] = profile;
      this.persistAccounts();
      this.notify();
    }
  }

  private tokenAlias(mid: string): string {
    return `ohb_token_${mid}`;
  }

  private refreshAlias(mid: string): string {
    return `ohb_refresh_${mid}`;
  }

  private expireAlias(mid: string): string {
    return `ohb_expire_${mid}`;
  }
}
