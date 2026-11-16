import preferences from '@ohos.data.preferences';
import { common } from '@kit.AbilityKit';

/**
 * 轻量 KV（01 §FR-13 / §8）：只存「最后一次快照 + 版本 + 设置」，
 * 权威数据在 RDB（CaseDb）；Preferences 是加速层，丢了能重建。
 */
export class Prefs {
  private static store: preferences.Preferences | null = null;

  static readonly KEY_SNAPSHOT: string = 'snapshot.v1';
  static readonly KEY_SEQ: string = 'snapshot.seq';
  static readonly KEY_CONTENT_VERSION: string = 'content.version';
  static readonly KEY_FONT_SCALE: string = 'settings.fontScale';
  static readonly KEY_SFX: string = 'settings.sfxOn';
  static readonly KEY_REDUCE_MOTION: string = 'settings.reduceMotion';

  static async init(context: common.UIAbilityContext): Promise<void> {
    Prefs.store = await preferences.getPreferences(context, 'campus_case_pref');
  }

  private static need(): preferences.Preferences {
    if (Prefs.store === null) {
      throw new Error('Prefs 未初始化');
    }
    return Prefs.store as preferences.Preferences;
  }

  static async putString(key: string, value: string): Promise<void> {
    await Prefs.need().put(key, value);
    await Prefs.need().flush();
  }

  static async getString(key: string, def: string): Promise<string> {
    const v = await Prefs.need().get(key, def);
    return typeof v === 'string' ? v as string : def;
  }

  static async putNumber(key: string, value: number): Promise<void> {
    await Prefs.need().put(key, value);
    await Prefs.need().flush();
  }

  static async getNumber(key: string, def: number): Promise<number> {
    const v = await Prefs.need().get(key, def);
    return typeof v === 'number' ? v as number : def;
  }

  static async putBoolean(key: string, value: boolean): Promise<void> {
    await Prefs.need().put(key, value);
    await Prefs.need().flush();
  }

  static async getBoolean(key: string, def: boolean): Promise<boolean> {
    const v = await Prefs.need().get(key, def);
    return typeof v === 'boolean' ? v as boolean : def;
  }

  /** 清空进度（保留设置）。 */
  static async clearProgress(): Promise<void> {
    await Prefs.need().delete(Prefs.KEY_SNAPSHOT);
    await Prefs.need().delete(Prefs.KEY_SEQ);
    await Prefs.need().flush();
  }
}
