import { DeviceItem } from './DeviceItem';
import { findKind } from './DeviceKind';

/** 扇形图的一段 */
export interface PieSlice {
  n: string;   // 名称
  v: number;   // 数值
  c: string;   // 颜色
}

/** 最多显示多少段，其余合并为"其他" */
const MAX_SLICE: number = 6;

export class ChartData {
  /**
   * 按设备类型聚合。
   * @param byAmount true=按金额，false=按台数
   */
  static slices(list: DeviceItem[], byAmount: boolean): PieSlice[] {
    const keys: string[] = [];
    const vals: number[] = [];
    for (let i: number = 0; i < list.length; i++) {
      const k: string = list[i].category;
      const v: number = byAmount ? list[i].price : 1;
      let idx: number = -1;
      for (let j: number = 0; j < keys.length; j++) {
        if (keys[j] === k) {
          idx = j;
          break;
        }
      }
      if (idx < 0) {
        keys.push(k);
        vals.push(v);
      } else {
        vals[idx] = vals[idx] + v;
      }
    }

    const out: PieSlice[] = [];
    for (let i: number = 0; i < keys.length; i++) {
      const kd = findKind(keys[i]);
      out.push({ n: kd.label, v: vals[i], c: kd.color });
    }
    out.sort((a: PieSlice, b: PieSlice): number => b.v - a.v);

    if (out.length > MAX_SLICE) {
      let rest: number = 0;
      for (let i: number = MAX_SLICE - 1; i < out.length; i++) {
        rest += out[i].v;
      }
      out.splice(MAX_SLICE - 1, out.length - MAX_SLICE + 1);
      out.push({ n: '其他', v: rest, c: '#9CA3AF' });
    }
    return out;
  }

  /** 序列化成 JSON 字符串（便于作为组件参数传递，避免数组引用带来的刷新问题） */
  static json(list: DeviceItem[], byAmount: boolean): string {
    return JSON.stringify(ChartData.slices(list, byAmount));
  }

  static total(slices: PieSlice[]): number {
    let sum: number = 0;
    for (let i: number = 0; i < slices.length; i++) {
      sum += slices[i].v;
    }
    return sum;
  }

  /**
   * 各段占整圆的百分比（整数），保证加在一起精确等于 100。
   *
   * 逐段各自四舍五入是不行的：三段各 33.3% 会算出 33/33/33 = 99%，
   * 图例那一列看着就少了 1%。这里用「最大余数法」：先给每段取其下整，
   * 再把剩下的名额按小数部分从大到小依次补 1，和始终是 100。
   *
   * 另外保底：凡是数值不为 0 的段至少给 1%，避免出现「占了钱却写着 0%」。
   */
  static percents(slices: PieSlice[]): number[] {
    const n: number = slices.length;
    const out: number[] = [];
    let total: number = 0;
    for (let i: number = 0; i < n; i++) {
      total += slices[i].v;
      out.push(0);
    }
    if (n === 0 || total <= 0) {
      return out;
    }

    const raw: number[] = [];
    const order: number[] = [];
    let sum: number = 0;
    for (let i: number = 0; i < n; i++) {
      const exact: number = slices[i].v / total * 100;
      raw.push(exact);
      // 数值不为 0 就至少留 1%，否则这一段在图例里会是"占着份额却显示 0%"
      let whole: number = Math.floor(exact);
      if (whole === 0 && slices[i].v > 0) {
        whole = 1;
      }
      out[i] = whole;
      sum += whole;
      order.push(i);
    }

    let diff: number = 100 - sum;
    if (diff > 0) {
      // 名额富余：小数部分越大的越该进位
      order.sort((a: number, b: number): number => {
        return (raw[b] - Math.floor(raw[b])) - (raw[a] - Math.floor(raw[a]));
      });
      let k: number = 0;
      while (diff > 0) {
        out[order[k % n]] = out[order[k % n]] + 1;
        diff--;
        k++;
      }
    } else if (diff < 0) {
      // 保底提 1% 把总数顶过 100 了：从数值最大的段里往回扣
      order.sort((a: number, b: number): number => slices[b].v - slices[a].v);
      let k: number = 0;
      let guard: number = 0;
      while (diff < 0 && guard < n * 100) {
        const i: number = order[k % n];
        if (out[i] > 1) {
          out[i] = out[i] - 1;
          diff++;
        }
        k++;
        guard++;
      }
    }
    return out;
  }
}
