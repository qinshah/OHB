/**
 * 统一错误模型（AP-2）
 * 携带业务码、错误信息、可重试性与原始异常，避免错误字符串散落。
 */
export enum ErrorKind {
  /** 网络不可达/超时 */
  Network,
  /** HTTP 状态码异常 */
  Http,
  /** 业务错误（B站 code != 0） */
  Business,
  /** 未登录 / 登录态失效 */
  Unauthorized,
  /** 数据解析失败 */
  Parse,
  /** 其他未知错误 */
  Unknown
}

export class AppError {
  readonly kind: ErrorKind;
  readonly code: number;
  readonly message: string;
  readonly retryable: boolean;
  readonly cause: string;

  constructor(kind: ErrorKind, code: number, message: string, retryable: boolean = false, cause: string = '') {
    this.kind = kind;
    this.code = code;
    this.message = message;
    this.retryable = retryable;
    this.cause = cause;
  }

  static network(cause: string): AppError {
    return new AppError(ErrorKind.Network, -1, '网络连接失败，请检查网络后重试', true, cause);
  }

  static http(status: number): AppError {
    return new AppError(ErrorKind.Http, status, `请求失败（HTTP ${status}）`, status >= 500);
  }

  static business(code: number, message: string): AppError {
    const retryable: boolean = code === -412 || code === -504;
    return new AppError(ErrorKind.Business, code, message, retryable);
  }

  static unauthorized(message: string = '登录状态已失效，请重新登录'): AppError {
    return new AppError(ErrorKind.Unauthorized, -101, message, false);
  }

  static parse(cause: string): AppError {
    return new AppError(ErrorKind.Parse, -2, '数据解析失败', false, cause);
  }

  static unknown(cause: string): AppError {
    return new AppError(ErrorKind.Unknown, -999, '发生未知错误', false, cause);
  }
}
