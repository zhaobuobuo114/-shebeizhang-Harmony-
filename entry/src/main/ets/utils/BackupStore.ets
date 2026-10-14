import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DeviceCalc, DeviceItem } from '../model/DeviceItem';
import { TrashCalc, TrashItem } from '../model/TrashItem';
import { DeviceStore } from './DeviceStore';

const DOMAIN: number = 0x0001;
const TAG: string = 'BackupStore';

/** 一份完整数据：设备 + 回收站 + 勋章 */
export interface Snapshot {
  devices: DeviceItem[];
  recycle: TrashItem[];
  badges: Map<string, number>;
  exportedAt: number;
}

export interface BackupFile {
  slot: number;
  at: number;
  deviceCount: number;
  recycleCount: number;
  badgeCount: number;
}

/* ---------------- 文件里出现的结构 ---------------- */

interface BadgeRecord {
  id: string;
  at: number;
}

interface TrashRecord {
  id: string;
  name: string;
  price: number;
  buyDate: string;
  category: string;
  note: string;
  favorite: boolean;
  createdAt: number;
  deletedAt: number;
}

interface CountsRecord {
  devices: number;
  recycle: number;
  badges: number;
}

interface RootRecord {
  app?: string;
  format?: string;
  version?: number;
  exportedAt?: number;
  kind?: string;
  devices?: DeviceItem[];
  recycle?: TrashRecord[];
  // 勋章既可能是 [{id,at}] 数组，也可能是 {id: 时间戳} 对象（后者是本机 prefs 的内部形状）
  badges?: object;
  counts?: CountsRecord;
}

/**
 * 数据的导出、导入与自动备份。
 *
 * 导出的文件是一份自描述的 JSON，鸿蒙版与安卓版**完全同一套格式**，
 * 一端导出的文件另一端能原样读进来（设备、回收站、勋章三块一起带走）。
 *
 * 自动备份写在应用私有目录里，轮流占 5 个槽位：每次数据变动前留一份快照，
 * 超出 5 份就覆盖最旧的。卸载应用会随之清除，不涉及任何权限。
 */
export class BackupStore {
  static readonly FORMAT: string = 'device-ledger';
  static readonly VERSION: number = 1;

  /** 自动备份最多保留几份 */
  static readonly SLOTS: number = 5;
  /** 回收站保留天数 */
  static readonly KEEP_DAYS: number = 30;
  /** 两次自动快照之间的最小间隔，避免连续编辑把 5 个槽位全刷成同一分钟 */
  private static readonly MIN_INTERVAL_MS: number = 60 * 1000;

  private static readonly DIR_BACKUP: string = 'backups';
  private static readonly DIR_EXPORT: string = 'export';

  private static ctx: common.UIAbilityContext | undefined = undefined;

  /** 建议在 EntryAbility 的 onWindowStageCreate 里调一次，之后所有文件操作都能自己找到目录 */
  static init(ctx: common.UIAbilityContext): void {
    BackupStore.ctx = ctx;
  }

  private static rootDir(): string {
    return BackupStore.ctx === undefined ? '' : BackupStore.ctx.filesDir;
  }

  private static slotFile(slot: number): string {
    return BackupStore.rootDir() + '/' + BackupStore.DIR_BACKUP + '/backup-' + slot + '.json';
  }

  /* ---------------- 编解码 ---------------- */

  /** 价格写进文件前统一到分，避免浮点尾巴在另一端被当成不同的值 */
  private static money(v: number): number {
    if (!isFinite(v)) {
      return 0;
    }
    return Math.round(v * 100) / 100;
  }

  private static deviceJson(it: DeviceItem): DeviceItem {
    return {
      id: it.id,
      name: it.name,
      price: BackupStore.money(it.price),
      buyDate: it.buyDate,
      category: it.category,
      note: it.note,
      favorite: it.favorite,
      createdAt: it.createdAt
    };
  }

  private static trashJson(t: TrashItem): TrashRecord {
    const d: DeviceItem = BackupStore.deviceJson(t.item);
    return {
      id: d.id,
      name: d.name,
      price: d.price,
      buyDate: d.buyDate,
      category: d.category,
      note: d.note,
      favorite: d.favorite,
      createdAt: d.createdAt,
      deletedAt: t.deletedAt
    };
  }

  /** 组装导出内容。字段与安卓端一致，便于两边人工比对 */
  static buildJson(snapshot: Snapshot, forBackup: boolean = false): string {
    const badges: BadgeRecord[] = [];
    snapshot.badges.forEach((at: number, id: string) => {
      badges.push({ id: id, at: at });
    });

    const devices: DeviceItem[] = [];
    for (let i: number = 0; i < snapshot.devices.length; i++) {
      devices.push(BackupStore.deviceJson(snapshot.devices[i]));
    }
    const recycle: TrashRecord[] = [];
    for (let i: number = 0; i < snapshot.recycle.length; i++) {
      recycle.push(BackupStore.trashJson(snapshot.recycle[i]));
    }

    const root: RootRecord = {
      app: 'DeviceLedger',
      format: BackupStore.FORMAT,
      version: BackupStore.VERSION,
      exportedAt: snapshot.exportedAt > 0 ? snapshot.exportedAt : Date.now(),
      devices: devices,
      recycle: recycle,
      badges: badges,
      counts: {
        devices: devices.length,
        recycle: recycle.length,
        badges: badges.length
      }
    };
    if (forBackup) {
      root.kind = 'auto-backup';
    }
    return JSON.stringify(root);
  }

  /**
   * 把一段文本解析成数据；认不出来返回 undefined。
   *
   * "认不出来"必须是 undefined 而不是空数据：调用方拿到 undefined 只会提示读不出来、
   * 什么都不改；而返回一个 devices 为空的 Snapshot 会被导入当成合法文件整体落盘，
   * 挑错一个 json（比如随便一份 package.json）就等于把台账清空。
   */
  static parseJson(text: string): Snapshot | undefined {
    const s: string = text.trim();
    if (s.length === 0) {
      return undefined;
    }
    try {
      if (s.startsWith('[')) {
        const arr: object[] = JSON.parse(s) as object[];
        if (!Array.isArray(arr)) {
          return undefined;
        }
        return {
          devices: BackupStore.parseDevices(arr),
          recycle: [],
          badges: new Map<string, number>(),
          exportedAt: 0
        };
      }
      if (s.startsWith('{')) {
        const root: RootRecord = JSON.parse(s) as RootRecord;
        // format 对不上就不是设备账的文件；version 比本机新则不敢猜它的意思
        if (root.format !== undefined && root.format !== BackupStore.FORMAT) {
          return undefined;
        }
        if (typeof root.version === 'number' && root.version > BackupStore.VERSION) {
          return undefined;
        }
        // 老文件可能没有 format/version，但至少得真有一/devices 数组
        if (root.devices === undefined || !Array.isArray(root.devices)) {
          return undefined;
        }
        return {
          devices: BackupStore.parseDevices(root.devices),
          recycle: BackupStore.parseRecycle(root.recycle),
          badges: BackupStore.parseBadges(root.badges),
          exportedAt: root.exportedAt === undefined ? 0 : root.exportedAt
        };
      }
      return undefined;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'parse failed: %{public}s', JSON.stringify(e));
      return undefined;
    }
  }

  private static parseDevices(arr: object[]): DeviceItem[] {
    const out: DeviceItem[] = [];
    if (arr === undefined || !Array.isArray(arr)) {
      return out;
    }
    for (let i: number = 0; i < arr.length; i++) {
      const raw: DeviceItem = arr[i] as DeviceItem;
      out.push(DeviceCalc.normalize({
        id: raw.id,
        name: raw.name,
        price: raw.price,
        buyDate: raw.buyDate,
        category: raw.category,
        note: raw.note,
        favorite: raw.favorite,
        createdAt: raw.createdAt
      }));
    }
    return out;
  }

  private static parseRecycle(arr: TrashRecord[] | undefined): TrashItem[] {
    const out: TrashItem[] = [];
    if (arr === undefined || !Array.isArray(arr)) {
      return out;
    }
    for (let i: number = 0; i < arr.length; i++) {
      const raw: TrashRecord = arr[i];
      out.push(TrashCalc.normalize({
        id: raw.id,
        name: raw.name,
        price: raw.price,
        buyDate: raw.buyDate,
        category: raw.category,
        note: raw.note,
        favorite: raw.favorite,
        createdAt: raw.createdAt,
        deletedAt: raw.deletedAt
      }));
    }
    return out;
  }

  /** 勋章在文件里可能是数组，也可能是 id -> 时间戳的对象，两种都认（与安卓版一致） */
  private static parseBadges(raw: object | undefined): Map<string, number> {
    const out: Map<string, number> = new Map<string, number>();
    if (raw === undefined || raw === null) {
      return out;
    }
    if (Array.isArray(raw)) {
      const arr: BadgeRecord[] = raw as BadgeRecord[];
      for (let i: number = 0; i < arr.length; i++) {
        const b: BadgeRecord = arr[i];
        if (b === undefined || b === null) {
          continue;
        }
        const at: number = Number(b.at);
        if (typeof b.id === 'string' && b.id.length > 0 && isFinite(at) && at > 0) {
          out.set(b.id, Math.trunc(at));
        }
      }
      return out;
    }
    const obj: Record<string, number> = raw as Record<string, number>;
    const keys: string[] = Object.keys(obj);
    for (let i: number = 0; i < keys.length; i++) {
      const at: number = Number(obj[keys[i]]);
      if (isFinite(at) && at > 0) {
        out.set(keys[i], Math.trunc(at));
      }
    }
    return out;
  }

  /* ---------------- 导入的两种落地方式 ---------------- */

  /** 合并：保留本机已有，只把不重复的补进来；勋章取更早的获得时间 */
  static merge(local: Snapshot, incoming: Snapshot): Snapshot {
    const devices: DeviceItem[] = local.devices.slice();
    const seen: Set<string> = new Set<string>();
    for (let i: number = 0; i < devices.length; i++) {
      seen.add(devices[i].id);
    }
    for (let i: number = 0; i < incoming.devices.length; i++) {
      if (!seen.has(incoming.devices[i].id)) {
        devices.push(incoming.devices[i]);
        seen.add(incoming.devices[i].id);
      }
    }

    const recycle: TrashItem[] = local.recycle.slice();
    const seenTrash: Set<string> = new Set<string>();
    for (let i: number = 0; i < recycle.length; i++) {
      seenTrash.add(recycle[i].item.id);
    }
    for (let i: number = 0; i < incoming.recycle.length; i++) {
      if (!seenTrash.has(incoming.recycle[i].item.id)) {
        recycle.push(incoming.recycle[i]);
        seenTrash.add(incoming.recycle[i].item.id);
      }
    }

    // 一台设备不能同时"在册"又在"回收站"：甲机删了 X、乙机还留着 X，合并后就会出现两份同 id。
    // 以在册为准（用户还在用），把回收站里那条同 id 的快照剔掉，否则恢复一次就多出一台重复设备。
    const liveIds: Set<string> = new Set<string>();
    for (let i: number = 0; i < devices.length; i++) {
      liveIds.add(devices[i].id);
    }
    const deduped: TrashItem[] = [];
    for (let i: number = 0; i < recycle.length; i++) {
      if (!liveIds.has(recycle[i].item.id)) {
        deduped.push(recycle[i]);
      }
    }

    const badges: Map<string, number> = new Map<string, number>(local.badges);
    incoming.badges.forEach((at: number, id: string) => {
      const has: number | undefined = badges.get(id);
      if (has === undefined || at < has) {
        badges.set(id, at);
      }
    });

    return { devices: devices, recycle: deduped, badges: badges, exportedAt: Date.now() };
  }

  /* ---------------- 自动备份 ---------------- */

  /**
   * 数据变动前留一份快照。刚备份过（60 秒内）就跳过，
   * 免得连着编辑几次就把 5 个槽位刷成同一时刻、回退空间被吃掉。
   */
  static maybeBackup(snapshot: Snapshot): boolean {
    const now: number = Date.now();
    if (now - DeviceStore.loadBackupAt() < BackupStore.MIN_INTERVAL_MS) {
      return false;
    }
    return BackupStore.writeBackup(snapshot, now);
  }

  /** 直接写一份快照（导入、恢复这类大动作前强制留底） */
  static forceBackup(snapshot: Snapshot): boolean {
    return BackupStore.writeBackup(snapshot, Date.now());
  }

  private static writeBackup(snapshot: Snapshot, now: number): boolean {
    try {
      const slot: number = DeviceStore.loadBackupSlot(BackupStore.SLOTS);
      const withTime: Snapshot = {
        devices: snapshot.devices,
        recycle: snapshot.recycle,
        badges: snapshot.badges,
        exportedAt: now
      };
      // 写失败就别推进游标：否则下一次会跳到另一槽，把"这一份已经留好了"的错误印象留下来
      if (!BackupStore.writeText(BackupStore.slotFile(slot), BackupStore.buildJson(withTime, true))) {
        return false;
      }
      DeviceStore.saveBackupSlot(slot >= BackupStore.SLOTS ? 1 : slot + 1);
      DeviceStore.saveBackupAt(now);
      return true;
    } catch (e) {
      return false;
    }
  }

  /** 列出已有快照，新的排前面 */
  static listBackups(): BackupFile[] {
    const out: BackupFile[] = [];
    for (let slot: number = 1; slot <= BackupStore.SLOTS; slot++) {
      const path: string = BackupStore.slotFile(slot);
      if (!BackupStore.exists(path)) {
        continue;
      }
      const snap: Snapshot | undefined = BackupStore.parseJson(BackupStore.readText(path));
      let at: number = snap === undefined ? 0 : snap.exportedAt;
      if (at <= 0) {
        at = BackupStore.lastModified(path);
      }
      out.push({
        slot: slot,
        at: at,
        deviceCount: snap === undefined ? 0 : snap.devices.length,
        recycleCount: snap === undefined ? 0 : snap.recycle.length,
        badgeCount: snap === undefined ? 0 : snap.badges.size
      });
    }
    out.sort((a: BackupFile, b: BackupFile) => b.at - a.at);
    return out;
  }

  /** 读取某一槽位的快照内容 */
  static readBackup(slot: number): Snapshot | undefined {
    const path: string = BackupStore.slotFile(slot);
    if (!BackupStore.exists(path)) {
      return undefined;
    }
    return BackupStore.parseJson(BackupStore.readText(path));
  }

  /* ---------------- 导出用的临时文件 ---------------- */

  /** 导出文件名：device-ledger-20261010-2045.json */
  static fileName(at: number = Date.now()): string {
    const d: Date = new Date(at);
    const p = (n: number): string => (n < 10 ? '0' + n : '' + n);
    return 'device-ledger-' + d.getFullYear().toString() +
      p(d.getMonth() + 1) + p(d.getDate()) + '-' +
      p(d.getHours()) + p(d.getMinutes()) + '.json';
  }

  /**
   * 在私有目录里写出一份待分享 / 待发送的文件，返回它的路径。
   * 目录里只留最近那一份，别让临时文件越堆越多。
   */
  static writeExportFile(snapshot: Snapshot): string {
    const dir: string = BackupStore.rootDir() + '/' + BackupStore.DIR_EXPORT;
    try {
      if (!BackupStore.exists(dir)) {
        fs.mkdirSync(dir, true);
      }
      const old: string[] = fs.listFileSync(dir);
      for (let i: number = 0; i < old.length; i++) {
        const p: string = dir + '/' + old[i];
        if (BackupStore.isFile(p)) {
          fs.unlinkSync(p);
        }
      }
      const path: string = dir + '/' + BackupStore.fileName();
      BackupStore.writeText(path, BackupStore.buildJson(snapshot));
      return path;
    } catch (e) {
      return '';
    }
  }

  /** 弹系统文件选择器，把数据存成一个 .json；返回是否存成 */
  static async saveViaPicker(ctx: common.UIAbilityContext, snapshot: Snapshot): Promise<boolean> {
    try {
      const dp: picker.DocumentViewPicker = new picker.DocumentViewPicker(ctx);
      const opt: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();
      opt.newFileNames = [BackupStore.fileName()];
      opt.fileSuffixChoices = ['json'];
      const uris: string[] = await dp.save(opt);
      if (uris.length === 0) {
        return false;
      }
      return BackupStore.writeText(uris[0], BackupStore.buildJson(snapshot));
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'save picker failed: %{public}s', JSON.stringify(e));
      return false;
    }
  }

  /** 弹系统文件选择器挑一个 .json 进来；返回解析结果，取消则返回 undefined */
  static async pickViaPicker(ctx: common.UIAbilityContext): Promise<Snapshot | undefined> {
    try {
      const dp: picker.DocumentViewPicker = new picker.DocumentViewPicker(ctx);
      const opt: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
      opt.maxSelectNumber = 1;
      opt.fileSuffixFilters = ['.json'];
      const uris: string[] = await dp.select(opt);
      if (uris.length === 0) {
        return undefined;
      }
      return BackupStore.parseJson(BackupStore.readText(uris[0]));
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'select picker failed: %{public}s', JSON.stringify(e));
      return undefined;
    }
  }

  /* ---------------- 文件读写的小工具 ---------------- */

  private static exists(path: string): boolean {
    try {
      return fs.accessSync(path);
    } catch (e) {
      return false;
    }
  }

  private static isFile(path: string): boolean {
    try {
      return fs.statSync(path).isFile();
    } catch (e) {
      return false;
    }
  }

  /**
   * 文件的最后修改时间，**毫秒**。
   *
   * `@ohos.file.fs` 的 `Stat.mtime` 官方说明是 "the number of **seconds** elapsed since
   * 00:00:00 on January 1, 1970"（要纳秒另有 `mtimeNs`），而调用方
   * （`DateUtil.formatClock` → `new Date(at)`）按毫秒解释。原先直接返回秒值，
   * 只要某个槽位的快照解析失败走到这条回退路径，面板上就会显示一个 1970 年的时间，
   * 还会被时间排序甩到列表末尾。安卓端用的是 `File.lastModified()`，本来就是毫秒。
   */
  private static lastModified(path: string): number {
    try {
      return fs.statSync(path).mtime * 1000;
    } catch (e) {
      return 0;
    }
  }

  private static writeText(path: string, text: string): boolean {
    try {
      const dirEnd: number = path.lastIndexOf('/');
      if (dirEnd > 0) {
        const dir: string = path.substring(0, dirEnd);
        if (!BackupStore.exists(dir)) {
          fs.mkdirSync(dir, true);
        }
      }
      const file: fs.File = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.TRUNC | fs.OpenMode.WRITE_ONLY);
      fs.writeSync(file.fd, text);
      fs.closeSync(file);
      return true;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'write failed: %{public}s', JSON.stringify(e));
      return false;
    }
  }

  private static readText(path: string): string {
    try {
      const size: number = fs.statSync(path).size;
      const buf: ArrayBuffer = new ArrayBuffer(size);
      const file: fs.File = fs.openSync(path, fs.OpenMode.READ_ONLY);
      fs.readSync(file.fd, buf);
      fs.closeSync(file);
      const decoder: util.TextDecoder = new util.TextDecoder('utf-8');
      return decoder.decodeToString(new Uint8Array(buf));
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'read failed: %{public}s', JSON.stringify(e));
      return '';
    }
  }
}
