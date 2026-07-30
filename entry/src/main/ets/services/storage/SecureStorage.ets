import { asset } from '@kit.AssetStoreKit';
import { CryptoUtil } from '../../common/utils/CryptoUtil';
import { Logger } from '../../common/utils/Logger';

/**
 * 凭证安全存储（AP-5）
 * 基于系统 Asset Store（@ohos.security.asset）：由系统安全区加密托管，
 * Token / Cookie 等敏感数据不落明文。（与 HUKS 同级安全能力，API 更契合键值凭证场景）
 */
export class SecureStorage {
  static put(alias: string, secret: string): void {
    try {
      const attrs: asset.AssetMap = new Map();
      attrs.set(asset.Tag.ALIAS, CryptoUtil.encodeUtf8(alias));
      attrs.set(asset.Tag.SECRET, CryptoUtil.encodeUtf8(secret));
      attrs.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_FIRST_UNLOCKED);
      // 已存在则先删除再写入（等价覆盖）
      if (SecureStorage.get(alias).length > 0) {
        SecureStorage.remove(alias);
      }
      asset.addSync(attrs);
    } catch (e) {
      Logger.error('SecureStorage', `put ${alias} fail: ${JSON.stringify(e)}`);
    }
  }

  static get(alias: string): string {
    try {
      const query: asset.AssetMap = new Map();
      query.set(asset.Tag.ALIAS, CryptoUtil.encodeUtf8(alias));
      query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
      const results = asset.querySync(query);
      if (results.length === 0) {
        return '';
      }
      const secret = results[0].get(asset.Tag.SECRET);
      if (secret === undefined) {
        return '';
      }
      return CryptoUtil.decodeUtf8(secret as Uint8Array);
    } catch (e) {
      // 未找到时系统可能抛异常，按空处理
      return '';
    }
  }

  static remove(alias: string): void {
    try {
      const query: asset.AssetMap = new Map();
      query.set(asset.Tag.ALIAS, CryptoUtil.encodeUtf8(alias));
      asset.removeSync(query);
    } catch (e) {
      Logger.error('SecureStorage', `remove ${alias} fail: ${JSON.stringify(e)}`);
    }
  }
}
