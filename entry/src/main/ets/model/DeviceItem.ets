import { DateUtil } from '../utils/DateUtil';
import { resolveKind } from './DeviceKind';

/**
 * 设备条目数据模型
 * 一台设备 = 一次"固定资产投入"，记录购买日期与金额，据此计算使用天数与日均成本。
 */
export interface DeviceItem {
  id: string;          // 唯一标识
  name: string;        // 设备名称
  price: number;       // 购买价格（元）
  buyDate: string;     // 购买日期，格式 yyyy-MM-dd
  category: string;    // 设备类型 key（见 DeviceKind.ets）
  note: string;        // 备注
  favorite: boolean;   // 是否收藏（最爱）
  createdAt: number;   // 记录创建时间戳
}

/** 读取历史数据时使用的宽松结构（导出以便存储层复用同一类型） */
export interface RawDevice {
  id?: string;
  name?: string;
  price?: number;
  buyDate?: string;
  category?: string;
  note?: string;
  favorite?: boolean;
  createdAt?: number;
}

/** 与设备相关的计算逻辑 */
export class DeviceCalc {
  /** 已使用天数：含购买当天，至少 1 天 */
  static daysUsed(item: DeviceItem): number {
    return DateUtil.daysSince(item.buyDate) + 1;
  }

  /** 日均成本：价格 / 已使用天数，用得越久日均越低 */
  static avgPerDay(item: DeviceItem): number {
    const days: number = DeviceCalc.daysUsed(item);
    return item.price / (days > 0 ? days : 1);
  }

  /** 折算年限，如 1.5 年 */
  static yearsUsed(item: DeviceItem): number {
    return DeviceCalc.daysUsed(item) / 365;
  }

  /**
   * ForEach 的 key：把内容也算进去。
   * ArkUI 的 ForEach 对 key 相同的项不会重跑子组件，编辑后 key 变了才会刷新，
   * 所以 key 必须包含会变化的字段。
   *
   * 注意：故意**不**包含 favorite。收藏只是卡片右下角那颗星的状态，
   * 放进 key 会让整张卡片重建、重播一遍入场动画（点星标时卡片乱飞一下）。
   * 星标由 DeviceCard 自己维护 @State 镜像，点击即时变色。
   */
  static key(item: DeviceItem): string {
    return item.id + '#' + item.name + '#' + item.price + '#' + item.buyDate +
      '#' + item.category + '#' + item.note;
  }

  /** 兜底清洗：把历史脏数据规整成合法结构 */
  static normalize(raw: RawDevice): DeviceItem {
    const name: string = raw.name === undefined ? '' : raw.name;
    const price: number = raw.price === undefined ? 0 : raw.price;
    const buyDate: string = raw.buyDate === undefined ? DateUtil.today() : raw.buyDate;
    const created: number = raw.createdAt === undefined ? 0 : raw.createdAt;
    const id: string = raw.id === undefined ? ('d' + created + Math.floor(Math.random() * 10000)) : raw.id;
    const item: DeviceItem = {
      id: id,
      name: name,
      price: price,
      buyDate: buyDate,
      category: resolveKind(raw.category === undefined ? '' : raw.category),
      note: raw.note === undefined ? '' : raw.note,
      // 老版本数据没有 favorite 字段，缺省就是未收藏
      favorite: raw.favorite === true,
      createdAt: created
    };
    return item;
  }
}
