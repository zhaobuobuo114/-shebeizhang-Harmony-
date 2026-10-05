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

  /** 从 dateStr 到今天，相差多少个自然日（今天为 0，未来返回 0） */
  static daysSince(dateStr: string): number {
    const target: number = DateUtil.parse(dateStr).getTime();
    const now: Date = new Date();
    const todayStart: number = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
    const diff: number = Math.floor((todayStart - target) / DateUtil.DAY_MS);
    return diff > 0 ? diff : 0;
  }

  /** 简易合法性校验 */
  static isValid(dateStr: string): boolean {
    if (dateStr.length !== 10) {
      return false;
    }
    const d: Date = DateUtil.parse(dateStr);
    return DateUtil.format(d.getFullYear(), d.getMonth() + 1, d.getDate()) === dateStr;
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
