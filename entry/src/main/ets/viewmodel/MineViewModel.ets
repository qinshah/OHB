import { AccountProfile } from '../models/LoginModels';
import { AccountManager } from '../services/account/AccountManager';
import { AuthRepository, RelationStat } from '../data/repository/AuthRepository';

/**
 * 我的 ViewModel（Task 4/10）：账户列表、当前账户、切换/退出。
 *
 * 切换账号 UI 不更新修复：
 * - AccountManager 变更通知 → listener → reload()（属性赋值驱动 @State 刷新）
 * - switchAccount/logout 之外，页面侧也直接调用 reload() 双保险
 * - reload 内部触发 refreshProfile()：切账号后档案（B币/硬币）与统计（关注/粉丝）
 *   均按新账号重新拉取，避免停留在旧账号数据
 */
@Observed
export class MineViewModel {
  current: AccountProfile | null = null;
  accounts: AccountProfile[] = [];
  isLoggedIn: boolean = false;
  /** 关注数（-1 未获取，登录后异步填充） */
  following: number = -1;
  /** 粉丝数（-1 未获取，登录后异步填充） */
  follower: number = -1;

  private am: AccountManager = AccountManager.getInstance();
  private authRepo: AuthRepository = new AuthRepository();
  private listener: () => void = () => {
    // 账户变化（登录/切换/退出/档案更新）：同步 reload 刷新 UI。
    // 注意不能在此调 refreshProfile：updateCurrentProfile 也会 notify，
    // 会形成 notify → refreshProfile → notify 死循环。
    this.reload();
  };

  init(): void {
    this.am.addListener(this.listener);
    this.reload();
  }

  dispose(): void {
    this.am.removeListener(this.listener);
  }

  reload(): void {
    this.isLoggedIn = this.am.isLoggedIn;
    this.current = this.am.current;
    this.accounts = this.am.accountList;
    // 未登录时清空统计，避免残留旧账号数据
    if (!this.isLoggedIn) {
      this.following = -1;
      this.follower = -1;
    }
  }

  /** 刷新当前账户档案（nav：昵称/头像/等级/B币/硬币）与统计（关注/粉丝） */
  async refreshProfile(): Promise<void> {
    if (!this.am.isLoggedIn) {
      return;
    }
    const mid: string = this.am.current?.mid ?? '';
    if (mid.length === 0) {
      return;
    }
    // 档案：失败静默（沿用本地缓存），成功会经 notify → reload 再刷新统计
    const r = await this.authRepo.fetchMyProfile();
    if (r.isOk) {
      this.am.updateCurrentProfile(r.value);
    }
    // 统计：切换/更新后按当前 mid 重新拉取
    const s = await this.authRepo.fetchRelationStat(mid);
    if (s.isOk) {
      this.following = s.value.following;
      this.follower = s.value.follower;
    }
  }

  switchAccount(mid: string): void {
    if (!this.am.switchTo(mid)) {
      return; // 切换失败（账户不存在）不重复刷新
    }
    // 双保险：listener 已 reload，这里再同步一次并拉取新账号数据
    this.reload();
    this.refreshProfile();
  }

  logout(mid: string): void {
    this.am.logout(mid);
    this.reload();
    this.refreshProfile();
  }
}
