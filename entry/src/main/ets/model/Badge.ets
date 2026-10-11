import { DeviceCalc, DeviceItem } from './DeviceItem';
import { DateUtil } from '../utils/DateUtil';

/**
 * 里程碑勋章：给记设备这件事配上一点达成感。
 *
 * 判定只看本机已有的数据，达成即永久点亮并记录获得日期——
 * 之后即便数字回落（比如删掉设备导致总投入下降），勋章也不会熄灭，
 * 这一点和 QQ 的勋章墙一致：拿到过就是拿到过。
 *
 * 清单、id、名称、达成条件文案必须与安卓端逐项一致——导出文件里只写 id，
 * 这三样对不上，从一端导出的文件在另一端就会认错或认不出勋章。
 * 图案（icon）是各端自己的呈现物，不参与互通：安卓与鸿蒙共用同一批插画，
 * 改图案不需要动另一端，改上面三样必须同时改两端。
 */
export interface BadgeDef {
  id: string;      // 唯一标识，写进导出文件
  name: string;    // 勋章名
  desc: string;    // 达成条件说明
  icon: Resource;  // 专属徽章插画（resources/base/media/badge_*.png）
}

/** 一次判定需要的全部统计量 */
export interface BadgeStat {
  count: number;     // 设备台数
  total: number;     // 总投入
  fav: number;       // 收藏台数
  maxDays: number;   // 用得最久的那台用了多少天
  kinds: number;     // 覆盖了多少种设备类型
  minAvg: number;    // 最低的日均成本
  maxPrice: number;  // 单台最高价
}

export class Badges {
  /** 达成过就不再熄灭 */
  static readonly KEEP_AFTER_DELETE: boolean = true;

  /** 总览卡胶囊里那颗通用奖牌：不随解锁情况变化，只当"勋章"这件事的门面 */
  static readonly MEDAL: Resource = $r('app.media.badge_medal');

  static readonly ALL: BadgeDef[] = [
    { id: 'first_device', name: '初次见面', desc: '记录第一台设备', icon: $r('app.media.badge_first_device') },
    { id: 'count_10', name: '十全十美', desc: '设备数达到 10 台', icon: $r('app.media.badge_count_10') },
    { id: 'count_25', name: '成群结队', desc: '设备数达到 25 台', icon: $r('app.media.badge_count_25') },
    { id: 'spend_1k', name: '小有积蓄', desc: '总投入超过 1000 元', icon: $r('app.media.badge_spend_1k') },
    { id: 'spend_10k', name: '万元户', desc: '总投入超过 10000 元', icon: $r('app.media.badge_spend_10k') },
    { id: 'spend_50k', name: '家底殷实', desc: '总投入超过 50000 元', icon: $r('app.media.badge_spend_50k') },
    { id: 'fav_3', name: '心头好', desc: '收藏 3 台设备', icon: $r('app.media.badge_fav_3') },
    { id: 'fav_10', name: '宠爱有加', desc: '收藏 10 台设备', icon: $r('app.media.badge_fav_10') },
    { id: 'days_365', name: '长情相伴', desc: '有设备用满 365 天', icon: $r('app.media.badge_days_365') },
    { id: 'days_1095', name: '三年之约', desc: '有设备用满 1095 天', icon: $r('app.media.badge_days_1095') },
    { id: 'kind_8', name: '品类达人', desc: '覆盖 8 种设备类型', icon: $r('app.media.badge_kind_8') },
    { id: 'kind_20', name: '面面俱到', desc: '覆盖 20 种设备类型', icon: $r('app.media.badge_kind_20') },
    { id: 'roi', name: '回本达人', desc: '有设备日均低于 0.5 元', icon: $r('app.media.badge_roi') },
    { id: 'big_ticket', name: '大手笔', desc: '单台设备超过 5000 元', icon: $r('app.media.badge_big_ticket') }
  ];

  static byId(id: string): BadgeDef | undefined {
    for (let i: number = 0; i < Badges.ALL.length; i++) {
      if (Badges.ALL[i].id === id) {
        return Badges.ALL[i];
      }
    }
    return undefined;
  }

  /** 从设备列表算出判定所需的统计量 */
  static statOf(list: DeviceItem[]): BadgeStat {
    let total: number = 0;
    let fav: number = 0;
    let maxDays: number = 0;
    let minAvg: number = Number.MAX_VALUE;
    let maxPrice: number = 0;
    const kinds: Set<string> = new Set<string>();
    for (let i: number = 0; i < list.length; i++) {
      const it: DeviceItem = list[i];
      total += it.price;
      if (it.favorite) {
        fav += 1;
      }
      const days: number = DeviceCalc.daysUsed(it);
      if (days > maxDays) {
        maxDays = days;
      }
      const avg: number = DeviceCalc.avgPerDay(it);
      if (avg < minAvg) {
        minAvg = avg;
      }
      if (it.price > maxPrice) {
        maxPrice = it.price;
      }
      kinds.add(it.category);
    }
    return {
      count: list.length,
      total: total,
      fav: fav,
      maxDays: maxDays,
      kinds: kinds.size,
      minAvg: minAvg,
      maxPrice: maxPrice
    };
  }

  /** 当前数据满足了哪些勋章（返回 id 集合） */
  static satisfied(s: BadgeStat): Set<string> {
    const out: Set<string> = new Set<string>();
    if (s.count >= 1) {
      out.add('first_device');
    }
    if (s.count >= 10) {
      out.add('count_10');
    }
    if (s.count >= 25) {
      out.add('count_25');
    }
    if (s.total >= 1000) {
      out.add('spend_1k');
    }
    if (s.total >= 10000) {
      out.add('spend_10k');
    }
    if (s.total >= 50000) {
      out.add('spend_50k');
    }
    if (s.fav >= 3) {
      out.add('fav_3');
    }
    if (s.fav >= 10) {
      out.add('fav_10');
    }
    if (s.maxDays >= 365) {
      out.add('days_365');
    }
    if (s.maxDays >= 1095) {
      out.add('days_1095');
    }
    if (s.kinds >= 8) {
      out.add('kind_8');
    }
    if (s.kinds >= 20) {
      out.add('kind_20');
    }
    if (s.count > 0 && s.minAvg < 0.5) {
      out.add('roi');
    }
    if (s.maxPrice >= 5000) {
      out.add('big_ticket');
    }
    return out;
  }

  /**
   * 对照数据重新判定，把新达成的写进已有的状态表。
   * 返回本次**新点亮**的勋章（供界面弹一句提示），已点亮的不重复返回。
   */
  static evaluate(list: DeviceItem[], state: Map<string, number>): BadgeDef[] {
    const hit: Set<string> = Badges.satisfied(Badges.statOf(list));
    const now: number = Date.now();
    const fresh: BadgeDef[] = [];
    for (let i: number = 0; i < Badges.ALL.length; i++) {
      const def: BadgeDef = Badges.ALL[i];
      if (hit.has(def.id) && !state.has(def.id)) {
        state.set(def.id, now);
        fresh.push(def);
      }
    }
    return fresh;
  }

  /** 勋章获得日期的展示文案，如「2026.03.05」 */
  static dateText(at: number): string {
    return DateUtil.formatStamp(at);
  }
}
