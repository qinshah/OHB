import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';

/** 加解密/编码工具 */
export class CryptoUtil {
  /** MD5（十六进制小写），WBI/App 签名使用 */
  static async md5Hex(input: string): Promise<string> {
    const md = cryptoFramework.createMd('MD5');
    const encoder = util.TextEncoder.create('utf-8');
    await md.update({ data: encoder.encodeInto(input) });
    const blob = await md.digest();
    return CryptoUtil.bytesToHex(blob.data);
  }

  static bytesToHex(bytes: Uint8Array): string {
    const hex: string[] = [];
    for (let i = 0; i < bytes.length; i++) {
      const h = bytes[i].toString(16);
      hex.push(h.length === 1 ? `0${h}` : h);
    }
    return hex.join('');
  }

  static encodeUtf8(input: string): Uint8Array {
    return util.TextEncoder.create('utf-8').encodeInto(input);
  }

  static decodeUtf8(bytes: Uint8Array): string {
    return util.TextDecoder.create('utf-8').decodeToString(bytes);
  }

  /** 随机十六进制串 */
  static randomHex(byteLen: number): string {
    const rand = cryptoFramework.createRandom();
    const blob = rand.generateRandomSync(byteLen);
    return CryptoUtil.bytesToHex(blob.data);
  }
}
