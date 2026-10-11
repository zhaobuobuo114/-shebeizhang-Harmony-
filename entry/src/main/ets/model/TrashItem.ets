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

/** 从文件里读出来的宽松结构：设备字段 + 删除时间 */
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
}

export class TrashCalc {
  private static readonly DAY_MS: number = 24 * 60 * 60 * 1000;

  /** 兜底清洗：deletedAt 缺失、为 null 或不是合法数字就按"刚刚"算 */
  static normalize(raw: RawTrash): TrashItem {
    const item: DeviceItem = DeviceCalc.normalize({
      id: raw.id,
      name: raw.name,
      price: raw.price,
      buyDate: raw.buyDate,
      category: raw.category,
      note: raw.note,
      favorite: raw.favorite,
      createdAt: raw.createdAt
    });
    const atNum: number = typeof raw.deletedAt === 'number' ? raw.deletedAt : Number(raw.deletedAt);
    const at: number = isFinite(atNum) && atNum > 0 ? Math.trunc(atNum) : Date.now();
    return { item: item, deletedAt: at };
  }

  /** 距离自动清除还剩几天（已经过期的返回 0） */
  static daysLeft(t: TrashItem, keepDays: number): number {
    const passed: number = Math.floor((Date.now() - t.deletedAt) / TrashCalc.DAY_MS);
    const left: number = keepDays - passed;
    return left > 0 ? left : 0;
  }
}
