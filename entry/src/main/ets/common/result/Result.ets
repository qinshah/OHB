import { AppError } from './AppError';

/**
 * 纯操作结果（AP-2）：Ok<T> | Err<E>，与 UI 状态分离。
 * 网络/存储层只返回 Result，由 ViewModel 转换为 DataState。
 */
export class Result<T> {
  readonly isOk: boolean;
  private readonly valueOrNull: T | null;
  private readonly errorOrNull: AppError | null;

  private constructor(value: T | null, error: AppError | null) {
    this.valueOrNull = value;
    this.errorOrNull = error;
    this.isOk = error === null;
  }

  static ok<T>(value: T): Result<T> {
    return new Result<T>(value, null);
  }

  static err<T>(error: AppError): Result<T> {
    return new Result<T>(null, error);
  }

  get value(): T {
    if (this.valueOrNull === null) {
      throw new Error('Result has no value');
    }
    return this.valueOrNull;
  }

  get valueOrNullSafe(): T | null {
    return this.valueOrNull;
  }

  get error(): AppError {
    if (this.errorOrNull === null) {
      return AppError.unknown('no error present');
    }
    return this.errorOrNull;
  }

  /** 映射成功值 */
  map<R>(transform: (v: T) => R): Result<R> {
    if (this.isOk && this.valueOrNull !== null) {
      return Result.ok<R>(transform(this.valueOrNull));
    }
    return Result.err<R>(this.error);
  }
}
