import { hilog } from '@kit.PerformanceAnalysisKit';

/** 统一日志入口 */
const DOMAIN: number = 0x0B11;
const TAG: string = 'OHB';

export class Logger {
  static debug(sub: string, msg: string): void {
    hilog.debug(DOMAIN, TAG, '[%{public}s] %{public}s', sub, msg);
  }

  static info(sub: string, msg: string): void {
    hilog.info(DOMAIN, TAG, '[%{public}s] %{public}s', sub, msg);
  }

  static warn(sub: string, msg: string): void {
    hilog.warn(DOMAIN, TAG, '[%{public}s] %{public}s', sub, msg);
  }

  static error(sub: string, msg: string): void {
    hilog.error(DOMAIN, TAG, '[%{public}s] %{public}s', sub, msg);
  }
}
