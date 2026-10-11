import { AppTheme, LIGHT_THEME } from '../utils/Theme';
import { Badges } from '../model/Badge';

/** 墙上的一格：勋章本体 + 点亮状态（没点亮就是 0） */
export interface BadgeCell {
  id: string;
  name: string;
  desc: string;
  icon: Resource;
  at: number;
}

/**
 * 勋章墙：14 枚里程碑一字排开，点亮的是彩色，没拿到的是灰的并显示达成条件。
 *
 * 拿到过的永远亮着——即便之后数字回落（比如删了设备导致总投入下降）也不会熄灭，
 * 这一点和 QQ 的勋章墙一致。
 */
@Component
export struct BadgeWall {
  @Prop theme: AppTheme = LIGHT_THEME;
  @Prop cells: BadgeCell[] = [];
  onClose: () => void = () => {
  };

  @State shown: boolean = false;

  private unlockedCount(): number {
    let n: number = 0;
    for (let i: number = 0; i < this.cells.length; i++) {
      if (this.cells[i].at > 0) {
        n += 1;
      }
    }
    return n;
  }

  aboutToAppear(): void {
    setTimeout(() => {
      this.shown = true;
    }, 20);
  }

  @Builder
  private cellView(cell: BadgeCell) {
    Column() {
      // 专属插画自带圆盘、描边与丝带；没点亮的走灰度 + 压暗，
      // 与安卓端 ColorMatrix 去饱和 + alpha 0.35 同一套语义
      Image(cell.icon)
        .width(52)
        .height(52)
        .grayscale(cell.at > 0 ? 0 : 1)
        .opacity(cell.at > 0 ? 1 : 0.35)
      Text(cell.name)
        .fontSize(12)
        .fontWeight(cell.at > 0 ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(cell.at > 0 ? this.theme.text : this.theme.sub)
        .margin({ top: 6 })
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(cell.at > 0 ? Badges.dateText(cell.at) + ' 达成' : cell.desc)
        .fontSize(9.5)
        .fontColor(this.theme.sub)
        .margin({ top: 3 })
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding({ left: 6, right: 6, top: 12, bottom: 12 })
    .backgroundColor(cell.at > 0 ? this.theme.primarySoft : this.theme.card2)
    .borderRadius(12)
    .border({
      width: cell.at > 0 ? 1 : 0,
      color: cell.at > 0 ? this.theme.primary : Color.Transparent
    })
  }

  build() {
    Column() {
      // 遮罩：点一下就关
      Column()
        .width('100%')
        .layoutWeight(1)
        .focusable(false)
        .onClick(() => {
          this.onClose();
        })

      Column() {
        Row() {
          Column() {
            Text('里程碑')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme.text)
            Text('记录设备路上的一个个小节点')
              .fontSize(11.5)
              .fontColor(this.theme.sub)
              .margin({ top: 3 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Text(this.unlockedCount() + ' / ' + this.cells.length)
            .fontSize(13)
            .fontColor(this.theme.primary)
            .backgroundColor(this.theme.primarySoft)
            .borderRadius(10)
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Grid() {
          ForEach(this.cells, (cell: BadgeCell) => {
            GridItem() {
              this.cellView(cell);
            }
          }, (cell: BadgeCell) => cell.id)
        }
        .columnsTemplate('1fr 1fr 1fr')
        .columnsGap(10)
        .rowsGap(10)
        .width('100%')
        .margin({ top: 16 })

        Button('知道了')
          .fontSize(15)
          .fontColor(this.theme.primary)
          .backgroundColor(this.theme.primarySoft)
          .borderRadius(12)
          .height(44)
          .width('100%')
          .margin({ top: 16 })
          .stateEffect(false)
          .focusable(false)
          .onClick(() => {
            this.onClose();
          })
      }
      .width('92%')
      .constraintSize({ maxHeight: '78%' })
      .padding(18)
      .backgroundColor(this.theme.card)
      .borderRadius(20)

      Column()
        .width('100%')
        .layoutWeight(1)
        .focusable(false)
        .onClick(() => {
          this.onClose();
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.shown ? this.theme.scrim : Color.Transparent)
    .animation({ duration: 200, curve: Curve.EaseOut })
  }
}
