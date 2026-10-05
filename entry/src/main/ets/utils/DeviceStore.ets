import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DeviceCalc, DeviceItem, RawDevice } from '../model/DeviceItem';

const DOMAIN: number = 0x0001;
const TAG: string = 'DeviceStore';
const STORE_NAME: string = 'device_ledger_store';
const KEY_LIST: string = 'device_list';
const KEY_DARK: string = 'dark_mode';

/**
 * 本地持久化：使用用户首选项（Preferences）以 JSON 形式保存设备列表与主题。
 * 数据量小、读写简单，卸载应用会随之清除。
 */
export class DeviceStore {
  private static pref: preferences.Preferences | undefined = undefined;

  /** 建议在 EntryAbility 的 onWindowStageCreate 中调用一次 */
  static init(context: common.UIAbilityContext): void {
    try {
      DeviceStore.pref = preferences.getPreferencesSync(context, { name: STORE_NAME });
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'init failed: %{public}s', JSON.stringify(e));
    }
  }

  /** 静态初始化（无 UIAbilityContext 时也能用，例如 EntryAbility.onCreate 里读主题） */
  static initByContext(context: common.Context): void {
    try {
      DeviceStore.pref = preferences.getPreferencesSync(context, { name: STORE_NAME });
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'initByContext failed: %{public}s', JSON.stringify(e));
    }
  }

  /** 读取全部设备 */
  static load(): DeviceItem[] {
    if (DeviceStore.pref === undefined) {
      return [];
    }
    let raw: string = '';
    try {
      raw = DeviceStore.pref.getSync(KEY_LIST, '[]') as string;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'read failed: %{public}s', JSON.stringify(e));
      return [];
    }
    if (raw.length === 0) {
      return [];
    }
    try {
      const parsed: RawDevice[] = JSON.parse(raw) as RawDevice[];
      const out: DeviceItem[] = [];
      for (let i: number = 0; i < parsed.length; i++) {
        out.push(DeviceCalc.normalize(parsed[i]));
      }
      return out;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'parse failed: %{public}s', JSON.stringify(e));
      return [];
    }
  }

  /** 整体写回 */
  static save(list: DeviceItem[]): void {
    if (DeviceStore.pref === undefined) {
      return;
    }
    try {
      DeviceStore.pref.putSync(KEY_LIST, JSON.stringify(list));
      DeviceStore.pref.flush();
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'save failed: %{public}s', JSON.stringify(e));
    }
  }

  /** 读取上次选择的主题 */
  static loadDark(): boolean {
    if (DeviceStore.pref === undefined) {
      return false;
    }
    try {
      return DeviceStore.pref.getSync(KEY_DARK, false) as boolean;
    } catch (e) {
      return false;
    }
  }

  static saveDark(dark: boolean): void {
    if (DeviceStore.pref === undefined) {
      return;
    }
    try {
      DeviceStore.pref.putSync(KEY_DARK, dark);
      DeviceStore.pref.flush();
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'save dark failed: %{public}s', JSON.stringify(e));
    }
  }

  /** 生成唯一 id */
  static newId(): string {
    return 'd' + Date.now().toString() + Math.floor(Math.random() * 10000).toString();
  }
}
