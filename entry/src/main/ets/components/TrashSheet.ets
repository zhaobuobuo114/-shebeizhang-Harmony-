import { AppTheme, LIGHT_THEME } from '../utils/Theme';
import { Fmt } from '../utils/Format';
import { DateUtil } from '../utils/DateUtil';
import { I18n } from '../utils/I18n';
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

  /**
   * 回收站那一行的副标题：价格 · 购买日 · 用了多久 · 何时删的 + 还剩几天。
   *
   * trash_meta 四种语言都是 `{0} · {1} · {2} · …{3}`（英文 `… · deleted {3}`），
   * "删除"这个词在各语言贴着日期走、位置各不相同，所以必须整条从表里取，
   * 不能在这里拿 ' · ' 把 "删除" 和日期拼起来。
   * 表里没有带第五段的版本，剩期那半句（trash_days_left / trash_expiring）
   * 本身是完整资源，用与模板一致的 ' · ' 接在整条之后——两段都是成品短语，
   * 不存在跨语言语序问题。
   */
  private metaText(t: TrashItem): string {
    const left: number = TrashCalc.daysLeft(t, this.keepDays);
    const tail: string = left > 0
      ? this.t('trash_days_left', left)
      : this.t('trash_expiring');
    const used: number = DeviceCalc.daysUsed(t.item);
    const meta: string = this.t('trash_meta',
      Fmt.moneyLabel(t.item.price),
      DateUtil.displayDate(t.item.buyDate),
      this.qt('p_used_days', used, used),
      DateUtil.formatStamp(t.deletedAt));
    return meta + ' · ' + tail;
  }

  @Builder
  private rowView(t: TrashItem) {
    Row() {
      Column() {
        Text(t.item.name.length > 0 ? t.item.name : this.t('trash_unnamed'))
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

      Button(this.t('trash_restore'))
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

      Button(this.t('trash_purge'))
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
          Text(this.t('trash_title'))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.text)
            .maxLines(1)
            .layoutWeight(1)
          Text(this.qt('p_items', this.items.length, this.items.length))
            .fontSize(12)
            .fontColor(this.theme.sub)
            .maxLines(1)
            .margin({ left: 8 })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Text(this.t('trash_hint', this.keepDays))
          .fontSize(11.5)
          .fontColor(this.theme.sub)
          .margin({ top: 10 })
          .width('100%')

        if (this.items.length === 0) {
          Text(this.t('trash_empty'))
            .fontSize(13)
            .fontColor(this.theme.sub)
            .margin({ top: 24, bottom: 24 })
        } else {
          Scroll() {
            Column({ space: 8 }) {
              ForEach(this.items, (t: TrashItem) => {
                this.rowView(t);
              }, (t: TrashItem) => this.langVersion + '|' + t.item.id + '#' + t.deletedAt)
            }
            .width('100%')
          }
          .width('100%')
          .constraintSize({ maxHeight: 340 })
          .margin({ top: 12 })
          .scrollBar(BarState.Off)

          Button(this.t('trash_clear'))
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

        Button(this.t('editor_close'))
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
