import { DeviceCalc, DeviceItem } from './DeviceItem';
import { DateUtil } from '../utils/DateUtil';
import { I18n } from '../utils/I18n';

/**
 * 里程碑勋章：给记设备这件事配上一点达成感。
 *
 * 判定只看本机已有的数据，达成即永久点亮并记录获得日期——
 * 之后即便数字回落（比如删掉设备导致总投入下降），勋章也不会熄灭，
 * 这一点和 QQ 的勋章墙一致：拿到过就是拿到过。
 *
 * 清单、id、达成条件必须与安卓端逐项一致——导出文件里只写 id，
 * 这三样对不上，从一端导出的文件在另一端就会认错或认不出勋章。
 * 图案（icon）是各端自己的呈现物，不参与互通：安卓与鸿蒙共用同一批插画，
 * 改图案不需要动另一端，改上面三样必须同时改两端。
 *
 * 名称与条件文案（nameKey/descKey）是四语言表里的资源键，表里存的必须与
 * _i18n_master.json 的 badge_<id>_name / badge_<id>_desc 对齐；
 * 展示一律走 Badges.nameOf/descOf，不要在本表里写死任何文案。
 */
export interface BadgeDef {
  id: string;       // 唯一标识，写进导出文件
  nameKey: string;  // 勋章名的资源键：badge_<id>_name
  descKey: string;  // 达成条件说明的资源键：badge_<id>_desc
  icon: Resource;   // 专属徽章插画（resources/base/media/badge_*.png）
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
  /** 总览卡胶囊里那颗通用奖牌：不随解锁情况变化，只当"勋章"这件事的门面 */
  static readonly MEDAL: Resource = $r('app.media.badge_medal');

  static readonly ALL: BadgeDef[] = [
    { id: 'first_device', nameKey: 'badge_first_device_name', descKey: 'badge_first_device_desc', icon: $r('app.media.badge_first_device') },
    { id: 'count_10', nameKey: 'badge_count_10_name', descKey: 'badge_count_10_desc', icon: $r('app.media.badge_count_10') },
    { id: 'count_25', nameKey: 'badge_count_25_name', descKey: 'badge_count_25_desc', icon: $r('app.media.badge_count_25') },
    { id: 'spend_1k', nameKey: 'badge_spend_1k_name', descKey: 'badge_spend_1k_desc', icon: $r('app.media.badge_spend_1k') },
    { id: 'spend_10k', nameKey: 'badge_spend_10k_name', descKey: 'badge_spend_10k_desc', icon: $r('app.media.badge_spend_10k') },
    { id: 'spend_50k', nameKey: 'badge_spend_50k_name', descKey: 'badge_spend_50k_desc', icon: $r('app.media.badge_spend_50k') },
    { id: 'fav_3', nameKey: 'badge_fav_3_name', descKey: 'badge_fav_3_desc', icon: $r('app.media.badge_fav_3') },
    { id: 'fav_10', nameKey: 'badge_fav_10_name', descKey: 'badge_fav_10_desc', icon: $r('app.media.badge_fav_10') },
    { id: 'days_365', nameKey: 'badge_days_365_name', descKey: 'badge_days_365_desc', icon: $r('app.media.badge_days_365') },
    { id: 'days_1095', nameKey: 'badge_days_1095_name', descKey: 'badge_days_1095_desc', icon: $r('app.media.badge_days_1095') },
    { id: 'kind_8', nameKey: 'badge_kind_8_name', descKey: 'badge_kind_8_desc', icon: $r('app.media.badge_kind_8') },
    { id: 'kind_20', nameKey: 'badge_kind_20_name', descKey: 'badge_kind_20_desc', icon: $r('app.media.badge_kind_20') },
    { id: 'roi', nameKey: 'badge_roi_name', descKey: 'badge_roi_desc', icon: $r('app.media.badge_roi') },
    { id: 'big_ticket', nameKey: 'badge_big_ticket_name', descKey: 'badge_big_ticket_desc', icon: $r('app.media.badge_big_ticket') }
  ];

  /** 勋章名：每次现取，切换语言后勋章墙与弹屏立刻跟着变 */
  static nameOf(def: BadgeDef): string {
    return I18n.t(def.nameKey);
  }

  /** 达成条件说明 */
  static descOf(def: BadgeDef): string {
    return I18n.t(def.descKey);
  }

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

  /**
   * 勋章获得日期，只给日期本身（如「2026.03.05」/「Mar 5, 2026」，按当前语言）。
   * 「{0} 达成」这句完整文案由调用方用 I18n.t('badge_unlocked_at', …) 组装，
   * 这里不掺文案——英文是「Earned Mar 5, 2026」，语序和中文相反，
   * 在本表里拼死语序就没法跟着语言走了。
   */
  static dateText(at: number): string {
    return DateUtil.formatStamp(at);
  }
}
