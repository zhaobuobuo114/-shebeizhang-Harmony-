import { DeviceCalc, DeviceItem } from './DeviceItem';

/**
 * 回收站条目：删进来的那台设备的完整快照，外加一个删除时间。
 *
 * 存的是快照而不是引用——设备从列表里摘掉之后，回收站照样能原样放回去，
 * 收藏、备注、创建时间一个字段都不会丢。
 */
export interface TrashItem {
  item: DeviceItem;
  deletedAt: number;
}

/**
 * 从盘上读出来的宽松结构。
 *
 * 两种形状都要认：
 * - 扁平（设备字段 + deletedAt 同一层）——与安卓版 DeviceStore.saveTrash、
 *   与两端通用的备份文件 BackupStore.trashJson 都是这一种；
 * - 嵌套 `{item:{…}, deletedAt}`——旧版鸿蒙 saveTrash 直接把内存里的
 *   TrashItem[] 整坨 JSON.stringify 落盘留下的数据。
 * 只认扁平的话，老数据里的设备名/价格/购买日会被读成空值，
 * 回收站整屏变成"未命名 · ¥0 · 今天"，点恢复还会塞一台空设备回列表。
 */
export interface RawTrash {
  id?: string;
  name?: string;
  price?: number;
  buyDate?: string;
  category?: string;
  note?: string;
  favorite?: boolean;
  createdAt?: number;
  deletedAt?: number;
  item?: RawTrash;
}

export class TrashCalc {
  private static readonly DAY_MS: number = 24 * 60 * 60 * 1000;

  /** 兜底清洗：deletedAt 缺失、为 null 或不是合法数字就按"刚刚"算 */
  static normalize(raw: RawTrash): TrashItem {
    const src: RawTrash = raw.item !== undefined ? raw.item : raw;
    const item: DeviceItem = DeviceCalc.normalize({
      id: src.id,
      name: src.name,
      price: src.price,
      buyDate: src.buyDate,
      category: src.category,
      note: src.note,
      favorite: src.favorite,
      createdAt: src.createdAt
    });
    const atNum: number = typeof raw.deletedAt === 'number' ? raw.deletedAt : Number(raw.deletedAt);
    const at: number = isFinite(atNum) && atNum > 0 ? Math.trunc(atNum) : Date.now();
    return { item: item, deletedAt: at };
  }

  /** 落盘用的扁平结构：字段顺序与安卓端 DeviceStore.saveTrash、与备份文件一致 */
  static toRaw(t: TrashItem): RawTrash {
    return {
      id: t.item.id,
      name: t.item.name,
      price: t.item.price,
      buyDate: t.item.buyDate,
      category: t.item.category,
      note: t.item.note,
      favorite: t.item.favorite,
      createdAt: t.item.createdAt,
      deletedAt: t.deletedAt
    };
  }

  /** 距离自动清除还剩几天（已经过期的返回 0） */
  static daysLeft(t: TrashItem, keepDays: number): number {
    const passed: number = Math.floor((Date.now() - t.deletedAt) / TrashCalc.DAY_MS);
    const left: number = keepDays - passed;
    return left > 0 ? left : 0;
  }
}
