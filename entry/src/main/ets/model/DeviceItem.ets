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

  /**
   * 兜底清洗：把历史脏数据规整成合法结构。
   *
   * 导入的文件来自外部，字段类型未必可信——null、数字写成字符串、日期不补零
   * 都可能出现在 JSON 里，而 ArkTS 的 `as` 只是骗过编译器、不做任何运行时转换，
   * 脏值一旦进列表就会一路扩散（日均变 NaN、汇总变 ¥NaN、null.split() 直接抛）。
   * 所以这里逐字段做真实的类型与取值收敛，保证出门的都是合法 DeviceItem。
   */
  static normalize(raw: RawDevice): DeviceItem {
    const name: string = typeof raw.name === 'string' ? raw.name : '';
    const note: string = typeof raw.note === 'string' ? raw.note : '';
    const categoryKey: string = typeof raw.category === 'string' ? raw.category : '';
    const rawId: string = typeof raw.id === 'string' ? raw.id : '';
    const rawDate: string = typeof raw.buyDate === 'string' ? raw.buyDate : '';

    const priceNum: number = typeof raw.price === 'number' ? raw.price : Number(raw.price);
    // 录入面板本来就禁止 0 与负数，负价只可能来自被改坏的文件；钳成 0 免得把扇形图算出负百分比
    const price: number = isFinite(priceNum) && priceNum > 0 ? priceNum : 0;

    const createdNum: number = typeof raw.createdAt === 'number' ? raw.createdAt : Number(raw.createdAt);
    const created: number = isFinite(createdNum) && createdNum > 0 ? Math.trunc(createdNum) : 0;

    const item: DeviceItem = {
      id: rawId.length > 0 ? rawId : ('d' + created + Math.floor(Math.random() * 10000)),
      name: name,
      price: price,
      buyDate: DateUtil.sanitize(rawDate),
      category: resolveKind(categoryKey),
      note: note,
      // 老版本数据没有 favorite 字段，缺省就是未收藏
      favorite: raw.favorite === true,
      createdAt: created
    };
    return item;
  }
}
