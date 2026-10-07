/** 金额格式化工具 */
export class Fmt {
  /** 金额：整数不带小数，超过三位加千分位 */
  static money(v: number): string {
    const neg: boolean = v < 0;
    let s: string = Math.abs(v).toFixed(2);
    if (s.endsWith('.00')) {
      s = s.substring(0, s.length - 3);
    }
    const parts: string[] = s.split('.');
    const intPart: string = parts[0];
    let out: string = '';
    for (let i: number = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 === 0) {
        out += ',';
      }
      out += intPart.charAt(i);
    }
    if (parts.length > 1) {
      out = out + '.' + parts[1];
    }
    return (neg ? '-' : '') + out;
  }

  /**
   * 大金额缩写：满 10 万写成「10.0万」，满 1 亿写成「1.2亿」，其余照常写全。
   * 只用于空间紧张的地方（如扇形图圆心），列表和汇总卡仍用完整的 money()。
   */
  static moneyCompact(v: number): string {
    return Fmt.moneyCompactAs(v, v);
  }

  /**
   * 按 ref 的量级决定用不用缩写，但换算的是 v。
   * 滚动动画里金额是从 0 涨上去的，中途会跨过 10 万这条线；
   * 让过程值跟最终值共用同一套单位，数字才不会中途从「99,999」跳成「10.0万」。
   */
  static moneyCompactAs(v: number, ref: number): string {
    const a: number = Math.abs(ref);
    if (a >= 100000000) {
      return Fmt.oneDecimal(v / 100000000) + '亿';
    }
    if (a >= 100000) {
      return Fmt.oneDecimal(v / 10000) + '万';
    }
    return Fmt.money(v);
  }

  /** 保留一位小数（10.0 / 123.5） */
  private static oneDecimal(x: number): string {
    return (Math.round(x * 10) / 10).toFixed(1);
  }

  /** 日均金额：小于 0.01 时给出提示，避免出现 0.00 的误导 */
  static smallMoney(v: number): string {
    if (v > 0 && v < 0.01) {
      return '<0.01';
    }
    return Fmt.money(v);
  }

  /** 百分比，0~1 */
  static percent(v: number): string {
    return (v * 100).toFixed(0) + '%';
  }

  /** 给 #RRGGBB 加上透明度前缀（ArkUI 的 8 位色值是 #AARRGGBB） */
  static tint(hex: string, alpha: string): string {
    if (hex.length === 7 && hex.charAt(0) === '#') {
      return '#' + alpha + hex.substring(1);
    }
    return hex;
  }
}
