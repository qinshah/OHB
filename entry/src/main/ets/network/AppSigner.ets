import { AppConstants } from '../common/constants/AppConstants';
import { CryptoUtil } from '../common/utils/CryptoUtil';

/**
 * App 签名（AppSign）：TV 扫码登录 / app.bilibili.com 域请求使用。
 * appkey + ts + 参数按 key 排序后 md5(query + appsec) = sign
 */
export class AppSigner {
  static async sign(params: Record<string, string | number | boolean>): Promise<Record<string, string | number | boolean>> {
    const merged: Record<string, string | number | boolean> = {};
    const keys = Object.keys(params);
    for (let i = 0; i < keys.length; i++) {
      merged[keys[i]] = params[keys[i]];
    }
    merged['appkey'] = AppConstants.APP_KEY;
    merged['ts'] = Math.floor(Date.now() / 1000);

    const sortedKeys = Object.keys(merged).sort();
    const parts: string[] = [];
    for (let i = 0; i < sortedKeys.length; i++) {
      const k = sortedKeys[i];
      parts.push(`${encodeURIComponent(k)}=${encodeURIComponent(`${merged[k]}`)}`);
    }
    const query = parts.join('&');
    const sign = await CryptoUtil.md5Hex(query + AppConstants.APP_SEC);
    merged['sign'] = sign;
    return merged;
  }

  /** 将参数表拼成 URL query 字符串 */
  static toQueryString(params: Record<string, string | number | boolean>): string {
    const keys = Object.keys(params);
    const parts: string[] = [];
    for (let i = 0; i < keys.length; i++) {
      const k = keys[i];
      parts.push(`${encodeURIComponent(k)}=${encodeURIComponent(`${params[k]}`)}`);
    }
    return parts.join('&');
  }
}
