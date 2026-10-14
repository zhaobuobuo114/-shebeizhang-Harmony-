import { I18n } from './I18n';

/** 一档缩写：除数 + 单位文案键。判档与换算共用一份定义，不会各写一遍。 */
export class CompactTier {
  divisor: number;
  unitKey: string;

  constructor(divisor: number, unitKey: string) {
    this.divisor = divisor;
    this.unitKey = unitKey;
  }
}

/** 金额格式化工具。money/smallMoney/percent/tint 都与 Context 无关、恒为 ASCII。 */
export class Fmt {
  /** 金额：整数不带小数，超过三位加千分位 */
  static money(v: number): string {
    const safe: number = Number.isFinite(v) ? v : 0;
    const neg: boolean = safe < 0;
    let s: string = Math.abs(safe).toFixed(2);
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
    // -0.004 会被 toFixed(2) 收成 "0.00"、裁掉小数后只剩 "0"，再挂负号就是一个平白无故的 "-0"
    return (neg && out !== '0' ? '-' : '') + out;
  }

  /**
   * 带货币符号的完整金额：界面里所有「¥xxx」「NT$xxx」「$xxx」都从这里出。
   * 符号按语言从文案表取（简中/日文 `¥`、繁中 `NT$`、英文 `$`），不写死字面量，
   * 免得代码里散落二十多个硬编码、将来换符号要改一片。
   * **换的只是符号，数值不做任何汇率换算**：同一笔账切成英文会从 ¥1,280 变成 $1,280，
   * 这是定的显示口径，账本里存的仍是用户录入的那个数。
   */
  static moneyLabel(v: number): string {
    return I18n.currency() + Fmt.money(v);
  }

  /**
   * 大金额缩写：满 10 万写成「10.0万」（英文 100.0K），满 1 亿写成「1.2亿」（英文 1.2B），其余照常写全。
   * 只用于空间紧张的地方（如扇形图圆心），列表和汇总卡仍用完整的 money()。
   */
  static moneyCompact(v: number): string {
    return Fmt.moneyCompactAs(v, v);
  }

  /**
   * 按 ref 的量级决定用不用缩写，但换算的是 v。
   * 滚动动画里金额是从 0 涨上去的，中途会跨过 10 万这条线；
   * 让过程值跟最终值共用同一套单位，数字才不会中途从「99,999」跳成「10.0万」。
   *
   * 汉字计数单位（万/亿）只在简中/繁中/日语里用，英文改走 K/M/B。
   * 两条分支的"起缩"门槛都守在 1e5：英文要是从千位就缩写，列表里绝大多数
   * 设备都会写成 1.2K 这种读着别扭的样子，而它们本来根本不该被缩写。
   */
  static moneyCompactAs(v: number, ref: number): string {
    const safe: number = Number.isFinite(v) ? v : 0;
    const a: number = Math.abs(Number.isFinite(ref) ? ref : 0);
    const tier: CompactTier | null = Fmt.tierOf(a, I18n.useWanNumerals());
    if (tier === null) {
      return Fmt.money(safe);
    }
    return Fmt.oneDecimal(safe / tier.divisor) + I18n.t(tier.unitKey);
  }

  /**
   * 该用哪一档，null 表示不缩写、写全数字。
   * 与安卓 `Fmt.tierOf` 逐行同构，边界表在 `_test_fmt_tier.mjs` 里逐条对着，改动要同步过去。
   *
   * 判档要看"缩写之后会不会进位到 1000"：999,950 用 K 档会写成 `1000.0K`，其实该用 M；
   * 999,950,000 用 M 档会写成 `1000.0M`，该用 B；B 是英文最大一档，
   * 999,950,000,000 用 B 会写成 `1000.0B`，无处可升 → 写全。
   * 汉字同理（99,999,999 → 10000.0万 要改用亿），亿档没有上界就保留。
   */
  static tierOf(a: number, wanNumerals: boolean): CompactTier | null {
    if (wanNumerals) {
      const wan: number = Math.round(a / 1000) / 10;
      if (a >= 1e8) {
        return new CompactTier(1e8, 'fmt_yi');
      }
      if (a >= 1e5) {
        return wan < 10000 ? new CompactTier(1e4, 'fmt_wan') : new CompactTier(1e8, 'fmt_yi');
      }
      return null;
    }
    const kb: number = Math.round(a / 100) / 10;
    const mb: number = Math.round(a / 1e5) / 10;
    const bb: number = Math.round(a / 1e8) / 10;
    if (a >= 1e9) {
      return bb < 1000 ? new CompactTier(1e9, 'fmt_b') : null;
    }
    if (a >= 1e6) {
      return mb < 1000 ? new CompactTier(1e6, 'fmt_m') : new CompactTier(1e9, 'fmt_b');
    }
    if (a >= 1e5) {
      return kb < 1000 ? new CompactTier(1e3, 'fmt_k') : new CompactTier(1e6, 'fmt_m');
    }
    return null;
  }

  /**
   * 保留一位小数（10.0 / 123.5）。公开它是为了能和安卓 `Fmt.oneDecimal` 逐值对测。
   *
   * **不要"顺手改成 `x.toFixed(1)`"** —— 那样反而与安卓分歧。
   * 《BUG报告》B8 断言"安卓 `%.1f` 是对精确二进制值做 HALF_UP，所以 12.35 会舍成 12.3"，
   * 那是用 Python `Decimal(float).quantize(HALF_UP)` 模拟出来的，**不是 OpenJDK 的实际行为**。
   * 真机量过（jbr-21，18 个探针）：
   *   12.35 → Java `12.4` / toFixed `12.3` / round10 `12.4`
   *   55.55 → Java `55.6` / toFixed `55.5` / round10 `55.6`
   *   56.05 → Java `56.1` / toFixed `56.0` / round10 `56.1`
   *    5.55 → Java `5.6`  / toFixed `5.5` / round10 `5.6`
   *    0.15 → Java `0.2`  / toFixed `0.1` / round10 `0.2`
   *    0.35 → Java `0.4`  / toFixed `0.3` / round10 `0.4`
   * 即 `Math.round(x * 10) / 10` 与 Java 的 `%.1f` 在非负值上 18/18 逐位一致，
   * `toFixed(1)` 有 6 处偏离。外层再套 `toFixed(1)` 只为补出 "1000.0" 这种尾零。
   *
   * 已知不一致但走不到：负数上两边定义不同（Java `-12.35` → `-12.4`，本实现 → `-12.3`）。
   * 金额经 `DeviceItem.normalize` 后恒 >= 0，`oneDecimal` 只被金额缩写调用，
   * 所以这条路径不可达；真要显示负数，得先把两端的取位规则重新对齐。
   */
  static oneDecimal(x: number): string {
    return (Math.round(x * 10) / 10).toFixed(1);
  }

  /** 日均金额：小于 0.01 时给出提示，避免出现 0.00 的误导 */
  static smallMoney(v: number): string {
    if (v > 0 && v < 0.01) {
      return '<0.01';
    }
    return Fmt.money(v);
  }

  /** 带货币符号的日均金额（与 moneyLabel 同理，符号取自文案表） */
  static smallMoneyLabel(v: number): string {
    return I18n.currency() + Fmt.smallMoney(v);
  }

  /**
   * 价格输入的严格解析：不合法返回 NaN。与安卓 `Fmt.parsePrice` 同一条规则。
   *
   * `parseFloat` 会"读到哪算哪"：`12abc` 拿回 12、`1234,56` 拿回 1234，
   * 用户以为记下了带小数的价格，存进去的却是被截断的整数——比报个错糟得多。
   * 逗号在小数点写成逗号的语言（德/法/意/俄）下是输入法正常产物，这里当小数点收；
   * 点与逗号混用、两个逗号、带字母一律判为无效。存储恒为 ASCII 点。
   */
  static parsePrice(text: string): number {
    const t: string = text.trim();
    const first: number = t.indexOf(',');
    let s: string = t;
    if (first >= 0) {
      if (t.indexOf('.') >= 0 || t.indexOf(',', first + 1) >= 0) {
        return NaN;
      }
      s = t.replace(',', '.');
    }
    return /^\d+(?:\.\d*)?$|^\.\d+$/.test(s) ? Number(s) : NaN;
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
