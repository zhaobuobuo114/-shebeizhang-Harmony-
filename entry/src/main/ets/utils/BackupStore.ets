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

/**
 * 导出结局。必须把「用户取消」和「真的没写进去」分开：
 * 选择器点取消也会走到一条空返回，若统一报失败，用户每次取消都会被莫名骂一句；
 * 反过来写失败若不吭声，用户带走的就是选择器刚建好的那个 0 字节空壳。
 */
export interface ExportOutcome {
  cancelled: boolean;
  written: boolean;
}

/** 导入结局，同样要分清取消（不提示）和挑到了不相干的文件（要提示） */
export interface ImportOutcome {
  cancelled: boolean;
  snapshot: Snapshot | undefined;
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
  /**
   * 选择器默认停在"最近"，而那一页只列媒体库认识的类型，.json 一个都不显示——
   * 用户导完再点导入，看到的就是一个空列表，以为文件没生成。显式指到 Download，
   * 让导出落在哪、导入就从哪找。
   */
  private static readonly PICKER_DIR: string = 'file://docs/storage/Users/currentUser/Download';

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
      // 写失败就不能把路径交出去，否则调用方拿着一个空文件去分享，又是一次"空壳"
      return BackupStore.writeText(path, BackupStore.buildJson(snapshot)) ? path : '';
    } catch (e) {
      return '';
    }
  }

  /** 弹系统文件选择器，把数据存成一个 .json */
  static async saveViaPicker(ctx: common.UIAbilityContext, snapshot: Snapshot): Promise<ExportOutcome> {
    const dp: picker.DocumentViewPicker = new picker.DocumentViewPicker(ctx);
    const opt: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();
    opt.newFileNames = [BackupStore.fileName()];
    // fileSuffixChoices 的格式是「描述|后缀」，没有 | 时整串就是后缀。
    // 原先写的 'json' 少了个点，选择器把文件存成 device-ledger-xxxx-1155json，
    // 于是导入那边按 .json 过滤，永远看不到自己刚导出的文件。
    opt.fileSuffixChoices = ['.json'];
    opt.defaultFilePathUri = BackupStore.PICKER_DIR;
    let uris: string[] | undefined = undefined;
    try {
      uris = await dp.save(opt);
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'save at default dir failed: %{public}s', JSON.stringify(e));
    }
    if (uris === undefined) {
      // 取消是"返回空数组"，打不开才是"抛异常"，两者不能混。
      // 万一某个 ROM 不认这个默认目录，退回系统默认位置再开一次，
      // 绝不能让导出按钮变成点了没反应。
      opt.defaultFilePathUri = '';
      try {
        uris = await dp.save(opt);
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'save picker failed: %{public}s', JSON.stringify(e));
        return { cancelled: true, written: false };
      }
    }
    if (uris.length === 0) {
      return { cancelled: true, written: false };
    }
    return { cancelled: false, written: BackupStore.writeText(uris[0], BackupStore.buildJson(snapshot)) };
  }

  /** 弹系统文件选择器挑一个 .json 进来 */
  static async pickViaPicker(ctx: common.UIAbilityContext): Promise<ImportOutcome> {
    const dp: picker.DocumentViewPicker = new picker.DocumentViewPicker(ctx);
    const opt: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
    opt.maxSelectNumber = 1;
    opt.fileSuffixFilters = ['.json'];
    opt.defaultFilePathUri = BackupStore.PICKER_DIR;
    let uris: string[] | undefined = undefined;
    try {
      uris = await dp.select(opt);
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'select at default dir failed: %{public}s', JSON.stringify(e));
    }
    if (uris === undefined) {
      opt.defaultFilePathUri = '';
      try {
        uris = await dp.select(opt);
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'select picker failed: %{public}s', JSON.stringify(e));
        return { cancelled: true, snapshot: undefined };
      }
    }
    if (uris.length === 0) {
      return { cancelled: true, snapshot: undefined };
    }
    return { cancelled: false, snapshot: BackupStore.parseJson(BackupStore.readText(uris[0])) };
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

  private static isUri(path: string): boolean {
    return path.startsWith('file://');
  }

  /**
   * 写一段文本。path 有两种：应用沙箱路径，或选择器返回的 file:// URI，两者不能一视同仁——
   * `accessSync`/`mkdirSync`/`statSync` 的入参官方写的是 "Application sandbox path"，
   * 拿 URI 去调会被文件沙箱判 13900012 (Permission denied)。原先 writeText 无条件
   * 对路径做 lastIndexOf('/') + mkdirSync，导出正是死在这一步：选择器已经把空文件建好，
   * 一个字节没写的它就以"空壳文件"的形式留在了用户挑的位置。
   */
  private static writeText(path: string, text: string): boolean {
    let file: fs.File | undefined = undefined;
    try {
      if (BackupStore.isUri(path)) {
        // URI 指向的空白文件已由选择器建好，这里只要句柄；清空是必须的：
        // 用户覆盖旧文件时不清空，尾部会留下上一份的残字节，整份 JSON 就废了
        file = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
        fs.truncateSync(file.fd, 0);
      } else {
        const dirEnd: number = path.lastIndexOf('/');
        if (dirEnd > 0) {
          const dir: string = path.substring(0, dirEnd);
          if (!BackupStore.exists(dir)) {
            fs.mkdirSync(dir, true);
          }
        }
        file = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.TRUNC | fs.OpenMode.WRITE_ONLY);
      }
      const bytes: number = new util.TextEncoder().encodeInto(text).length;
      const written: number = fs.writeSync(file.fd, text);
      // 只写了一半也返回成功的话，用户带走的就是一个打不开的备份
      return written === bytes;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'write failed: %{public}s', JSON.stringify(e));
      return false;
    } finally {
      BackupStore.closeQuietly(file);
    }
  }

  /** 读一段文本；读不出来返回空串，由调用方决定怎么向用户交代 */
  private static readText(path: string): string {
    let file: fs.File | undefined = undefined;
    try {
      file = fs.openSync(path, fs.OpenMode.READ_ONLY);
      // 不能先 statSync(path) 拿大小：URI 要到 API 22 才允许传进 statSync，
      // 低一点的系统上这一步就抛 13900012。边读边收，读到文件尾为止。
      const chunks: Uint8Array[] = [];
      const chunkSize: number = 64 * 1024;
      // 轮数封顶只为防死循环；真撞到顶就当作读失败，绝不交出一份被截断的"前半截"
      const maxRounds: number = 4096;
      let total: number = 0;
      let eof: boolean = false;
      for (let round: number = 0; round < maxRounds; round++) {
        const buf: ArrayBuffer = new ArrayBuffer(chunkSize);
        const n: number = fs.readSync(file.fd, buf);
        if (n <= 0) {
          eof = true;
          break;
        }
        chunks.push(new Uint8Array(buf, 0, n));
        total += n;
      }
      if (!eof) {
        hilog.error(DOMAIN, TAG, 'read stopped early at %{public}d bytes', total);
        return '';
      }
      const all: Uint8Array = new Uint8Array(total);
      let off: number = 0;
      for (let i: number = 0; i < chunks.length; i++) {
        all.set(chunks[i], off);
        off += chunks[i].length;
      }
      const decoder: util.TextDecoder = new util.TextDecoder('utf-8');
      return decoder.decodeToString(all);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'read failed: %{public}s', JSON.stringify(e));
      return '';
    } finally {
      BackupStore.closeQuietly(file);
    }
  }

  private static closeQuietly(file: fs.File | undefined): void {
    if (file === undefined) {
      return;
    }
    try {
      fs.closeSync(file);
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'close failed: %{public}s', JSON.stringify(e));
    }
  }
}
