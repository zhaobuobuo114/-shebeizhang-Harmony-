import { AppTheme, LIGHT_THEME } from '../utils/Theme';
import { Fmt } from '../utils/Format';
import { I18n } from '../utils/I18n';
import { Badges } from '../model/Badge';

/**
 * 顶部总览卡。
 * 注意：这里必须是自定义组件，不能用"@Builder 方法 + 参数"来实现，
 * 因为 @Builder 的参数是按值传递的，父组件状态变化时不会重新求值，会导致总览不刷新。
 */
@Component
export struct SummaryCard {
  /**
   * 语言版本号：ArkUI 只在表达式里"读到"状态变量时才建立依赖，
   * this.t() 自己不是状态，所以切语言不会让这行字重画。
   * 取词一律走下面的 t() / qt()，它们读一次这个值，把依赖挂上。
   */
  @StorageProp('langVersion') langVersion: number = 0;

  private t(key: string, ...args: (string | number)[]): string {
    const v: number = this.langVersion;
    return v < 0 ? key : I18n.t(key, ...args);
  }

  private qt(key: string, count: number, ...args: (string | number)[]): string {
    const v: number = this.langVersion;
    return v < 0 ? key : I18n.qt(key, count, ...args);
  }

  /**
   * 金额：符号按语言取（简中/日文 ¥、繁中 NT$、英文 $），所以必须走 this.t() 拿符号，
   * 不能直接调 Fmt.moneyLabel —— 那条路上读不到 langVersion，切完语言符号还是旧的。
   */
  private money(n: number): string {
    return this.t('fmt_currency') + Fmt.money(n);
  }

  private smallMoney(n: number): string {
    return this.t('fmt_currency') + Fmt.smallMoney(n);
  }


  @Prop @Watch('onData') version: number = 0;
  @Prop @Watch('onData') count: number = 0;
  @Prop @Watch('onData') total: number = 0;
  @Prop @Watch('onData') avg: number = 0;
  @Prop @Watch('onData') bestName: string = '';
  @Prop @Watch('onData') bestAvg: number = 0;
  @Prop theme: AppTheme = LIGHT_THEME;
  /** 卡内那颗勋章胶囊：已点亮数 / 总数，点击回调由 Index 注入 */
  @Prop badgeCount: number = 0;
  @Prop badgeTotal: number = 14;
  onOpenBadges: () => void = () => {
  };

  @State pillPressed: boolean = false;

  @State dTotal: number = 0;
  @State dAvg: number = 0;

  private play(): void {
    animateTo({ duration: 720, curve: Curve.EaseOut }, () => {
      this.dTotal = this.total;
      this.dAvg = this.avg;
    });
  }

  /** 数据变化：数字滚动到新值 */
  private onData(): void {
    this.play();
  }

  private enterId: number = -1;

  aboutToAppear(): void {
    this.dTotal = 0;
    this.dAvg = 0;
    this.enterId = setTimeout(() => {
      this.enterId = -1;
      animateTo({ duration: 900, curve: Curve.EaseOut }, () => {
        this.dTotal = this.total;
        this.dAvg = this.avg;
      });
    }, 60);
  }

  /** 卡片可能在延时落定前就随列表销毁，句柄不摘就会把动画打在已经不存在的组件上 */
  aboutToDisappear(): void {
    if (this.enterId >= 0) {
      clearTimeout(this.enterId);
      this.enterId = -1;
    }
  }

  build() {
    Stack() {
      // 装饰光斑
      Column()
        .width(150)
        .height(150)
        .borderRadius(75)
        .backgroundColor('#1FFFFFFF')
        .position({ x: 218, y: -52 })
      Column()
        .width(84)
        .height(84)
        .borderRadius(42)
        .backgroundColor('#14FFFFFF')
        .position({ x: -20, y: 74 })

      Column() {
        Row() {
          Text(this.t('sum_total_label'))
            .fontSize(12)
            .fontColor('#D8E3FF')
            // 定长单行：这块的高度决定了下面大数字的落点，而勋章胶囊是 y:58 绝对定位的，
            // 标签一旦被译名撑到换行，胶囊就会压在标签第二行上。宁 ellipsis 也不换行。
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          Text(this.qt('p_in_record', this.count, this.count))
            .fontSize(11)
            .fontColor('#FFFFFF')
            .maxLines(1)
            .backgroundColor('#26FFFFFF')
            .borderRadius(10)
            .padding({ left: 9, right: 9, top: 3, bottom: 3 })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Text(this.money(this.dTotal))
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .margin({ top: 8 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Row() {
          Text(this.t('sum_avg_label'))
            .fontSize(12)
            .fontColor('#D8E3FF')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.smallMoney(this.dAvg))
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFD9C0')
            .margin({ left: 6 })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ top: 6 })

        if (this.bestName.length > 0) {
          Row() {
            Text(this.t('sum_best_label'))
              .fontSize(11)
              .fontColor('#FFFFFF')
              .maxLines(1)
              .backgroundColor('#26FFFFFF')
              .borderRadius(8)
              .padding({ left: 7, right: 7, top: 2, bottom: 2 })
            Text(this.bestName)
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor('#FFFFFF')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
              .margin({ left: 8 })
            Text(this.t('sum_avg_prefix', this.smallMoney(this.bestAvg)))
              .fontSize(12)
              .fontColor('#FFD9C0')
              .maxLines(1)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          .margin({ top: 12 })
        }
      }
      .width('100%')
      .padding(18)
      .alignItems(HorizontalAlign.Start)

      // 里程碑勋章入口：总览卡右侧那块空档，与安卓版同位置同观感。
      // 用整宽 Row 右对齐 + position 定位，避免写死 x 坐标（卡片宽度随屏宽变）
      Row() {
        Row() {
          Image(Badges.MEDAL)
            .width(16)
            .height(16)
          Text(this.t('sum_badge_progress', this.badgeCount, this.badgeTotal))
            .fontSize(11)
            .fontColor('#FFFFFF')
            .maxLines(1)
            .margin({ left: 5 })
          Text('›')
            .fontSize(13)
            .fontColor('#D8E3FF')
            .margin({ left: 2 })
        }
        .backgroundColor('#26FFFFFF')
        .borderRadius(10)
        .padding({ left: 9, top: 4, right: 7, bottom: 4 })
        .scale({ x: this.pillPressed ? 0.92 : 1, y: this.pillPressed ? 0.92 : 1 })
        .animation({ duration: 140, curve: Curve.EaseOut })
        .onClick(() => {
          this.onOpenBadges();
        })
        .onTouch((e: TouchEvent) => {
          if (e.type === TouchType.Down) {
            this.pillPressed = true;
          } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
            this.pillPressed = false;
          }
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
      .padding({ right: 18 })
      .position({ x: 0, y: 58 })
    }
    .width('100%')
    .borderRadius(20)
    .clip(true)
    .linearGradient({
      angle: 135,
      colors: [[this.theme.primary, 0.0], [this.theme.primary2, 1.0]]
    })
    .shadow({ radius: 16, color: '#332B5CFF', offsetX: 0, offsetY: 6 })
  }
}
