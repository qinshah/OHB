import { Result } from '../../common/result/Result';
import { AppError } from '../../common/result/AppError';
import { BiliApi } from '../../network/BiliApi';
import { AccountProfile, AuthCredential, QrCodeSession, QrPollResult, QrPollStatus } from '../../models/LoginModels';
import { AccountManager } from '../../services/account/AccountManager';
import { hilog } from '@kit.PerformanceAnalysisKit';

interface RawAuthCodeData {
  url?: string;
  auth_code?: string;
}

interface RawTokenInfo {
  access_token?: string;
  refresh_token?: string;
  expires_in?: number;
  mid?: number;
}

interface RawCookieItem {
  name?: string;
  value?: string;
}

interface RawCookieInfo {
  cookies?: RawCookieItem[];
}

interface RawPollData {
  token_info?: RawTokenInfo;
  cookie_info?: RawCookieInfo;
}

interface RawNavData {
  isLogin?: boolean;
  mid?: number;
  uname?: string;
  face?: string;
  level?: number;
  money?: number;
}

/** B站轮询返回码 */
const CODE_SCANNED: number = 86090;
const CODE_WAITING: number = 86039;
const CODE_EXPIRED: number = 86038;

/**
 * 认证仓库（Task 4）：TV 端扫码登录全流程。
 * getTVCode → 二维码 → poll 轮询 → 成功写 AccountManager
 */
export class AuthRepository {
  private api: BiliApi = new BiliApi();

  /** 申请登录二维码 */
  async createQrSession(): Promise<Result<QrCodeSession>> {
    const r = await this.api.tvQrCodeAuth();
    if (!r.isOk) {
      return Result.err<QrCodeSession>(r.error);
    }
    const data = r.value as RawAuthCodeData;
    if (data.url === undefined || data.auth_code === undefined) {
      return Result.err<QrCodeSession>(AppError.parse('auth_code response invalid'));
    }
    const session = new QrCodeSession();
    session.url = data.url;
    session.authCode = data.auth_code;
    session.createAt = Date.now();
    return Result.ok<QrCodeSession>(session);
  }

  /**
   * 轮询一次扫码状态。
   * code 0=成功(返回凭证)；86039=未扫码；86090=已扫待确认；86038=过期
   */
  async pollQrCode(authCode: string): Promise<Result<QrPollResult>> {
    const r = await this.api.tvQrCodePoll(authCode);
    const result = new QrPollResult();
    if (r.isOk) {
      // 成功时直接解析凭证，避免二次请求
      const data = r.value as RawPollData;
      const token = data.token_info;
      if (token !== undefined && token.access_token !== undefined && token.refresh_token !== undefined) {
        const credential = new AuthCredential();
        credential.accessToken = token.access_token;
        credential.refreshToken = token.refresh_token;
        credential.mid = `${token.mid ?? 0}`;
        credential.expiresAt = Math.floor(Date.now() / 1000) + (token.expires_in ?? 0);
        const cookies = data.cookie_info?.cookies ?? [];
        for (let i = 0; i < cookies.length; i++) {
          const c = cookies[i];
          if (c.name !== undefined && c.value !== undefined) {
            credential.cookies.set(c.name, c.value);
          }
        }
        result.credential = credential;
      }
      result.status = QrPollStatus.Success;
      result.message = '登录成功';
      return Result.ok<QrPollResult>(result);
    }
    const err = r.error;
    switch (err.code) {
      case CODE_WAITING:
        result.status = QrPollStatus.Waiting;
        result.message = '等待扫码';
        return Result.ok<QrPollResult>(result);
      case CODE_SCANNED:
        result.status = QrPollStatus.Scanned;
        result.message = '已扫码，请在手机上确认';
        return Result.ok<QrPollResult>(result);
      case CODE_EXPIRED:
        result.status = QrPollStatus.Expired;
        result.message = '二维码已过期，请刷新';
        return Result.ok<QrPollResult>(result);
      default:
        result.status = QrPollStatus.Failed;
        result.message = err.message;
        return Result.ok<QrPollResult>(result);
    }
  }

  /** 轮询成功后取回凭证（再次 poll 同一 auth_code，code=0 时 data 内含 token/cookie） */
  async fetchCredential(authCode: string): Promise<Result<AuthCredential>> {
    const r = await this.api.tvQrCodePoll(authCode);
    if (!r.isOk) {
      return Result.err<AuthCredential>(r.error);
    }
    const data = r.value as RawPollData;
    const token = data.token_info;
    if (token === undefined || token.access_token === undefined || token.refresh_token === undefined) {
      return Result.err<AuthCredential>(AppError.parse('token_info missing'));
    }
    const credential = new AuthCredential();
    credential.accessToken = token.access_token;
    credential.refreshToken = token.refresh_token;
    credential.mid = `${token.mid ?? 0}`;
    credential.expiresAt = Math.floor(Date.now() / 1000) + (token.expires_in ?? 0);
    const cookies = data.cookie_info?.cookies ?? [];
    for (let i = 0; i < cookies.length; i++) {
      const c = cookies[i];
      if (c.name !== undefined && c.value !== undefined) {
        credential.cookies.set(c.name, c.value);
      }
    }
    return Result.ok<AuthCredential>(credential);
  }

  /** 拉取当前登录用户信息（nav） */
  async fetchMyProfile(): Promise<Result<AccountProfile>> {
    const r = await this.api.nav();
    if (!r.isOk) {
      return Result.err<AccountProfile>(r.error);
    }
    const data = r.value as RawNavData;
    if (data.isLogin !== true) {
      return Result.err<AccountProfile>(AppError.unauthorized());
    }
    const profile = new AccountProfile();
    profile.mid = `${data.mid ?? 0}`;
    profile.uname = data.uname ?? '';
    profile.face = data.face ?? '';
    profile.level = data.level ?? 0;
    return Result.ok<AccountProfile>(profile);
  }

  /** 完成登录：写凭证 + 拉取并保存用户档案 */
  async completeLogin(credential: AuthCredential): Promise<Result<AccountProfile>> {
    const am = AccountManager.getInstance();
    // 先用凭证临时写入 Cookie 空间，才能拉取 nav
    const tempProfile = new AccountProfile();
    tempProfile.mid = credential.mid;
    am.login(credential, tempProfile);

    const r = await this.fetchMyProfile();
    if (r.isOk) {
      am.updateCurrentProfile(r.value);
      return Result.ok<AccountProfile>(r.value);
    }
    // nav 失败不阻断登录，返回临时档案
    return Result.ok<AccountProfile>(tempProfile);
  }
}
