import { AppError, ErrorKind } from '../result/AppError';

/**
 * UI 数据流状态机（AP-2，不沿用 PiliPlus 三态）
 * Idle | Loading | Refreshing | Data | Error | Empty
 * 覆盖首屏 / 下拉刷新 / 分页 / 空 / 错等场景。
 */
export enum DataStatus {
  Idle,
  /** 首屏加载（无数据） */
  Loading,
  /** 已有数据，正在刷新 */
  Refreshing,
  /** 有数据 */
  Data,
  /** 加载成功但为空 */
  Empty,
  /** 加载失败 */
  Error
}

export class DataState<T> {
  status: DataStatus = DataStatus.Idle;
  data: T | null = null;
  error: AppError | null = null;

  static idle<T>(): DataState<T> {
    return new DataState<T>();
  }

  static loading<T>(): DataState<T> {
    const s = new DataState<T>();
    s.status = DataStatus.Loading;
    return s;
  }

  static refreshing<T>(current: T | null): DataState<T> {
    const s = new DataState<T>();
    s.status = DataStatus.Refreshing;
    s.data = current;
    return s;
  }

  static data<T>(value: T): DataState<T> {
    const s = new DataState<T>();
    s.status = DataStatus.Data;
    s.data = value;
    return s;
  }

  static empty<T>(): DataState<T> {
    const s = new DataState<T>();
    s.status = DataStatus.Empty;
    return s;
  }

  static error<T>(err: AppError, keepData: T | null = null): DataState<T> {
    const s = new DataState<T>();
    s.status = DataStatus.Error;
    s.error = err;
    s.data = keepData;
    return s;
  }

  get isLoading(): boolean {
    return this.status === DataStatus.Loading;
  }

  get hasData(): boolean {
    return this.data !== null && (this.status === DataStatus.Data || this.status === DataStatus.Refreshing);
  }

  get isUnauthorized(): boolean {
    return this.error !== null && this.error.kind === ErrorKind.Unauthorized;
  }
}
