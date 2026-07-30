import { AuthRepository } from '../data/repository/AuthRepository';
import { AccountProfile, AuthCredential, QrPollStatus } from '../models/LoginModels';
import { Logger } from '../common/utils/Logger';

/** 二维码有效期（秒） */
const QR_TTL_SEC: number = 180;
/** 轮询间隔（ms） */
const POLL_INTERVAL_MS: number = 1000;

/**
 * 登录 ViewModel（Task 4）：扫码登录状态机。
 * 申请二维码 → 1s 轮询（等待→已扫→成功/过期）→ 写凭证 → 拉取档案
 */
@Observed
export class LoginViewModel {
  qrUrl: string = '';
  statusText: string = '正在获取二维码…';
  isLoadingQr: boolean = true;
  isSuccess: boolean = false;
  isExpired: boolean = false;
  errorText: string = '';
  /** 剩余有效秒数 */
  countdown: number = 0;

  private repo: AuthRepository = new AuthRepository();
  private authCode: string = '';
  private polling: boolean = false;
  private sessionSeq: number = 0;
  private onSuccessCb: ((profile: AccountProfile) => void) | null = null;

  setOnSuccess(cb: (profile: AccountProfile) => void): void {
    this.onSuccessCb = cb;
  }

  /** 开始一轮扫码登录 */
  async start(): Promise<void> {
    this.sessionSeq++;
    const seq = this.sessionSeq;
    this.stopPolling();
    this.isLoadingQr = true;
    this.isSuccess = false;
    this.isExpired = false;
    this.errorText = '';
    this.qrUrl = '';

    const r = await this.repo.createQrSession();
    if (seq !== this.sessionSeq) {
      return;
    }
    if (!r.isOk) {
      this.isLoadingQr = false;
      this.errorText = r.error.message;
      this.statusText = '二维码获取失败，点击重试';
      return;
    }
    const session = r.value;
    this.qrUrl = session.url;
    this.authCode = session.authCode;
    this.isLoadingQr = false;
    this.statusText = '请使用哔哩哔哩 App 扫码登录';
    this.countdown = QR_TTL_SEC;
    this.startPolling(seq);
  }

  private startPolling(seq: number): void {
    this.polling = true;
    const timer = setInterval(() => {
      if (!this.polling || seq !== this.sessionSeq) {
        clearInterval(timer);
        return;
      }
      this.countdown--;
      if (this.countdown <= 0) {
        this.isExpired = true;
        this.statusText = '二维码已过期，点击刷新';
        this.stopPolling();
        clearInterval(timer);
        return;
      }
      this.pollOnce(seq);
    }, POLL_INTERVAL_MS);
  }

  private async pollOnce(seq: number): Promise<void> {
    if (this.authCode.length === 0) {
      return;
    }
    try {
      const r = await this.repo.pollQrCode(this.authCode);
      if (!this.polling || seq !== this.sessionSeq || !r.isOk) {
        return;
      }
      const result = r.value;
      switch (result.status) {
        case QrPollStatus.Waiting:
          this.statusText = '请使用哔哩哔哩 App 扫码登录';
          break;
        case QrPollStatus.Scanned:
          this.statusText = '已扫码，请在手机上确认登录';
          break;
        case QrPollStatus.Expired:
          this.isExpired = true;
          this.statusText = '二维码已过期，点击刷新';
          this.stopPolling();
          break;
        case QrPollStatus.Failed:
          this.statusText = result.message;
          break;
        case QrPollStatus.Success:
          this.statusText = '登录成功，正在获取用户信息…';
          this.stopPolling();
          if (result.credential !== undefined) {
            await this.finishLogin(result.credential);
          } else {
            this.statusText = '凭证获取失败：未找到凭证信息';
          }
          break;
      }
    } catch (e) {
      Logger.error('Login', `poll error: ${JSON.stringify(e)}`);
    }
  }

  private async finishLogin(credential: AuthCredential): Promise<void> {
    const r2 = await this.repo.completeLogin(credential);
    if (r2.isOk) {
      this.isSuccess = true;
      this.statusText = `欢迎，${r2.value.uname}`;
      if (this.onSuccessCb !== null) {
        this.onSuccessCb(r2.value);
      }
    } else {
      this.statusText = `登录异常：${r2.error.message}`;
    }
  }

  stopPolling(): void {
    this.polling = false;
  }

  dispose(): void {
    this.sessionSeq++;
    this.stopPolling();
  }
}
