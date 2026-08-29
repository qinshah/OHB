import { http } from '@kit.NetworkKit';
import { bundleManager, common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { ContextUtil } from './ContextUtil';
import { Logger } from './Logger';
import { AppColors } from '../../theme/AppTheme';

/** GitHub Release 资产（仅取所需字段） */
interface GhAsset {
  name?: string;
  browser_download_url?: string;
}

/** GitHub Release（latest 接口返回结构，仅取所需字段） */
interface GhRelease {
  tag_name?: string;
  body?: string;
  html_url?: string;
  assets?: GhAsset[];
}

/** 检查更新结果 */
interface UpdateInfo {
  /** 远端最新 tag（如 v1.1.0） */
  latestTag: string;
  /** Release 页面链接（无 hap 资产时的兜底下载地址） */
  htmlUrl: string;
  /** .hap 下载直链（Release 未附带 hap 资产时为空串） */
  hapUrl: string;
  /** 更新说明（Release body） */
  notes: string;
}

/**
 * 检查更新工具
 *
 * 版本比较逻辑（与 PiliPlus 的 buildTime/commitHash 对比不同）：
 * 本地包版本（AppScope/app.json5 的 versionName） vs 仓库最新 Release 的 tag_name，
 * tag 形如 "v1.2.3"，去掉 v 前缀后按语义化版本逐段数值比较。
 */
export class UpdateUtils {
  /** GitHub 仓库 API（release tag 与 hap 下载地址的来源） */
  private static readonly REPO_API: string = 'https://api.github.com/repos/qinshah/OHB';

  /**
   * 检查更新入口
   * @param isAuto true=启动时自动检查（失败静默）；false=手动检查（有结果提示）
   */
  static async checkUpdate(isAuto: boolean): Promise<void> {
    try {
      // 1. 本地版本：包信息 versionName（如 "1.0.0"）
      const local = await UpdateUtils.getLocalVersion();
      // 2. 远端版本：仓库最新 Release 的 tag（如 "v1.1.0"）
      const res = await UpdateUtils.fetchLatestRelease();
      if (res === null) {
        if (!isAuto) {
          promptAction.showToast({ message: '检查更新失败，GitHub接口未返回数据' });
        }
        return;
      }
      // 3. 比较：tag 去掉 v 前缀后与本地版本逐段比较
      const remoteVer = res.latestTag.replace(/^v/i, '');
      if (UpdateUtils.compareVersion(local, remoteVer) >= 0) {
        if (!isAuto) {
          promptAction.showToast({ message: '已是最新版本' });
        }
        return;
      }
      // 4. 发现新版本：弹窗提示
      UpdateUtils.showUpdateDialog(local, res);
    } catch (e) {
      Logger.error('Update', `check update fail: ${JSON.stringify(e)}`);
      if (!isAuto) {
        promptAction.showToast({ message: '检查更新失败，请检查网络' });
      }
    }
  }

  /** 获取本地包版本号（versionName），接口为异步 */
  static async getLocalVersion(): Promise<string> {
    const info = await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
    return info.versionName;
  }

  /**
   * 语义化版本比较："1.10.0" vs "1.2.1" → 正数
   * @return 正数=a 更新；0=相同；负数=b 更新
   */
  static compareVersion(a: string, b: string): number {
    const pa = a.replace(/^v/i, '').split('.');
    const pb = b.replace(/^v/i, '').split('.');
    const len = Math.max(pa.length, pb.length);
    for (let i = 0; i < len; i++) {
      // 缺失的段按 0 处理，如 "1.0" 等价 "1.0.0"
      const na = i < pa.length ? Number(pa[i]) || 0 : 0;
      const nb = i < pb.length ? Number(pb[i]) || 0 : 0;
      if (na !== nb) {
        return na - nb;
      }
    }
    return 0;
  }

  /** 请求 GitHub latest Release 接口，失败/无 Release 时返回 null */
  private static async fetchLatestRelease(): Promise<UpdateInfo | null> {
    const req = http.createHttp();
    try {
      const resp = await req.request(`${UpdateUtils.REPO_API}/releases/latest`, {
        method: http.RequestMethod.GET,
        header: {
          // GitHub API 要求 UA；Accept 指定 v3 JSON
          'User-Agent': 'OHB-Update-Checker',
          'Accept': 'application/vnd.github+json'
        },
        connectTimeout: 10000,
        readTimeout: 15000,
        expectDataType: http.HttpDataType.STRING
      });
      // 404 = 仓库还没有正式 Release
      if (resp.responseCode !== 200) {
        Logger.warn('Update', `latest release api http ${resp.responseCode}`);
        return null;
      }
      const rel = JSON.parse(resp.result as string) as GhRelease;
      if (rel.tag_name === undefined || rel.tag_name.length === 0) {
        return null;
      }
      // 在资产里找 .hap 直链
      let hapUrl = '';
      const assets = rel.assets ?? [];
      for (let i = 0; i < assets.length; i++) {
        const name = assets[i].name ?? '';
        if (name.endsWith('.hap')) {
          hapUrl = assets[i].browser_download_url ?? '';
          break;
        }
      }
      const info: UpdateInfo = {
        latestTag: rel.tag_name,
        htmlUrl: rel.html_url ?? `${UpdateUtils.REPO_API.replace('api.github.com/repos', 'github.com')}/releases/latest`,
        hapUrl: hapUrl,
        notes: (rel.body ?? '').trim()
      };
      return info;
    } finally {
      req.destroy();
    }
  }

  /** 新版本弹窗：下载按钮直接用浏览器打开 hap 下载地址 */
  private static showUpdateDialog(localVersion: string, info: UpdateInfo): void {
    const message = `当前版本 ${localVersion}，最新版本 ${info.latestTag}` +
      (info.notes.length > 0 ? `\n\n${info.notes}` : '');
    AlertDialog.show({
      title: `发现新版本 ${info.latestTag}`,
      message: message,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '下载更新',
        fontColor: AppColors.BRAND,
        action: () => {
          // 优先 hap 直链，无 hap 资产时打开 Release 页面
          UpdateUtils.openInBrowser(info.hapUrl.length > 0 ? info.hapUrl : info.htmlUrl);
        }
      }
    });
  }

  /** 用系统浏览器打开链接 */
  static async openInBrowser(url: string): Promise<void> {
    try {
      const ctx = ContextUtil.context as common.UIAbilityContext;
      await ctx.openLink(url);
    } catch (e) {
      Logger.error('Update', `open link fail: ${JSON.stringify(e)}`);
      promptAction.showToast({ message: '打开链接失败' });
    }
  }
}
