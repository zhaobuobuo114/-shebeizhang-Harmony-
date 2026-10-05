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
