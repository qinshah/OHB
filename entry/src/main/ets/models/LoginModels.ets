/** 扫码登录模型 */

/** 二维码申请结果 */
export class QrCodeSession {
  /** 二维码内容（直接生成二维码） */
  url: string = '';
  authCode: string = '';
  /** 申请时刻（ms），有效期 180s */
  createAt: number = 0;
}

/** 轮询状态机 */
export enum QrPollStatus {
  /** 等待扫码 */
  Waiting,
  /** 已扫码待确认 */
  Scanned,
  /** 登录成功 */
  Success,
  /** 二维码过期 */
  Expired,
  /** 网络/业务异常 */
  Failed
}

export class QrPollResult {
  status: QrPollStatus = QrPollStatus.Waiting;
  message: string = '';
}

/** 登录成功后的凭证包 */
export class AuthCredential {
  mid: string = '';
  accessToken: string = '';
  refreshToken: string = '';
  /** cookie 名值表（SESSDATA / bili_jct / DedeUserID 等） */
  cookies: Map<string, string> = new Map();
  /** 过期时间戳（秒） */
  expiresAt: number = 0;
}

/** 账户档案（不含敏感凭证，可明文存储） */
export class AccountProfile {
  mid: string = '';
  uname: string = '';
  face: string = '';
  level: number = 0;
}
