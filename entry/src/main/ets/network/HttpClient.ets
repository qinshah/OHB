import { http } from '@kit.NetworkKit';
import { AppConstants } from '../common/constants/AppConstants';
import { AppError } from '../common/result/AppError';
import { Result } from '../common/result/Result';
import { Logger } from '../common/utils/Logger';
import { CookieManager } from './CookieManager';
import { WbiKeys, WbiSigner } from './WbiSigner';
import { AppSigner } from './AppSigner';
import { ApiConstants } from './ApiConstants';

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
   * @param url      完整 URL
   * @param method   GET / POST
   * @param params   query 参数（GET）或表单字段（POST form）
   * @param channel  Web=加 WBI 签名；App=加 AppSign+access_key；Raw=不签
   * @param useAppUa 是否使用 App UA（登录等接口）
   */
  async request(
    url: string,
    method: http.RequestMethod,
    params: Record<string, string | number | boolean>,
    channel: ChannelType,
    useAppUa: boolean = false,
    referer: string = AppConstants.REFERER
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
      if (method === http.RequestMethod.POST) {
        header['Content-Type'] = 'application/x-www-form-urlencoded';
      }

      Logger.info('Http', `${method} ${requestUrl}`);
      const resp = await this.doRequest(requestUrl, method, header, extraData);
      return this.parseEnvelope(resp);
    } catch (e) {
      Logger.error('Http', `request fail ${url}: ${JSON.stringify(e)}`);
      const err = e as BusinessErrorLike;
      if (err !== null && err !== undefined && err.code !== undefined && typeof err.code === 'number') {
        return Result.err<Object>(AppError.network(`code=${err.code}`));
      }
      return Result.err<Object>(AppError.network(JSON.stringify(e)));
    }
  }

  async get(url: string, params: Record<string, string | number | boolean>, channel: ChannelType = ChannelType.Raw,
    referer: string = AppConstants.REFERER): Promise<Result<Object>> {
    return this.request(url, http.RequestMethod.GET, params, channel, false, referer);
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
        Logger.warn('Http', `retry ${attempt} for ${url}`);
      } finally {
        req.destroy();
      }
    }
    throw lastError ?? new Error('request failed');
  }

  /** 包络解析 + 错误转换（拦截器职责） */
  private parseEnvelope(resp: http.HttpResponse): Result<Object> {
    if (resp.responseCode !== 200) {
      return Result.err<Object>(AppError.http(resp.responseCode));
    }
    const body = resp.result as string;
    let parsed: BiliEnvelope;
    try {
      parsed = JSON.parse(body) as BiliEnvelope;
    } catch (e) {
      return Result.err<Object>(AppError.parse(`not json: ${body.substring(0, 120)}`));
    }
    const code = parsed.code ?? -2;
    if (code === 0) {
      return Result.ok<Object>(parsed.data !== undefined ? parsed.data : new EmptyData());
    }
    if (code === -101) {
      return Result.err<Object>(AppError.unauthorized());
    }
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
        Logger.info('Http', 'wbi keys refreshed');
      }
    } catch (e) {
      Logger.error('Http', `refresh wbi keys fail: ${JSON.stringify(e)}`);
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
