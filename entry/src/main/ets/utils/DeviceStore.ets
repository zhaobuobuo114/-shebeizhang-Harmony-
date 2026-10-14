import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DeviceCalc, DeviceItem, RawDevice } from '../model/DeviceItem';
import { RawTrash, TrashCalc, TrashItem } from '../model/TrashItem';

const DOMAIN: number = 0x0001;
const TAG: string = 'DeviceStore';
const STORE_NAME: string = 'device_ledger_store';
const KEY_LIST: string = 'device_list';
const KEY_DARK: string = 'dark_mode';
const KEY_AGREED: string = 'privacy_agreed';
const KEY_TRASH: string = 'trash_list';
const KEY_BADGE: string = 'badge_state';
const KEY_BACKUP_SLOT: string = 'backup_slot';
const KEY_BACKUP_AT: string = 'backup_at';
const KEY_LANGUAGE: string = 'app_language';

/**
 * 本地持久化：使用用户首选项（Preferences）以 JSON 形式保存设备列表与主题。
 * 数据量小、读写简单，卸载应用会随之清除。
 *
 * 所有写操作都用 flushSync 而不是 flush：flush 返回的是没人等的 Promise，
 * 删除一台设备要连写两次（列表 + 回收站），中间被系统杀掉就会出现
 * "这台设备既不在列表里、也不在回收站里"的彻底丢失。同步落盘把这段窗口关掉。
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
      DeviceStore.pref.flushSync();
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
      DeviceStore.pref.flushSync();
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'save dark failed: %{public}s', JSON.stringify(e));
    }
  }

  /**
   * 界面语言：'system' 或四种 tag 之一。
   * 默认跟随系统，升级到老版本装过的应用时用户看到的仍是原来那份中文（系统为中文时）。
   */
  static loadLanguage(): string {
    if (DeviceStore.pref === undefined) {
      return 'system';
    }
    try {
      return DeviceStore.pref.getSync(KEY_LANGUAGE, 'system') as string;
    } catch (e) {
      return 'system';
    }
  }

  static saveLanguage(tag: string): void {
    if (DeviceStore.pref === undefined) {
      return;
    }
    try {
      DeviceStore.pref.putSync(KEY_LANGUAGE, tag);
      DeviceStore.pref.flushSync();
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'saveLanguage failed: %{public}s', JSON.stringify(e));
    }
  }

  /** 是否已阅读并同意隐私条款与服务条款（首次启动时确认过一次就记下来） */
  static loadAgreed(): boolean {
    if (DeviceStore.pref === undefined) {
      return false;
    }
    try {
      return DeviceStore.pref.getSync(KEY_AGREED, false) as boolean;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'read agreed failed: %{public}s', JSON.stringify(e));
      return false;
    }
  }

  static saveAgreed(agreed: boolean): void {
    if (DeviceStore.pref === undefined) {
      return;
    }
    try {
      DeviceStore.pref.putSync(KEY_AGREED, agreed);
      DeviceStore.pref.flushSync();
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'save agreed failed: %{public}s', JSON.stringify(e));
    }
  }

  /* ---------------- 回收站 ---------------- */

  /**
   * 读取回收站。超过保留期的记录在这里就被丢掉，
   * 不必另外跑清理任务——读的时候顺手做最省事，也不会漏。
   */
  static loadTrash(keepDays: number = 30): TrashItem[] {
    if (DeviceStore.pref === undefined) {
      return [];
    }
    let raw: string = '';
    try {
      raw = DeviceStore.pref.getSync(KEY_TRASH, '[]') as string;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'read trash failed: %{public}s', JSON.stringify(e));
      return [];
    }
    if (raw.length === 0) {
      return [];
    }
    const deadline: number = Date.now() - keepDays * 24 * 60 * 60 * 1000;
    const out: TrashItem[] = [];
    try {
      const parsed: RawTrash[] = JSON.parse(raw) as RawTrash[];
      for (let i: number = 0; i < parsed.length; i++) {
        const t: TrashItem = TrashCalc.normalize(parsed[i]);
        if (t.deletedAt > 0 && t.deletedAt < deadline) {
          continue;
        }
        out.push(t);
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'parse trash failed: %{public}s', JSON.stringify(e));
      return out;
    }
    return out;
  }

  /**
   * 回收站落盘写成扁平结构（设备字段 + deletedAt 同一层）。
   *
   * 以前这里是 `JSON.stringify(list)`，把内存里的 TrashItem[] 整坨写下去，
   * 变成嵌套的 `{item:{…}, deletedAt}`；而 loadTrash 认的是扁平字段。
   * 于是"存进去再读出来"这台设备就空了：回收站整屏"未命名 · ¥0 · 今天"，
   * 点恢复还会塞一台空设备回列表。安卓端 saveTrash 写的就是扁平，两端必须一致。
   */
  static saveTrash(list: TrashItem[]): void {
    if (DeviceStore.pref === undefined) {
      return;
    }
    try {
      const rows: RawTrash[] = [];
      for (let i: number = 0; i < list.length; i++) {
        rows.push(TrashCalc.toRaw(list[i]));
      }
      DeviceStore.pref.putSync(KEY_TRASH, JSON.stringify(rows));
      DeviceStore.pref.flushSync();
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'save trash failed: %{public}s', JSON.stringify(e));
    }
  }

  /* ---------------- 勋章 ---------------- */

  /** 已点亮的勋章：id -> 获得时间戳 */
  static loadBadges(): Map<string, number> {
    const out: Map<string, number> = new Map<string, number>();
    if (DeviceStore.pref === undefined) {
      return out;
    }
    let raw: string = '';
    try {
      raw = DeviceStore.pref.getSync(KEY_BADGE, '{}') as string;
    } catch (e) {
      return out;
    }
    if (raw.length === 0) {
      return out;
    }
    try {
      const obj: Record<string, number> = JSON.parse(raw) as Record<string, number>;
      const keys: string[] = Object.keys(obj);
      for (let i: number = 0; i < keys.length; i++) {
        const v: number = obj[keys[i]];
        if (v > 0) {
          out.set(keys[i], v);
        }
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'parse badges failed: %{public}s', JSON.stringify(e));
      return out;
    }
    return out;
  }

  static saveBadges(map: Map<string, number>): void {
    if (DeviceStore.pref === undefined) {
      return;
    }
    try {
      const obj: Record<string, number> = {} as Record<string, number>;
      map.forEach((value: number, key: string) => {
        obj[key] = value;
      });
      DeviceStore.pref.putSync(KEY_BADGE, JSON.stringify(obj));
      DeviceStore.pref.flushSync();
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'save badges failed: %{public}s', JSON.stringify(e));
    }
  }

  /* ---------------- 自动备份的轮转位置 ---------------- */

  /** 下一个要写入的备份槽位（1..slots） */
  static loadBackupSlot(slots: number): number {
    if (DeviceStore.pref === undefined) {
      return 1;
    }
    let v: number = 1;
    try {
      v = DeviceStore.pref.getSync(KEY_BACKUP_SLOT, 1) as number;
    } catch (e) {
      return 1;
    }
    return (v >= 1 && v <= slots) ? v : 1;
  }

  static saveBackupSlot(slot: number): void {
    if (DeviceStore.pref === undefined) {
      return;
    }
    try {
      DeviceStore.pref.putSync(KEY_BACKUP_SLOT, slot);
      DeviceStore.pref.flushSync();
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'save backup slot failed: %{public}s', JSON.stringify(e));
    }
  }

  /** 上次自动备份的时间，用来控制留快照的间隔 */
  static loadBackupAt(): number {
    if (DeviceStore.pref === undefined) {
      return 0;
    }
    try {
      return DeviceStore.pref.getSync(KEY_BACKUP_AT, 0) as number;
    } catch (e) {
      return 0;
    }
  }

  static saveBackupAt(at: number): void {
    if (DeviceStore.pref === undefined) {
      return;
    }
    try {
      DeviceStore.pref.putSync(KEY_BACKUP_AT, at);
      DeviceStore.pref.flushSync();
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'save backup at failed: %{public}s', JSON.stringify(e));
    }
  }

  /** 生成唯一 id */
  static newId(): string {
    return 'd' + Date.now().toString() + Math.floor(Math.random() * 10000).toString();
  }
}
