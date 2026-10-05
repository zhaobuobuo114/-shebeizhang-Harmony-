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
}
