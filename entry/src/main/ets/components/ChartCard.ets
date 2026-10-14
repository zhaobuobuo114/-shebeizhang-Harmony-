import { ChartData, PieSlice } from '../model/ChartData';
import { AppTheme, LIGHT_THEME } from '../utils/Theme';
import { Fmt } from '../utils/Format';
import { I18n } from '../utils/I18n';

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
  /**
   * 语言版本号：ArkUI 只在表达式里"读到"状态变量时才建立依赖，
   * this.t() 自己不是状态，所以切语言不会让这行字重画。
   * 取词一律走下面的 t() / qt()，它们读一次这个值，把依赖挂上。
   */
  @StorageProp('langVersion') @Watch('onLang') langVersion: number = 0;

  private t(key: string, ...args: (string | number)[]): string {
    const v: number = this.langVersion;
    return v < 0 ? key : I18n.t(key, ...args);
  }

  private qt(key: string, count: number, ...args: (string | number)[]): string {
    const v: number = this.langVersion;
    return v < 0 ? key : I18n.qt(key, count, ...args);
  }


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

  /**
   * 语言切换：圆心的三处文案与图例都是 draw()/buildRows() 现取的，不重绘就留着旧语言。
   *
   * 这里必须自己挂 @Watch：`dataAmount`/`dataCount` 那两个 @Watch('refresh') 只在
   * JSON 字符串真的变了才触发，而**一台设备都没有**时它们恒为 '[]'、简繁之间
   * 类型名又可能完全同名（平板/冰箱/其他三项繁简同字），两种情况都不会触发 refresh，
   * 于是切完语言圆心还写着「总投入」。
   *
   * 不复用 refresh()：那会 start() 重播 820ms 展开动画，而安卓侧切语言是
   * `updateChart(animate=false, force=true)`——只重画、不重播。
   */
  private onLang(): void {
    this.rows = this.buildRows();
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

  /**
   * 圆心的三处文案都在每次 draw 里现取，不留模块级常量：
   * 画布是命令式绘制的，缓存下来的字符串不会跟着语言变。
   */
  private centerMain(): string {
    const total: number = this.totalValue();
    const shown: number = total * this.progress;
    if (this.mode === 'amount') {
      // 单位跟最终值保持一致，动画过程里才不会在「99,999」和「10.0万」之间跳一下
      return I18n.currency() + Fmt.moneyCompactAs(shown, total);
    }
    return Math.round(shown).toString();
  }

  private centerSub(): string {
    if (this.mode === 'amount') {
      return this.t('chart_center_amount');
    }
    // 圆心下方那个词要跟着台数走单复数：英文一台是 "1 device"，两台才是 "2 devices"
    return this.qt('p_center_count', Math.round(this.totalValue()));
  }

  /**
   * 滚动动画结束（progress = 1）时圆心要显示的主数字。
   * 字号按它来定，而不是按逐帧的中间值——否则金额从 0 涨到总额的过程中
   * 字符串越来越长，字号会被一路压小，看着像"数字自己在缩水"。
   */
  private centerSettled(): string {
    const total: number = this.totalValue();
    if (this.mode === 'amount') {
      return I18n.currency() + Fmt.moneyCompact(total);
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

  /**
   * 一个色值往白（delta>0）或往黑（delta<0）挪 delta 的比例。
   * 渐变两档由它从扇区自己的主题色派生，而不是另配一套色板：
   * 41 种设备类型每种只有一个色，深色模式下另配色板会亮成一片不像同个 app。
   */
  private shade(hex: string, delta: number): string {
    let h: string = hex;
    if (h.startsWith('#')) {
      h = h.substring(1);
    }
    if (h.length === 3) {
      h = h.charAt(0) + h.charAt(0) + h.charAt(1) + h.charAt(1) + h.charAt(2) + h.charAt(2);
    }
    if (h.length < 6) {
      return hex;
    }
    const to: number = delta > 0 ? 255 : 0;
    const k: number = Math.abs(delta);
    const out: string[] = [];
    for (let i: number = 0; i < 3; i++) {
      const raw: number = parseInt(h.substring(i * 2, i * 2 + 2), 16);
      const v: number = isNaN(raw) ? 0 : raw;
      let mixed: number = Math.round(v + (to - v) * k);
      if (mixed < 0) {
        mixed = 0;
      }
      if (mixed > 255) {
        mixed = 255;
      }
      const s: string = mixed.toString(16);
      out.push(s.length < 2 ? '0' + s : s);
    }
    return '#' + out[0] + out[1] + out[2];
  }

  /**
   * 圆角扇环：外弧 → 右下圆角 → 侧边 → 内下圆角 → 内弧 → 左下圆角 → 侧边 → 左上圆角。
   *
   * 圆角半径被三件事卡着：环宽的一半、这一片在内圈上的弧长的一半、在外圈上的弧长的一半。
   * 占比千分之几的窄片会被后两项压到 0，这时**退回直角**——
   * 宁可那一片是个小楔子，也不能让两个圆角互相穿过、把扇面扭成蝴蝶结。
   */
  private slicePath(ctx: CanvasRenderingContext2D, cx: number, cy: number, rIn: number,
    rOut: number, a0: number, a1: number, cr: number): void {
    const w: number = rOut - rIn;
    const span: number = a1 - a0;
    let r: number = cr;
    if (r > w / 2) {
      r = w / 2;
    }
    if (r > span * rIn / 2) {
      r = span * rIn / 2;
    }
    if (r > span * rOut / 2) {
      r = span * rOut / 2;
    }
    if (r < 0.6) {
      ctx.beginPath();
      ctx.arc(cx, cy, rOut, a0, a1, false);
      ctx.arc(cx, cy, rIn, a1, a0, true);
      ctx.closePath();
      return;
    }
    const aoOut: number = r / rOut;
    const aoIn: number = r / rIn;
    ctx.beginPath();
    ctx.moveTo(cx + rOut * Math.cos(a0 + aoOut), cy + rOut * Math.sin(a0 + aoOut));
    ctx.arc(cx, cy, rOut, a0 + aoOut, a1 - aoOut, false);
    // 弧走到头，用"尖角当控制点"的二次曲线拐进侧边；侧边是径向直线
    ctx.quadraticCurveTo(cx + rOut * Math.cos(a1), cy + rOut * Math.sin(a1),
      cx + (rOut - r) * Math.cos(a1), cy + (rOut - r) * Math.sin(a1));
    ctx.lineTo(cx + (rIn + r) * Math.cos(a1), cy + (rIn + r) * Math.sin(a1));
    ctx.quadraticCurveTo(cx + rIn * Math.cos(a1), cy + rIn * Math.sin(a1),
      cx + rIn * Math.cos(a1 - aoIn), cy + rIn * Math.sin(a1 - aoIn));
    ctx.arc(cx, cy, rIn, a1 - aoIn, a0 + aoIn, true);
    ctx.quadraticCurveTo(cx + rIn * Math.cos(a0), cy + rIn * Math.sin(a0),
      cx + (rIn + r) * Math.cos(a0), cy + (rIn + r) * Math.sin(a0));
    ctx.lineTo(cx + (rOut - r) * Math.cos(a0), cy + (rOut - r) * Math.sin(a0));
    ctx.quadraticCurveTo(cx + rOut * Math.cos(a0), cy + rOut * Math.sin(a0),
      cx + rOut * Math.cos(a0 + aoOut), cy + rOut * Math.sin(a0 + aoOut));
    ctx.closePath();
  }

  /** 整圈扇环路径（投影与轨道用）：不切缝、不圆角；dy 是整体下移的像素数 */
  private ringPath(ctx: CanvasRenderingContext2D, cx: number, cy: number, rIn: number,
    rOut: number, dy: number): void {
    ctx.beginPath();
    ctx.arc(cx, cy + dy, rOut, 0, Math.PI * 2, false);
    ctx.arc(cx, cy + dy, rIn, Math.PI * 2, 0, true);
    ctx.closePath();
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

    /* ============ 材质：先落投影与轨道，再把扇片贴上去 ============ */
    // 投影画成"整体下移 2vp 的一份低透明度环形"，不用 shadowBlur：
    // 安卓那边硬件加速画布上 setShadowLayer 对填充路径的支持要看 API 级别，
    // 两端要长得一模一样，就只用两边行为完全一致的原语。
    ctx.fillStyle = th.dark ? 'rgba(0,0,0,0.34)' : 'rgba(0,0,0,0.10)';
    this.ringPath(ctx, cx, cy, rIn, rOut, 2);
    ctx.fill();
    ctx.fillStyle = th.trackBg;
    this.ringPath(ctx, cx, cy, rIn, rOut, 0);
    ctx.fill();

    if (total > 0) {
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
        // 让缝之后可能比起点还窄：原先直接 continue，于是占比不到 ~0.5% 的类型在图上
        // 一个像素都没有，而图例里照样列着它、还标着 1%（百分比是最大余数法保底的）。
        // 安卓端有 1.2° 的 minSweep 保底，这里同值同法：至少画出 1.2°，
        // 但用 Math.min(raw1, …) 封在这一片自身的角度内，不会压到下一片。
        const minSweep: number = 1.2 * Math.PI / 180;
        const b1: number = whole ? Math.min(raw1, Math.max(s1 - gap, b0 + minSweep)) : raw1;
        if (b1 - b0 <= 0.0001) {
          continue;
        }
        // 扇环：圆角四角 + 内外两条弧，窄片自动退回直角（见 slicePath）；
        // 填充用从内圈到外圈的径向渐变，内暗外亮，41 种颜色各自派生、不另配色板
        const base: string = this.slices[i].c;
        const grad: CanvasGradient = ctx.createRadialGradient(cx, cy, rIn, cx, cy, rOut);
        grad.addColorStop(0, this.shade(base, -0.10));
        grad.addColorStop(1, this.shade(base, 0.16));
        this.slicePath(ctx, cx, cy, rIn, rOut, b0, b1, 4);
        ctx.fillStyle = grad;
        ctx.fill();
      }
    }

    /* ============ 内圈高光：1.2vp 的一圈浅色描边，把"洞口"边缘立起来 ============ */
    ctx.beginPath();
    ctx.lineWidth = 1.2;
    ctx.strokeStyle = th.dark ? 'rgba(255,255,255,0.10)' : 'rgba(0,0,0,0.05)';
    ctx.arc(cx, cy, rIn - 1.4, 0, Math.PI * 2, false);
    ctx.stroke();

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
      const value: string = this.mode === 'amount'
        ? (I18n.currency() + Fmt.money(v))
        : this.qt('p_sticky_count', v, v.toFixed(0));
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

  /**
   * 表头拆成两行。
   *
   * 原来一行里塞了标题、副标题、两个模式胶囊和收起按钮：中文刚好放得下，
   * 但英文量出来 "Where it went" + "By device type" + "By amount" + "By count" + "Collapse"
   * 约 393vp、日语约 332vp，而卡片正文只有 296vp 宽（360vp 屏减去页面与卡片内边距），
   * 光靠副标题收缩根本填不平——最右边的胶囊会被直接切掉。
   * 现在第一行只剩 标题 + 副标题（弹性、省略号）+ 收起，四种语言都放得下；
   * 两个模式胶囊单独一行右对齐，点击区域也更大。
   */
  build() {
    Column() {
      Row() {
        Text(this.t('chart_title'))
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme.text)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.t('chart_sub'))
          .fontSize(11)
          .fontColor(this.theme.sub)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ left: 8 })
          // 本行唯一的弹性元素：标题与"收起"都定长，挤不动的一律省略号
          .layoutWeight(1)
        Text(this.open ? this.t('chart_collapse') : this.t('chart_expand'))
          .fontSize(11)
          .fontColor(this.theme.sub)
          .maxLines(1)
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

      Row() {
        Text(this.t('chart_by_amount'))
          .fontSize(11)
          .fontColor(this.mode === 'amount' ? this.theme.onPrimary : this.theme.chipText)
          .backgroundColor(this.mode === 'amount' ? this.theme.primary : this.theme.chipBg)
          .borderRadius(11)
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .maxLines(1)
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
        Text(this.t('chart_by_count'))
          .fontSize(11)
          .fontColor(this.mode === 'count' ? this.theme.onPrimary : this.theme.chipText)
          .backgroundColor(this.mode === 'count' ? this.theme.primary : this.theme.chipBg)
          .borderRadius(11)
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .maxLines(1)
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
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
      .margin({ top: 8 })

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
              Text(this.t('chart_empty_legend'))
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
              }, (row: LegendRow) => this.langVersion + '|' + row.key)
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
