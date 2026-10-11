/** 日期工具：统一按本地时区、按"自然日"计算，避免时区和时分秒带来的误差 */
export class DateUtil {
  private static readonly DAY_MS: number = 24 * 60 * 60 * 1000;

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

  /** 时间戳 -> yyyy.MM.dd（勋章获得日期用） */
  static formatStamp(at: number): string {
    if (at <= 0) {
      return '';
    }
    const d: Date = new Date(at);
    return d.getFullYear() + '.' + DateUtil.pad(d.getMonth() + 1) + '.' + DateUtil.pad(d.getDate());
  }

  /** 时间戳 -> 便于排序与比对的时间串，如 10-09 14:30（备份列表用） */
  static formatClock(at: number): string {
    if (at <= 0) {
      return '--';
    }
    const d: Date = new Date(at);
    const now: Date = new Date();
    const dayPart: string = d.getFullYear() === now.getFullYear()
      ? DateUtil.pad(d.getMonth() + 1) + '-' + DateUtil.pad(d.getDate())
      : d.getFullYear() + '-' + DateUtil.pad(d.getMonth() + 1) + '-' + DateUtil.pad(d.getDate());
    return dayPart + ' ' + DateUtil.pad(d.getHours()) + ':' + DateUtil.pad(d.getMinutes());
  }

  /** 把天数说成人话：如 3 年 2 个月 */
  static humanDays(days: number): string {
    if (days < 30) {
      return days + ' 天';
    }
    if (days < 365) {
      return Math.floor(days / 30) + ' 个月';
    }
    const years: number = Math.floor(days / 365);
    const restMonths: number = Math.floor((days - years * 365) / 30);
    return restMonths > 0 ? years + ' 年 ' + restMonths + ' 个月' : years + ' 年';
  }
}
