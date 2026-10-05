import { AppTheme, LIGHT_THEME } from '../utils/Theme';
import { Fmt } from '../utils/Format';

/**
 * 顶部总览卡。
 * 注意：这里必须是自定义组件，不能用"@Builder 方法 + 参数"来实现，
 * 因为 @Builder 的参数是按值传递的，父组件状态变化时不会重新求值，会导致总览不刷新。
 */
@Component
export struct SummaryCard {
  @Prop @Watch('onData') version: number = 0;
  @Prop @Watch('onData') count: number = 0;
  @Prop @Watch('onData') total: number = 0;
  @Prop @Watch('onData') avg: number = 0;
  @Prop @Watch('onData') bestName: string = '';
  @Prop @Watch('onData') bestAvg: number = 0;
  @Prop theme: AppTheme = LIGHT_THEME;

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

  aboutToAppear(): void {
    this.dTotal = 0;
    this.dAvg = 0;
    setTimeout(() => {
      animateTo({ duration: 900, curve: Curve.EaseOut }, () => {
        this.dTotal = this.total;
        this.dAvg = this.avg;
      });
    }, 60);
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
          Text('设备总投入')
            .fontSize(12)
            .fontColor('#D8E3FF')
            .layoutWeight(1)
          Text(this.count + ' 台在册')
            .fontSize(11)
            .fontColor('#FFFFFF')
            .backgroundColor('#26FFFFFF')
            .borderRadius(10)
            .padding({ left: 9, right: 9, top: 3, bottom: 3 })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Text('¥' + Fmt.money(this.dTotal))
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .margin({ top: 8 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Row() {
          Text('日均合计')
            .fontSize(12)
            .fontColor('#D8E3FF')
          Text('¥' + Fmt.smallMoney(this.dAvg))
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
            Text('最划算')
              .fontSize(11)
              .fontColor('#FFFFFF')
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
            Text('日均 ¥' + Fmt.smallMoney(this.bestAvg))
              .fontSize(12)
              .fontColor('#FFD9C0')
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          .margin({ top: 12 })
        }
      }
      .width('100%')
      .padding(18)
      .alignItems(HorizontalAlign.Start)
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
