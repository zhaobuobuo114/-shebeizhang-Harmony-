import { AppTheme, LIGHT_THEME } from '../utils/Theme';
import { Fmt } from '../utils/Format';
import { DateUtil } from '../utils/DateUtil';
import { DeviceCalc } from '../model/DeviceItem';
import { TrashCalc, TrashItem } from '../model/TrashItem';

/**
 * 回收站：误删的设备先落在这里，到了保留期之前随时原样放回去。
 *
 * 恢复出来的就是删除前的那条记录——收藏、备注、创建时间都还在，
 * 因为删进来时没有改过任何字段。
 */
@Component
export struct TrashSheet {
  @Prop theme: AppTheme = LIGHT_THEME;
  @Prop items: TrashItem[] = [];
  /** 保留天数，用来算「还剩几天」 */
  @Prop keepDays: number = 30;
  /** 原样放回设备列表 */
  onRestore: (id: string) => void = () => {
  };
  /** 彻底删除，删掉之后找不回来 */
  onDeleteForever: (id: string) => void = () => {
  };
  /** 清空整个回收站 */
  onClear: () => void = () => {
  };
  onClose: () => void = () => {
  };

  @State shown: boolean = false;

  aboutToAppear(): void {
    setTimeout(() => {
      this.shown = true;
    }, 20);
  }

  private metaText(t: TrashItem): string {
    const left: number = TrashCalc.daysLeft(t, this.keepDays);
    const tail: string = left > 0 ? '还剩 ' + left + ' 天' : '即将清除';
    return '¥' + Fmt.money(t.item.price) + ' · ' + t.item.buyDate +
      ' · 用了 ' + DeviceCalc.daysUsed(t.item) + ' 天 · ' +
      DateUtil.formatStamp(t.deletedAt) + ' 删除 · ' + tail;
  }

  @Builder
  private rowView(t: TrashItem) {
    Row() {
      Column() {
        Text(t.item.name.length > 0 ? t.item.name : '未命名')
          .fontSize(13.5)
          .fontColor(this.theme.text)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.metaText(t))
          .fontSize(11)
          .fontColor(this.theme.sub)
          .margin({ top: 3 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Button('恢复')
        .fontSize(12)
        .fontColor(this.theme.primary)
        .backgroundColor(this.theme.primarySoft)
        .borderRadius(9)
        .height(30)
        .padding({ left: 12, right: 12 })
        .stateEffect(false)
        .focusable(false)
        .onClick(() => {
          this.onRestore(t.item.id);
        })

      Button('彻底删除')
        .fontSize(12)
        .fontColor(this.theme.danger)
        .backgroundColor(this.theme.card2)
        .borderRadius(9)
        .height(30)
        .padding({ left: 12, right: 12 })
        .margin({ left: 8 })
        .stateEffect(false)
        .focusable(false)
        .onClick(() => {
          this.onDeleteForever(t.item.id);
        })
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor(this.theme.card2)
    .borderRadius(12)
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Column() {
      Column()
        .width('100%')
        .layoutWeight(1)
        .focusable(false)
        .onClick(() => {
          this.onClose();
        })

      Column() {
        Row() {
          Text('回收站')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.text)
            .layoutWeight(1)
          Text(this.items.length + ' 条')
            .fontSize(12)
            .fontColor(this.theme.sub)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Text('删除的设备会在这里留 ' + this.keepDays + ' 天，期间可以原样恢复；超过之后会自动清掉。')
          .fontSize(11.5)
          .fontColor(this.theme.sub)
          .margin({ top: 10 })
          .width('100%')

        if (this.items.length === 0) {
          Text('回收站是空的。')
            .fontSize(13)
            .fontColor(this.theme.sub)
            .margin({ top: 24, bottom: 24 })
        } else {
          Scroll() {
            Column({ space: 8 }) {
              ForEach(this.items, (t: TrashItem) => {
                this.rowView(t);
              }, (t: TrashItem) => t.item.id + '#' + t.deletedAt)
            }
            .width('100%')
          }
          .width('100%')
          .constraintSize({ maxHeight: 340 })
          .margin({ top: 12 })
          .scrollBar(BarState.Off)

          Button('清空回收站')
            .fontSize(14)
            .fontColor(this.theme.danger)
            .backgroundColor(this.theme.card2)
            .borderRadius(12)
            .height(42)
            .width('100%')
            .margin({ top: 12 })
            .stateEffect(false)
            .focusable(false)
            .onClick(() => {
              this.onClear();
            })
        }

        Button('关闭')
          .fontSize(15)
          .fontColor(this.theme.primary)
          .backgroundColor(this.theme.primarySoft)
          .borderRadius(12)
          .height(44)
          .width('100%')
          .margin({ top: 14 })
          .stateEffect(false)
          .focusable(false)
          .onClick(() => {
            this.onClose();
          })
      }
      .width('92%')
      .constraintSize({ maxHeight: '80%' })
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
