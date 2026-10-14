import { I18n, Lang } from './I18n';

/** 日期工具：统一按本地时区、按"自然日"计算，避免时区和时分秒带来的误差。
 *
 * 关于本地化的分工：`format/parse/sanitize/daysSince/today/pad/epochDay`
 * 与 yyyy-MM-dd 这套**存储格式**一律与语言无关——它是数据格式，也是和安卓版
 * 导出文件之间的跨端契约，任何时候都不能因为界面语言而改变。
 * 只有 displayDate / formatStamp / formatClock / humanDays 这四个"给人看"的方法
 * 才按当前语言取写法。
 */
export class DateUtil {
  private static readonly DAY_MS: number = 24 * 60 * 60 * 1000;

  /**
   * 英文月份缩写。刻意写死在这里而不用 Intl：
   * Intl 读的是**系统** locale，而本应用的语言是应用内偏好（可以跟系统不一致），
   * 用 Intl 会出现"界面是英文、日期却是系统语言"的错配。
   */
  private static readonly MONTHS_EN: string[] = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  /** 数字补零 */
  static pad(n: number): string {
    return n < 10 ? '0' + n : '' + n;
  }

  /** 组装 yyyy-MM-dd */
  static format(year: number, month: number, day: number): string {
    return year + '-' + DateUtil.pad(month) + '-' + DateUtil.pad(day);
  }

  /** 今天的日期字符串 */
  static today(): string {
    const d: Date = new Date();
    return DateUtil.format(d.getFullYear(), d.getMonth() + 1, d.getDate());
  }

  /** yyyy-MM-dd -> Date（当日 00:00:00） */
  static parse(dateStr: string): Date {
    const parts: string[] = dateStr.split('-');
    const y: number = parseInt(parts[0], 10);
    const m: number = parseInt(parts[1], 10);
    const d: number = parseInt(parts[2], 10);
    return new Date(y, m - 1, d);
  }

  /**
   * 某一天在本地时区的"日序号"：取当天正午的时间戳整除一天毫秒数。
   * 与安卓版 DateUtil.epochDay 同构——正午离夏令时切换点最远，整天相减不会
   * 出现 ±1 天；整除用 trunc 而不是 floor，也是为跟安卓的 Long 除法对齐。
   */
  private static epochDay(year: number, month: number, day: number): number {
    const d: Date = new Date(year, month - 1, day, 12, 0, 0, 0);
    return Math.trunc(d.getTime() / DateUtil.DAY_MS);
  }

  /** 从 dateStr 到今天，相差多少个自然日（今天为 0，未来或读不懂的串返回 0） */
  static daysSince(dateStr: string): number {
    const target: Date = DateUtil.parse(dateStr);
    if (isNaN(target.getTime())) {
      return 0;
    }
    const now: Date = new Date();
    const diff: number = DateUtil.epochDay(now.getFullYear(), now.getMonth() + 1, now.getDate())
      - DateUtil.epochDay(target.getFullYear(), target.getMonth() + 1, target.getDate());
    return diff > 0 ? diff : 0;
  }

  /**
   * 把任意写法的日期修成标准串：'2026-1-5' 补零成 '2026-01-05'，
   * '2025-02-30' 这类不存在的一天、以及彻底读不懂的串一律修成今天。
   * 导入外部文件与读历史数据都走这里，保证落进列表的日期一定是规范串，
   * 也让'2026-1-5'这种老数据不至于丢掉购买日期（早前安卓会直接当今天）。
   */
  static sanitize(dateStr: string): string {
    const parts: string[] = dateStr.split('-');
    if (parts.length === 3) {
      const y: number = parseInt(parts[0], 10);
      const m: number = parseInt(parts[1], 10);
      const d: number = parseInt(parts[2], 10);
      if (!isNaN(y) && !isNaN(m) && !isNaN(d) && y >= 1900 && m >= 1 && m <= 12 && d >= 1 && d <= 31) {
        const back: Date = new Date(y, m - 1, d);
        if (back.getFullYear() === y && back.getMonth() === m - 1 && back.getDate() === d) {
          return DateUtil.format(y, m, d);
        }
      }
    }
    return DateUtil.today();
  }

  /**
   * 存储串 yyyy-MM-dd -> 界面上的日期。
   * 简中/繁中/日语原样返回 ISO（这三种语言里它就是最自然的写法，
   * 而且和存储格式一致、不引入任何歧义）；英文写成 Mar 5, 2026。
   * 读不懂的串原样返回——展示层不该猜日期，更不该顺手改成今天。
   */
  static displayDate(dateStr: string): string {
    if (dateStr.length === 0 || !DateUtil.englishMonths()) {
      return dateStr;
    }
    const parts: string[] = dateStr.split('-');
    if (parts.length !== 3) {
      return dateStr;
    }
    const y: number = parseInt(parts[0], 10);
    const m: number = parseInt(parts[1], 10);
    const d: number = parseInt(parts[2], 10);
    if (isNaN(y) || isNaN(m) || isNaN(d) || m < 1 || m > 12 || d < 1 || d > 31) {
      return dateStr;
    }
    return DateUtil.monthEn(m) + ' ' + d + ', ' + y;
  }

  /** 时间戳 -> 勋章获得日期（简中/繁中/日语 2026.03.05；英文 Mar 5, 2026） */
  static formatStamp(at: number): string {
    if (at <= 0) {
      return '';
    }
    const d: Date = new Date(at);
    if (DateUtil.englishMonths()) {
      return DateUtil.monthEn(d.getMonth() + 1) + ' ' + d.getDate() + ', ' + d.getFullYear();
    }
    return d.getFullYear() + '.' + DateUtil.pad(d.getMonth() + 1) + '.' + DateUtil.pad(d.getDate());
  }

  /** 时间戳 -> 便于排序与比对的时间串，如 10-09 14:30 / Oct 9, 14:30（备份列表用） */
  static formatClock(at: number): string {
    if (at <= 0) {
      return '--';
    }
    const d: Date = new Date(at);
    const now: Date = new Date();
    const sameYear: boolean = d.getFullYear() === now.getFullYear();
    const clock: string = DateUtil.pad(d.getHours()) + ':' + DateUtil.pad(d.getMinutes());
    if (DateUtil.englishMonths()) {
      // 英文同年就省掉年份，与原本"只写 MM-dd"的思路一致；跨年才补上
      const mon: string = DateUtil.monthEn(d.getMonth() + 1) + ' ' + d.getDate();
      const dayPart: string = sameYear ? mon : mon + ', ' + d.getFullYear();
      return dayPart + ', ' + clock;
    }
    const dayPart: string = sameYear
      ? DateUtil.pad(d.getMonth() + 1) + '-' + DateUtil.pad(d.getDate())
      : d.getFullYear() + '-' + DateUtil.pad(d.getMonth() + 1) + '-' + DateUtil.pad(d.getDate());
    return dayPart + ' ' + clock;
  }

  /** 把天数说成人话：如 3 年 2 个月 / 3 yr 2 mo（量词与单复数都在 p_* 里） */
  static humanDays(days: number): string {
    if (days < 30) {
      return I18n.qt('p_days', days, days);
    }
    const months: number = Math.floor(days / 30);
    if (days < 365) {
      return I18n.qt('p_months', months, months);
    }
    const years: number = Math.floor(days / 365);
    const restMonths: number = Math.floor((days - years * 365) / 30);
    return restMonths > 0
      ? I18n.qt('p_years_months', years, years, restMonths)
      : I18n.qt('p_years', years, years);
  }

  /** 界面当前是否用英文月名写法（只有 en；其余三种语言都是数字日期） */
  private static englishMonths(): boolean {
    return I18n.current() === Lang.EN;
  }

  /** 1~12 月 -> 英文缩写；越界退化成数字补零，取值前先挡住脏数据 */
  private static monthEn(month: number): string {
    if (month < 1 || month > 12) {
      return DateUtil.pad(month);
    }
    return DateUtil.MONTHS_EN[month - 1];
  }
}
