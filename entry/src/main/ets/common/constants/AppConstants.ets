/**
 * 应用级常量（Task 1）
 * API BaseUrl、UA、超时、AppKey 等集中维护。
 */
export class AppConstants {
  // ---- Base URLs ----
  static readonly API_BASE: string = 'https://api.bilibili.com';
  static readonly APP_BASE: string = 'https://app.bilibili.com';
  static readonly PASSPORT_BASE: string = 'https://passport.bilibili.com';
  static readonly SEARCH_BASE: string = 'https://s.search.bilibili.com';

  // ---- HTTP ----
  static readonly CONNECT_TIMEOUT: number = 10000;
  static readonly READ_TIMEOUT: number = 15000;
  static readonly MAX_RETRY: number = 1;

  // ---- Headers ----
  static readonly REFERER: string = 'https://www.bilibili.com';
  static readonly SEARCH_REFERER: string = 'https://search.bilibili.com';
  /** Web 端 UA */
  static readonly WEB_UA: string =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';
  /** App 端 UA（登录 / App 接口使用，与 PiliPlus 一致避免风控） */
  static readonly APP_UA: string =
    'Mozilla/5.0 BiliDroid/2.0.1 (bbcallen@gmail.com) os/android model/android_hd mobi_app/android_hd build/2001100 channel/master innerVer/2001100 osVer/15 network/2';

  // ---- App 签名（TV/App 接口 AppSign） ----
  static readonly APP_KEY: string = 'dfca71928277209b';
  static readonly APP_SEC: string = 'b5475a8825547a4fc26c7d518eaaa02e';

  // ---- 分页 ----
  static readonly PAGE_SIZE: number = 20;

  // ---- 主题品牌色 ----
  static readonly BRAND_COLOR: string = '#FB7299';
}
