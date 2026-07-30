import { AccountProfile } from '../models/LoginModels';
import { AccountManager } from '../services/account/AccountManager';
import { AuthRepository } from '../data/repository/AuthRepository';

/**
 * 我的 ViewModel（Task 4/10）：账户列表、当前账户、切换/退出。
 */
@Observed
export class MineViewModel {
  current: AccountProfile | null = null;
  accounts: AccountProfile[] = [];
  isLoggedIn: boolean = false;

  private am: AccountManager = AccountManager.getInstance();
  private authRepo: AuthRepository = new AuthRepository();
  private listener: () => void = () => {
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
  }

  /** 刷新当前账户档案（nav） */
  async refreshProfile(): Promise<void> {
    if (!this.am.isLoggedIn) {
      return;
    }
    const r = await this.authRepo.fetchMyProfile();
    if (r.isOk) {
      this.am.updateCurrentProfile(r.value);
    }
  }

  switchAccount(mid: string): void {
    this.am.switchTo(mid);
  }

  logout(mid: string): void {
    this.am.logout(mid);
  }
}
