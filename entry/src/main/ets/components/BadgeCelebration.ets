import { AppTheme, LIGHT_THEME } from '../utils/Theme';

/** 弹屏里的一页数据 */
export interface CelebrationItem {
  id: string;
  name: string;
  dateText: string;
  icon: Resource;
}

/** 一颗粒子：角度、外扩距离(vp)、点半径(vp)、时序偏移 */
class Spark {
  rad: number;
  reach: number;
  size: number;
  drift: number;

  constructor(rad: number, reach: number, size: number, drift: number) {
    this.rad = rad;
    this.reach = reach;
    this.size = size;
    this.drift = drift;
  }
}

/**
 * 与安卓版 SparkleView 里的 SPARKS 逐行相同。
 * 粒子形状若各端自己随机，同一朵烟花在两端会长得不一样，"完全同步"就落不到实处。
 */
const SPARKS: Spark[] = [
  new Spark(0.110000, 62, 3.4, 0.00),
  new Spark(0.688799, 48, 4.4, 0.12),
  new Spark(0.927598, 78, 2.6, 0.05),
  new Spark(1.516397, 55, 3.8, 0.17),
  new Spark(1.865196, 84, 3.0, 0.09),
  new Spark(2.463995, 44, 4.6, 0.02),
  new Spark(2.822794, 70, 3.2, 0.14),
  new Spark(3.151593, 58, 2.4, 0.07),
  new Spark(3.780392, 46, 4.0, 0.19),
  new Spark(4.129191, 80, 3.6, 0.04),
  new Spark(4.737990, 52, 2.8, 0.11),
  new Spark(4.986788, 74, 4.2, 0.16),
  new Spark(5.535587, 60, 3.1, 0.06),
  new Spark(5.854386, 66, 3.9, 0.13)
];

/** 起爆半径：必须落在勋章圆盘之外，否则整段飞行都被不透明的圆盘挡在身后 */
const START_RADIUS: number = 60;
const ENTRANCE_MS: number = 620;
const LAND_MS: number = 460;
const SETTLE_MS: number = 160;
const FADE_MS: number = 240;
const HIDE_HINT_MS: number = 1200;
const BURST_MS: number = 560;
const RISE_VP: number = 120;
const GRAVITY_VP: number = 14;

/**
 * 勋章达成弹屏：全屏遮罩 + 居中勋章特写，背后一朵短小烟花，多枚可以左右划着看。
 *
 * 与安卓版逐条对齐：升起 120vp + 转半圈 + 落位把 1.12 收到 1.0（620ms）、
 * 落位那一刻起爆、14 颗粒子 560ms、不自动收起、点空白关闭、1.2s 后淡出提示小字。
 * 差别只有两处，都是平台使然：翻页用 Swiper 而非 ViewPager2；
 * 不申请 VIBRATE 权限，因此没有主动震动（可点控件保留系统默认按压反馈）。
 */
@Component
export struct BadgeCelebration {
  @Prop theme: AppTheme = LIGHT_THEME;
  /** 每次都是新构建的覆盖层，所以构造时传入即可，不需要响应式 */
  items: CelebrationItem[] = [];
  onClose: () => void = () => {
  };

  @State scrimOn: boolean = false;
  @State riseY: number = RISE_VP;
  @State spin: number = -180;
  @State pop: number = 1.12;
  @State fadeIn: number = 0;
  @State hintOn: boolean = false;
  @State page: number = 0;

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private progress: number = 0;
  private frameId: number = -1;
  private landId: number = -1;
  private burstId: number = -1;
  private hintId: number = -1;
  private closed: boolean = false;

  aboutToAppear(): void {
    const ui = this.getUIContext();
    ui.animateTo({ duration: FADE_MS, curve: Curve.EaseOut }, () => {
      this.scrimOn = true;
    });
    // 升起 + 转半圈 + 淡入，一条动画管到底
    ui.animateTo({ duration: ENTRANCE_MS, curve: Curve.EaseOut }, () => {
      this.riseY = 0;
      this.spin = 0;
      this.fadeIn = 1;
    });
    // 落位那一下轻弹：最后 160ms 把 1.12 收到 1.0，同时起爆烟花
    this.landId = setTimeout(() => {
      this.landId = -1;
      ui.animateTo({ duration: SETTLE_MS, curve: Curve.EaseInOut }, () => {
        this.pop = 1;
      });
      this.burst();
    }, LAND_MS);
    this.hintId = setTimeout(() => {
      this.hintId = -1;
      ui.animateTo({ duration: FADE_MS, curve: Curve.EaseOut }, () => {
        this.hintOn = true;
      });
    }, HIDE_HINT_MS);
  }

  aboutToDisappear(): void {
    this.stopFrame();
    if (this.landId !== -1) {
      clearTimeout(this.landId);
      this.landId = -1;
    }
    if (this.burstId !== -1) {
      clearTimeout(this.burstId);
      this.burstId = -1;
    }
    if (this.hintId !== -1) {
      clearTimeout(this.hintId);
      this.hintId = -1;
    }
  }

  private stopFrame(): void {
    if (this.frameId !== -1) {
      clearTimeout(this.frameId);
      this.frameId = -1;
    }
  }

  /** 一次性播放的那朵烟花：放完就停，不常驻重绘 */
  private burst(): void {
    this.progress = 0;
    const started: number = Date.now();
    const colors: string[] = [this.theme.primary, this.theme.primary2, this.theme.accent, this.theme.gold];
    const step = (): void => {
      const t: number = (Date.now() - started) / BURST_MS;
      this.progress = t < 1 ? t : 1;
      this.draw(colors);
      if (this.progress < 1) {
        this.frameId = setTimeout(step, 16);
      } else {
        this.frameId = -1;
        this.ctx.clearRect(0, 0, this.ctx.width, this.ctx.height);
      }
    };
    step();
  }

  private draw(colors: string[]): void {
    const ctx = this.ctx;
    const w: number = ctx.width;
    const h: number = ctx.height;
    if (w <= 0 || h <= 0) {
      return;
    }
    ctx.clearRect(0, 0, w, h);
    const cx: number = w / 2;
    const cy: number = h / 2;
    for (let i: number = 0; i < SPARKS.length; i++) {
      const s: Spark = SPARKS[i];
      let life: number = (this.progress - s.drift) / (1 - s.drift);
      if (life <= 0) {
        continue;
      }
      if (life > 1) {
        life = 1;
      }
      const eased: number = 1 - (1 - life) * (1 - life);      // 先快后慢，像被空气拖住
      const r: number = START_RADIUS + s.reach * eased;
      const x: number = cx + Math.cos(s.rad) * r;
      const y: number = cy + Math.sin(s.rad) * r * 0.92 + GRAVITY_VP * life * life;
      ctx.globalAlpha = (230 / 255) * (1 - life * life);      // 前半程保持亮度，后半程才淡出
      ctx.fillStyle = colors[i % colors.length];
      ctx.beginPath();
      ctx.arc(x, y, s.size * (1 - life * 0.4), 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.globalAlpha = 1;
  }

  private close(): void {
    if (this.closed) {
      return;
    }
    this.closed = true;
    this.stopFrame();
    this.onClose();
  }

  private pageLabel(): string {
    return this.items.length > 1 ? (this.page + 1) + ' / ' + this.items.length : '';
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // 遮罩：点任意处关闭。刻意不用 theme.scrim —— 深色下那层 60% 黑压不住深色页面，
      // 勋章会跟底下的列表糊在一起，弹屏要的是"世界先暗下去"
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.theme.dark ? '#E6000000' : '#B3000000')
        .opacity(this.scrimOn ? 1 : 0)
        .onClick(() => {
          this.close();
        })

      // 烟花画在勋章背后；命中设为 Transparent，不挡住遮罩的点击
      Canvas(this.ctx)
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.Transparent)

      Column() {
        Swiper() {
          ForEach(this.items, (item: CelebrationItem) => {
            Column() {
              Image(item.icon)
                .width(132)
                .height(132)
                .translate({ y: this.riseY })
                .rotate({ angle: this.spin })
                .scale({ x: this.pop, y: this.pop })
                .opacity(this.fadeIn)
              Text(item.name)
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.theme.text)
                .margin({ top: 16 })
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(item.dateText + ' 达成')
                .fontSize(12)
                .fontColor(this.theme.primary)
                .margin({ top: 6 })
            }
            .width('100%')
            .height('100%')
            .justifyContent(FlexAlign.Center)
          }, (item: CelebrationItem) => item.id)
        }
        .width('100%')
        .height(252)
        .indicator(false)
        .loop(false)
        .disableSwipe(this.items.length <= 1)
        .onChange((index: number) => {
          this.page = index;
        })

        // 多枚时右下角「2 / 3」，只有一枚时整块空着
        Text(this.pageLabel())
          .fontSize(11)
          .fontColor(this.theme.sub)
          .width('100%')
          .textAlign(TextAlign.End)
          .padding({ right: 30 })

        Text('轻点空白处关闭')
          .fontSize(11)
          .fontColor(this.theme.sub)
          .opacity(this.hintOn ? 1 : 0)
          .margin({ top: 30 })
      }
      .width('100%')
      .transition(TransitionEffect.OPACITY.animation({ duration: FADE_MS, curve: Curve.EaseOut }))
    }
    .width('100%')
    .height('100%')
  }
}
