import { http } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppConstants } from '../common/constants/AppConstants';
import { AppError } from '../common/result/AppError';
import { Result } from '../common/result/Result';
import { CookieManager } from './CookieManager';
import { WbiKeys, WbiSigner } from './WbiSigner';
import { AppSigner } from './AppSigner';
import { ApiConstants } from './ApiConstants';

// TAG 固定写在文件最下方：const TAG = HttpClient.name ?? 'HttpClient'

/** B站统一响应包络 */
interface BiliEnvelope {
  code?: number;
  message?: string;
  data?: Object;
}

export enum ChannelType {
  /** Web 通道：WBI 签名 + Web UA */
  Web,
  /** App 通道：AppSign + App UA + access_key */
  App,
  /** 无签名裸请求 */
  Raw
}

/**
 * 统一 HTTP 客户端（Task 2）
 * - GET/POST、表单/JSON、超时、重试
 * - 拦截：Cookie 注入、UA、access_key、错误转换、日志
 * - WBI key 自动刷新（经 nav 接口）
 */
export class HttpClient {
  private static instance: HttpClient | null = null;
  private refreshingWbi: boolean = false;

  static getInstance(): HttpClient {
    if (HttpClient.instance === null) {
      HttpClient.instance = new HttpClient();
    }
    return HttpClient.instance;
  }

  /**
   * 统一请求入口。返回 Result<data 字段原始 Object>。
   * @param url          完整 URL
   * @param method        GET / POST
   * @param params        query 参数（GET）或表单字段（POST form）
   * @param channel       Web=加 WBI 签名；App=加 AppSign+access_key；Raw=不签
   * @param useAppUa      是否使用 App UA（登录等接口）
   * @param referer       Referer 头
   * @param extraHeaders  额外请求头（App 接口风控用：buvid / App UA / fp_local 等，覆盖同名默认头）
   */
  async request(
    url: string,
    method: http.RequestMethod,
    params: Record<string, string | number | boolean>,
    channel: ChannelType,
    useAppUa: boolean = false,
    referer: string = AppConstants.REFERER,
    extraHeaders?: Record<string, string>
  ): Promise<Result<Object>> {
    try {
      let finalParams = params;
      if (channel === ChannelType.Web) {
        await this.ensureWbiKeys();
        finalParams = await WbiSigner.sign(params);
      } else if (channel === ChannelType.App) {
        const cm = CookieManager.getInstance();
        const accessKey = cm.get('access_key');
        if (accessKey.length > 0) {
          const withToken: Record<string, string | number | boolean> = {};
          const ks = Object.keys(params);
          for (let i = 0; i < ks.length; i++) {
            withToken[ks[i]] = params[ks[i]];
          }
          withToken['access_key'] = accessKey;
          finalParams = withToken;
        }
        finalParams = await AppSigner.sign(finalParams);
      }

      let requestUrl = url;
      let extraData: string | undefined = undefined;
      const query = AppSigner.toQueryString(finalParams);
      if (method === http.RequestMethod.GET) {
        requestUrl = query.length > 0 ? `${url}?${query}` : url;
      } else {
        extraData = query;
      }

      const header: Record<string, string> = {
        'User-Agent': useAppUa ? AppConstants.APP_UA : AppConstants.WEB_UA,
        'Referer': referer,
        'Cookie': CookieManager.getInstance().buildCookieHeader(),
        'env': 'prod',
        'app-key': 'android64'
      };
      // 额外头合并（同名覆盖：App 接口风控需覆盖 UA 并补 buvid/fp_local 等）
      if (extraHeaders !== undefined && extraHeaders !== null) {
        const hks = Object.keys(extraHeaders);
        for (let i = 0; i < hks.length; i++) {
          header[hks[i]] = extraHeaders[hks[i]];
        }
      }
      if (method === http.RequestMethod.POST) {
        header['Content-Type'] = 'application/x-www-form-urlencoded';
      }

      hilog.info(0x0000, TAG, '%{public}s %{public}s', method, requestUrl);
      const resp = await this.doRequest(requestUrl, method, header, extraData);
      return this.parseEnvelope(resp, requestUrl);
    } catch (e) {
      hilog.error(0x0000, TAG, 'request fail %{public}s: %{public}s', url, JSON.stringify(e));
      const err = e as BusinessErrorLike;
      if (err !== null && err !== undefined && err.code !== undefined && typeof err.code === 'number') {
        return Result.err<Object>(AppError.network(`code=${err.code}`));
      }
      return Result.err<Object>(AppError.network(JSON.stringify(e)));
    }
  }

  async get(url: string, params: Record<string, string | number | boolean>, channel: ChannelType = ChannelType.Raw,
    referer: string = AppConstants.REFERER, extraHeaders?: Record<string, string>): Promise<Result<Object>> {
    return this.request(url, http.RequestMethod.GET, params, channel, false, referer, extraHeaders);
  }

  /**
   * 裸 JSON GET：不做包络解析，返回完整 JSON 对象（用于 suggest 等非标准包络接口）
   */
  async getRawJson(url: string, params: Record<string, string | number | boolean>,
    referer: string = AppConstants.REFERER): Promise<Result<Object>> {
    try {
      const query = AppSigner.toQueryString(params);
      const requestUrl = query.length > 0 ? `${url}?${query}` : url;
      const header: Record<string, string> = {
        'User-Agent': AppConstants.WEB_UA,
        'Referer': referer,
        'Cookie': CookieManager.getInstance().buildCookieHeader()
      };
      const resp = await this.doRequest(requestUrl, http.RequestMethod.GET, header, undefined);
      if (resp.responseCode !== 200) {
        return Result.err<Object>(AppError.http(resp.responseCode));
      }
      const parsed = JSON.parse(resp.result as string) as Object;
      return Result.ok<Object>(parsed);
    } catch (e) {
      return Result.err<Object>(AppError.network(JSON.stringify(e)));
    }
  }

  async post(url: string, params: Record<string, string | number | boolean>, channel: ChannelType = ChannelType.Raw,
    useAppUa: boolean = false): Promise<Result<Object>> {
    return this.request(url, http.RequestMethod.POST, params, channel, useAppUa);
  }

  /**
   * 二进制 GET：不做包络解析，返回原始 ArrayBuffer（用于 seg.so 等 protobuf 接口）。
   * - 请求头与 getRawJson 一致（Web UA + Referer + Cookie）
   * - 非 200 / 空响应 → Result.err（调用方静默降级，不影响播放主流程）
   */
  async getBinary(url: string, params: Record<string, string | number | boolean>,
    referer: string = AppConstants.REFERER): Promise<Result<ArrayBuffer>> {
    try {
      const query = AppSigner.toQueryString(params);
      const requestUrl = query.length > 0 ? `${url}?${query}` : url;
      const header: Record<string, string> = {
        'User-Agent': AppConstants.WEB_UA,
        'Referer': referer,
        'Cookie': CookieManager.getInstance().buildCookieHeader()
      };
      hilog.info(0x0000, TAG, 'GET(binary) %{public}s', requestUrl);
      const req = http.createHttp();
      try {
        const resp = await req.request(requestUrl, {
          method: http.RequestMethod.GET,
          header: header,
          connectTimeout: AppConstants.CONNECT_TIMEOUT,
          readTimeout: AppConstants.READ_TIMEOUT,
          expectDataType: http.HttpDataType.ARRAY_BUFFER
        });
        const setCookie = resp.cookies;
        if (typeof setCookie === 'string' && setCookie.length > 0) {
          CookieManager.getInstance().absorbSetCookie(setCookie);
        }
        if (resp.responseCode !== 200) {
          return Result.err<ArrayBuffer>(AppError.http(resp.responseCode));
        }
        const body = resp.result as ArrayBuffer;
        if (body === undefined || body === null || body.byteLength === 0) {
          return Result.err<ArrayBuffer>(AppError.parse('empty binary body'));
        }
        return Result.ok<ArrayBuffer>(body);
      } finally {
        req.destroy();
      }
    } catch (e) {
      hilog.error(0x0000, TAG, 'getBinary fail %{public}s: %{public}s', url, JSON.stringify(e));
      return Result.err<ArrayBuffer>(AppError.network(JSON.stringify(e)));
    }
  }

  private async doRequest(url: string, method: http.RequestMethod, header: Record<string, string>,
    extraData: string | undefined): Promise<http.HttpResponse> {
    let attempt = 0;
    let lastError: Error | null = null;
    while (attempt <= AppConstants.MAX_RETRY) {
      const req = http.createHttp();
      try {
        const opt: http.HttpRequestOptions = {
          method: method,
          header: header,
          connectTimeout: AppConstants.CONNECT_TIMEOUT,
          readTimeout: AppConstants.READ_TIMEOUT,
          expectDataType: http.HttpDataType.STRING
        };
        if (extraData !== undefined) {
          opt.extraData = extraData;
        }
        const resp = await req.request(url, opt);
        const setCookie = resp.cookies;
        if (typeof setCookie === 'string' && setCookie.length > 0) {
          CookieManager.getInstance().absorbSetCookie(setCookie);
        }
        return resp;
      } catch (e) {
        lastError = e as Error;
        attempt++;
        hilog.warn(0x0000, TAG, 'retry %{public}d for %{public}s', attempt, url);
      } finally {
        req.destroy();
      }
    }
    throw lastError ?? new Error('request failed');
  }

  /** 包络解析 + 错误转换（拦截器职责）。业务错误（code != 0）打印日志便于定位风控等问题 */
  private parseEnvelope(resp: http.HttpResponse, url: string): Result<Object> {
    if (resp.responseCode !== 200) {
      hilog.error(0x0000, TAG, 'http %{public}d %{public}s', resp.responseCode, url);
      return Result.err<Object>(AppError.http(resp.responseCode));
    }
    const body = resp.result as string;
    let parsed: BiliEnvelope;
    try {
      parsed = JSON.parse(body) as BiliEnvelope;
    } catch (e) {
      hilog.error(0x0000, TAG, 'not json: %{public}s body=%{public}s', url, body.substring(0, 120));
      return Result.err<Object>(AppError.parse(`not json: ${body.substring(0, 120)}`));
    }
    const code = parsed.code ?? -2;
    if (code === 0) {
      return Result.ok<Object>(parsed.data !== undefined ? parsed.data : new EmptyData());
    }
    if (code === -101) {
      hilog.warn(0x0000, TAG, 'unauthorized %{public}s', url);
      return Result.err<Object>(AppError.unauthorized());
    }
    // 业务错误（如 -352 风控）：打印 code/message 与接口，方便排查
    hilog.error(0x0000, TAG, 'biz code=%{public}d msg=%{public}s url=%{public}s',
      code, parsed.message ?? '', url);
    return Result.err<Object>(AppError.business(code, parsed.message ?? `业务错误 ${code}`));
  }

  /** 确保 WBI key 可用（按天缓存，经 nav 接口刷新） */
  private async ensureWbiKeys(): Promise<void> {
    if (!WbiSigner.needRefresh() || this.refreshingWbi) {
      return;
    }
    this.refreshingWbi = true;
    try {
      const req = http.createHttp();
      const header: Record<string, string> = {
        'User-Agent': AppConstants.WEB_UA,
        'Referer': AppConstants.REFERER,
        'Cookie': CookieManager.getInstance().buildCookieHeader()
      };
      const resp = await req.request(ApiConstants.NAV, {
        method: http.RequestMethod.GET,
        header: header,
        connectTimeout: AppConstants.CONNECT_TIMEOUT,
        readTimeout: AppConstants.READ_TIMEOUT,
        expectDataType: http.HttpDataType.STRING
      });
      req.destroy();
      const env = JSON.parse(resp.result as string) as BiliEnvelope;
      const data = env.data as NavWbiData | undefined;
      const img = data?.wbi_img;
      if (img !== undefined && img.img_url !== undefined && img.sub_url !== undefined) {
        const keys = new WbiKeys();
        keys.imgKey = WbiSigner.extractKeyFromUrl(img.img_url);
        keys.subKey = WbiSigner.extractKeyFromUrl(img.sub_url);
        const d = new Date();
        const m = d.getMonth() + 1;
        const day = d.getDate();
        keys.dayStamp = `${d.getFullYear()}-${m < 10 ? '0' + m : m}-${day < 10 ? '0' + day : day}`;
        WbiSigner.setKeys(keys);
        hilog.info(0x0000, TAG, 'wbi keys refreshed');
      }
    } catch (e) {
      hilog.error(0x0000, TAG, 'refresh wbi keys fail: %{public}s', JSON.stringify(e));
    } finally {
      this.refreshingWbi = false;
    }
  }
}

/** 部分接口 code=0 但无 data 字段时的占位对象 */
class EmptyData {
}

interface WbiImgUrls {
  img_url?: string;
  sub_url?: string;
}

interface NavWbiData {
  wbi_img?: WbiImgUrls;
}

interface BusinessErrorLike {
  code?: number;
  message?: string;
}

// TAG 固定写在文件最下方
const TAG = HttpClient.name ?? 'HttpClient';
