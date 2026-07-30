import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

/**
 * 轻量 KV 持久化封装（@ohos.data.preferences）
 * 每个逻辑存储独立 preferences 文件；每个设置项独立 key，只写对应 key（AP-4）。
 */
export class PrefsStorage {
  private pref: preferences.Preferences;

  constructor(context: common.Context, name: string) {
    this.pref = preferences.getPreferencesSync(context, { name: name });
  }

  putString(key: string, value: string): void {
    this.pref.putSync(key, value);
    this.pref.flush();
  }

  getString(key: string, def: string = ''): string {
    return this.pref.getSync(key, def) as string;
  }

  putNumber(key: string, value: number): void {
    this.pref.putSync(key, value);
    this.pref.flush();
  }

  getNumber(key: string, def: number = 0): number {
    return this.pref.getSync(key, def) as number;
  }

  putBool(key: string, value: boolean): void {
    this.pref.putSync(key, value);
    this.pref.flush();
  }

  getBool(key: string, def: boolean = false): boolean {
    return this.pref.getSync(key, def) as boolean;
  }

  delete(key: string): void {
    this.pref.deleteSync(key);
    this.pref.flush();
  }

  has(key: string): boolean {
    return this.pref.hasSync(key);
  }
}
