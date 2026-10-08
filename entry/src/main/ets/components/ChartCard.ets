import { ChartData, PieSlice } from '../model/ChartData';
import { AppTheme, LIGHT_THEME } from '../utils/Theme';
import { Fmt } from '../utils/Format';

interface LegendRow {
  name: string;
  value: string;
  percent: string;
  color: string;
  key: string;
}

/**
 * 扇形（环形）统计图卡片：按设备类型看支出构成。
 * 用 Canvas 手绘，配合定时器逐帧推进，做出"扇形展开"的动画。
 */
@Component
export struct ChartCard {
  @Prop @Watch('refresh') dataAmount: string = '[]';
  @Prop @Watch('refresh') dataCount: string = '[]';
  @Prop @Watch('onTheme') theme: AppTheme = LIGHT_THEME;

  @State mode: string = 'amount';
  // 展开动画的推进量。刻意不做成 @State：它每帧都在变，
  // 一旦挂上状态，820ms 里会触发五十多次组件重建，动画会一顿一顿的。
  // 圆心数字也是画布画出来的，直接 draw() 重绘就够。
  private progress: number = 0;
  @State rows: LegendRow[] = [];
  @State open: boolean = true;
  // 按压动效：记录当前被按下的控件标识
  @State pressed: string = '';

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private slices: PieSlice[] = [];
  private timer: number = -1;
  private ready: boolean = false;
  private chartSize: number = 152;
  /** 屏幕密度：画布坐标是 vp，但 ctx.font 的字号按 px 解释，换算时要用它 */
  private density: number = 0;

  aboutToDisappear(): void {
    if (this.timer !== -1) {
      clearTimeout(this.timer);
      this.timer = -1;
    }
  }

  private parse(json: string): PieSlice[] {
    if (json.length === 0) {
      return [];
    }
    try {
      return JSON.parse(json) as PieSlice[];
    } catch (e) {
      return [];
    }
  }

  /** 数据变化：重新取数并播放动画 */
  refresh(): void {
    this.slices = this.parse(this.mode === 'amount' ? this.dataAmount : this.dataCount);
    this.rows = this.buildRows();
    this.start();
  }

  /** 主题切换：画布是命令式绘制，必须手动重绘 */
  private onTheme(): void {
    this.draw();
  }

  private setMode(m: string): void {
    if (this.mode === m) {
      return;
    }
    this.mode = m;
    this.refresh();
  }

  private totalValue(): number {
    return ChartData.total(this.slices);
  }

  /* --------------------------- 按压动效 --------------------------- */

  private onPress(e: TouchEvent, key: string): void {
    if (e.type === TouchType.Down) {
      this.pressed = key;
    } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
      this.pressed = '';
    }
  }

  private sc(key: string): number {
    return this.pressed === key ? 0.9 : 1;
  }

  /* --------------------------- 绘制 --------------------------- */

  private centerMain(): string {
    const total: number = this.totalValue();
    const shown: number = total * this.progress;
    if (this.mode === 'amount') {
      // 单位跟最终值保持一致，动画过程里才不会在「99,999」和「10.0万」之间跳一下
      return '¥' + Fmt.moneyCompactAs(shown, total);
    }
    return Math.round(shown).toString();
  }

  private centerSub(): string {
    return this.mode === 'amount' ? '总投入' : '台设备';
  }

  /**
   * 滚动动画结束（progress = 1）时圆心要显示的主数字。
   * 字号按它来定，而不是按逐帧的中间值——否则金额从 0 涨到总额的过程中
   * 字符串越来越长，字号会被一路压小，看着像"数字自己在缩水"。
   */
  private centerSettled(): string {
    const total: number = this.totalValue();
    if (this.mode === 'amount') {
      return '¥' + Fmt.moneyCompact(total);
    }
    return Math.round(total).toString();
  }

  /* --------------------------- 字号与密度 --------------------------- */

  /** 1vp 等于多少 px。取不到就退化成 1，保证绘制不崩。 */
  private densityValue(): number {
    if (this.density <= 0) {
      let d: number = 0;
      try {
        d = vp2px(1);
      } catch (e) {
        d = 0;
      }
      this.density = d > 0 ? d : 1;
    }
    return this.density;
  }

  /** 按 vp 字号设置画布字体：ctx.font 的字号是 px，必须乘密度，否则高密度屏上只剩 1/3 大 */
  private setFont(ctx: CanvasRenderingContext2D, vpSize: number): void {
    ctx.font = Math.round(vpSize * this.densityValue()) + 'px sans-serif';
  }

  private draw(): void {
    if (!this.ready || !this.open) {
      return;
    }
    try {
      this.drawInner();
    } catch (e) {
      // 画布被回收时忽略，展开后会重新绘制
    }
  }

  private drawInner(): void {
    const th: AppTheme = this.theme;
    const ctx: CanvasRenderingContext2D = this.ctx;
    const s: number = this.chartSize;
    const cx: number = s / 2;
    const cy: number = s / 2;
    const rOut: number = s / 2 - 5;
    // 内圈占比 0.64（原 0.60）：环略薄一点，把宽度让给圆心的金额
    const rIn: number = rOut * 0.64;
    ctx.clearRect(0, 0, s, s);

    const total: number = this.totalValue();
    const A0: number = -Math.PI / 2;

    if (total <= 0) {
      ctx.beginPath();
      ctx.lineWidth = rOut - rIn;
      ctx.strokeStyle = th.trackBg;
      ctx.arc(cx, cy, (rOut + rIn) / 2, 0, Math.PI * 2);
      ctx.stroke();
    } else {
      const end: number = A0 + Math.PI * 2 * this.progress;
      // 相邻两段之间留 3vp 的缝。早先这里是给每段描一圈 3px 的卡片色边框，
      // 但 stroke 是以路径为中心向两侧各铺一半的，会把两边的扇面各吃掉一点，
      // 小份额那一段看起来就比图例的百分比窄。改成按角度让位之后，
      // 每一段的起止角度都是准的，和安卓版的算法也完全对上了。
      const ring: number = (rOut + rIn) / 2;
      const gap: number = 3 / ring;
      const full: number = Math.PI * 2;
      let cur: number = A0;
      for (let i: number = 0; i < this.slices.length; i++) {
        const s0: number = cur;
        // 最后一段直接收在整圈上，避免逐段累加的浮点误差在 12 点方向留一道细缝
        const s1: number = i === this.slices.length - 1 ? A0 + full : cur + full * (this.slices[i].v / total);
        cur = s1;
        const b0: number = s0 > A0 ? s0 : A0;
        const raw1: number = s1 < end ? s1 : end;
        if (raw1 - b0 <= 0.0001) {
          continue;
        }
        // 整段都已显示时才让出缝隙，否则动画推进中的那一段会一跳一跳地变窄
        const whole: boolean = raw1 >= s1 - 0.0001;
        const b1: number = whole ? s1 - gap : raw1;
        if (b1 - b0 <= 0.0001) {
          continue;
        }
        // 扇环：外弧 -> 内弧反向 -> 闭合
        ctx.beginPath();
        ctx.arc(cx, cy, rOut, b0, b1, false);
        ctx.arc(cx, cy, rIn, b1, b0, true);
        ctx.closePath();
        ctx.fillStyle = this.slices[i].c;
        ctx.fill();
      }
    }

    // 圆心文字：可用宽度取"文字所在高度处的内圆弦长"，
    // 而不是直接用内圆直径——上下两行是错开画的，弦长才是真实可用宽度。
    const main: string = this.centerMain();
    const sub: string = this.centerSub();
    const dyMain: number = -8;
    const dySub: number = 15;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';

    // 主数字：基准 24（比原来的 21 大一档），下限 12；字号按最终金额算，滚动时不再抖动
    let mainSize: number = this.fitSize(ctx, this.centerSettled(), 24, 12, this.chordWidth(dyMain, rIn));
    const mainCap: number = s * 0.18;
    if (mainSize > mainCap) {
      mainSize = mainCap;
    }
    mainSize = Math.floor(mainSize);
    this.setFont(ctx, mainSize);
    ctx.fillStyle = th.text;
    // 加粗用两次轻微错位绘制实现，兼容性最好
    ctx.fillText(main, cx - 0.5, cy + dyMain);
    ctx.fillText(main, cx + 0.5, cy + dyMain);

    let subSize: number = this.fitSize(ctx, sub, 12, 9, this.chordWidth(dySub, rIn));
    const subCap: number = s * 0.10;
    if (subSize > subCap) {
      subSize = subCap;
    }
    subSize = Math.floor(subSize);
    this.setFont(ctx, subSize);
    ctx.fillStyle = th.sub;
    ctx.fillText(sub, cx, cy + dySub);
  }

  /** 圆心处"离圆心 dy"这条水平线上，内圆还剩多宽可写（留 3 的呼吸空间，免得贴住内壁） */
  private chordWidth(dy: number, rIn: number): number {
    const r: number = rIn - 3;
    if (r <= 0) {
      return 0;
    }
    const inner: number = r * r - dy * dy;
    if (inner <= 0) {
      return 0;
    }
    return 2 * Math.sqrt(inner);
  }

  /** 按可用宽度等比缩字号；缩到 min 还放不下就继续缩——宁可字小，也不能压到圆环 */
  private fitSize(ctx: CanvasRenderingContext2D, text: string, base: number, min: number, maxW: number): number {
    if (maxW <= 0) {
      return min;
    }
    this.setFont(ctx, base);
    // measureText 回的是 px，除回密度才是和 maxW（vp）同一把尺子
    const w: number = ctx.measureText(text).width / this.densityValue();
    if (w <= maxW || w <= 0) {
      return base;
    }
    const fit: number = base * maxW / w;
    return fit > min ? fit : min;
  }

  private start(): void {
    if (this.timer !== -1) {
      clearTimeout(this.timer);
      this.timer = -1;
    }
    const dur: number = 820;
    const t0: number = Date.now();
    this.progress = 0;
    this.draw();
    const step = (): void => {
      const k: number = Math.min(1, (Date.now() - t0) / dur);
      this.progress = 1 - Math.pow(1 - k, 3);
      this.draw();
      if (k < 1) {
        this.timer = setTimeout(step, 16);
      } else {
        this.progress = 1;
        this.draw();
        this.timer = -1;
      }
    };
    this.timer = setTimeout(step, 16);
  }

  private buildRows(): LegendRow[] {
    const total: number = this.totalValue();
    // 百分比统一由「最大余数法」分配，整列加起来精确等于 100%
    const pct: number[] = ChartData.percents(this.slices);
    const rows: LegendRow[] = [];
    for (let i: number = 0; i < this.slices.length; i++) {
      const v: number = this.slices[i].v;
      const value: string = this.mode === 'amount' ? ('¥' + Fmt.money(v)) : (v.toFixed(0) + ' 台');
      rows.push({
        name: this.slices[i].n,
        value: value,
        percent: total > 0 ? (pct[i].toString() + '%') : '0%',
        color: this.slices[i].c,
        key: this.slices[i].n + '|' + v + '|' + this.mode
      });
    }
    return rows;
  }

  /* --------------------------- 界面 --------------------------- */

  build() {
    Column() {
      Row() {
        Text('支出构成')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme.text)
        Text('按设备类型')
          .fontSize(11)
          .fontColor(this.theme.sub)
          .margin({ left: 8 })
          .layoutWeight(1)

        Text('按金额')
          .fontSize(11)
          .fontColor(this.mode === 'amount' ? this.theme.onPrimary : this.theme.chipText)
          .backgroundColor(this.mode === 'amount' ? this.theme.primary : this.theme.chipBg)
          .borderRadius(11)
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          // 关闭系统焦点框，改用自定义按压缩放
          .focusable(false)
          .scale({ x: this.sc('amount'), y: this.sc('amount') })
          .animation({ duration: 140, curve: Curve.EaseOut })
          .onTouch((e: TouchEvent) => {
            this.onPress(e, 'amount');
          })
          .onClick(() => {
            this.setMode('amount');
          })
        Text('按台数')
          .fontSize(11)
          .fontColor(this.mode === 'count' ? this.theme.onPrimary : this.theme.chipText)
          .backgroundColor(this.mode === 'count' ? this.theme.primary : this.theme.chipBg)
          .borderRadius(11)
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .margin({ left: 6 })
          .focusable(false)
          .scale({ x: this.sc('count'), y: this.sc('count') })
          .animation({ duration: 140, curve: Curve.EaseOut })
          .onTouch((e: TouchEvent) => {
            this.onPress(e, 'count');
          })
          .onClick(() => {
            this.setMode('count');
          })
        Text(this.open ? '收起' : '展开')
          .fontSize(11)
          .fontColor(this.theme.sub)
          .margin({ left: 10 })
          .focusable(false)
          .scale({ x: this.sc('toggle'), y: this.sc('toggle') })
          .animation({ duration: 140, curve: Curve.EaseOut })
          .onTouch((e: TouchEvent) => {
            this.onPress(e, 'toggle');
          })
          .onClick(() => {
            animateTo({ duration: 260, curve: Curve.EaseOut }, () => {
              this.open = !this.open;
            });
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (this.open) {
        Row() {
          Canvas(this.ctx)
            .width(this.chartSize)
            .height(this.chartSize)
            .onReady(() => {
              this.ready = true;
              this.refresh();
            })

          Column() {
            if (this.rows.length === 0) {
              Text('还没有数据')
                .fontSize(12)
                .fontColor(this.theme.sub)
            } else {
              ForEach(this.rows, (row: LegendRow) => {
                Row() {
                  Column()
                    .width(9)
                    .height(9)
                    .borderRadius(5)
                    .backgroundColor(row.color)
                  Text(row.name)
                    .fontSize(12)
                    .fontColor(this.theme.text2)
                    .margin({ left: 7 })
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .layoutWeight(1)
                  Text(row.value)
                    .fontSize(12)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.theme.text)
                  Text(row.percent)
                    .fontSize(11)
                    .fontColor(this.theme.sub)
                    .width(38)
                    .textAlign(TextAlign.End)
                }
                .width('100%')
                .height(22)
                .alignItems(VerticalAlign.Center)
              }, (row: LegendRow) => row.key)
            }
          }
          .layoutWeight(1)
          .margin({ left: 10 })
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .margin({ top: 10 })
        .alignItems(VerticalAlign.Center)
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor(this.theme.card)
    .borderRadius(18)
    .shadow({ radius: 12, color: this.theme.dark ? '#40000000' : '#12000000', offsetX: 0, offsetY: 3 })
  }
}
