/** 展示格式化工具 */
export class FormatUtils {
  /** 12345 -> 1.2万 */
  static count(n: number): string {
    if (n >= 100000000) {
      return `${(n / 100000000).toFixed(1)}亿`;
    }
    if (n >= 10000) {
      return `${(n / 10000).toFixed(1)}万`;
    }
    return `${n}`;
  }

  /** 秒 -> mm:ss 或 hh:mm:ss */
  static duration(sec: number): string {
    const s = Math.max(0, Math.floor(sec));
    const h = Math.floor(s / 3600);
    const m = Math.floor((s % 3600) / 60);
    const r = s % 60;
    const mm = m < 10 ? `0${m}` : `${m}`;
    const rr = r < 10 ? `0${r}` : `${r}`;
    if (h > 0) {
      const hh = h < 10 ? `0${h}` : `${h}`;
      return `${hh}:${mm}:${rr}`;
    }
    return `${mm}:${rr}`;
  }

  /** 毫秒 -> mm:ss / hh:mm:ss */
  static durationMs(ms: number): string {
    return FormatUtils.duration(Math.floor(ms / 1000));
  }

  /** 时间戳（秒）-> 友好相对时间 */
  static relativeTime(tsSec: number): string {
    const now = Math.floor(Date.now() / 1000);
    const diff = now - tsSec;
    if (diff < 60) {
      return '刚刚';
    }
    if (diff < 3600) {
      return `${Math.floor(diff / 60)}分钟前`;
    }
    if (diff < 86400) {
      return `${Math.floor(diff / 3600)}小时前`;
    }
    if (diff < 86400 * 30) {
      return `${Math.floor(diff / 86400)}天前`;
    }
    const d = new Date(tsSec * 1000);
    const m = d.getMonth() + 1;
    const day = d.getDate();
    return `${d.getFullYear()}-${m < 10 ? '0' + m : m}-${day < 10 ? '0' + day : day}`;
  }

  static stripHtml(input: string): string {
    return input.replace(/<[^>]+>/g, '');
  }
}
