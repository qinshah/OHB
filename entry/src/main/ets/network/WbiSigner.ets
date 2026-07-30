import { CryptoUtil } from '../common/utils/CryptoUtil';

/**
 * WBI 签名（AP-2 / Task 2）
 * 算法参考 PiliPlus wbi_sign.dart 的实现逻辑，ArkTS 重写。
 *
 * 流程：
 * 1. 从 nav 接口取 wbi_img.img_url / sub_url，取文件名拼接 64 字符
 * 2. 按 mixinKeyEncTab 重排取 32 字符 = mixinKey
 * 3. 参数加 wts，按 key 字典序排序，剔除 value 中 !'()* 后 URL 编码
 * 4. w_rid = md5(query + mixinKey)
 */
const MIXIN_KEY_ENC_TAB: number[] = [
  46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35,
  27, 43, 5, 49, 33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13
];

export class WbiKeys {
  imgKey: string = '';
  subKey: string = '';
  /** 获取日期戳（YYYY-MM-DD），按天刷新 */
  dayStamp: string = '';
}

export class WbiSigner {
  private static keys: WbiKeys | null = null;

  /** 由 WbiKeyRefresher（HttpClient）注入最新 key */
  static setKeys(keys: WbiKeys): void {
    WbiSigner.keys = keys;
  }

  static getKeys(): WbiKeys | null {
    return WbiSigner.keys;
  }

  private static todayStamp(): string {
    const d = new Date();
    const m = d.getMonth() + 1;
    const day = d.getDate();
    return `${d.getFullYear()}-${m < 10 ? '0' + m : m}-${day < 10 ? '0' + day : day}`;
  }

  static needRefresh(): boolean {
    const k = WbiSigner.keys;
    if (k === null || k.imgKey.length === 0 || k.subKey.length === 0) {
      return true;
    }
    return k.dayStamp !== WbiSigner.todayStamp();
  }

  /** 从完整 URL 提取文件名（去路径与扩展名） */
  static extractKeyFromUrl(url: string): string {
    const noQuery = url.split('?')[0];
    const parts = noQuery.split('/');
    const file = parts[parts.length - 1];
    const dot = file.lastIndexOf('.');
    return dot > 0 ? file.substring(0, dot) : file;
  }

  private static mixinKey(imgKey: string, subKey: string): string {
    const raw = imgKey + subKey;
    let out = '';
    for (let i = 0; i < MIXIN_KEY_ENC_TAB.length; i++) {
      const idx = MIXIN_KEY_ENC_TAB[i];
      if (idx < raw.length) {
        out += raw.charAt(idx);
      }
    }
    return out.substring(0, 32);
  }

  /**
   * 对参数做 WBI 签名，返回已附加 wts / w_rid 的新参数表。
   * key 未就绪时原样返回（调用方需先刷新 key）。
   */
  static async sign(params: Record<string, string | number | boolean>): Promise<Record<string, string | number | boolean>> {
    const k = WbiSigner.keys;
    if (k === null) {
      return params;
    }
    const mixin = WbiSigner.mixinKey(k.imgKey, k.subKey);
    const withWts: Record<string, string | number | boolean> = {};
    const srcKeys = Object.keys(params);
    for (let i = 0; i < srcKeys.length; i++) {
      withWts[srcKeys[i]] = params[srcKeys[i]];
    }
    withWts['wts'] = Math.floor(Date.now() / 1000);

    const sortedKeys = Object.keys(withWts).sort();
    const parts: string[] = [];
    for (let i = 0; i < sortedKeys.length; i++) {
      const key = sortedKeys[i];
      let value = `${withWts[key]}`;
      // 剔除 value 中 !'()* 字符
      value = value.replace(/[!'()*]/g, '');
      parts.push(`${encodeURIComponent(key)}=${encodeURIComponent(value)}`);
    }
    const query = parts.join('&');
    const wRid = await CryptoUtil.md5Hex(query + mixin);

    const result: Record<string, string | number | boolean> = {};
    const finalKeys = Object.keys(withWts);
    for (let i = 0; i < finalKeys.length; i++) {
      result[finalKeys[i]] = withWts[finalKeys[i]];
    }
    result['w_rid'] = wRid;
    return result;
  }
}
