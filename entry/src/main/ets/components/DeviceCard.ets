import { kindColor, kindIcon, kindLabel } from '../model/DeviceKind';
import { DateUtil } from '../utils/DateUtil';
import { Fmt } from '../utils/Format';
import { AppTheme, LIGHT_THEME } from '../utils/Theme';

/** 单台设备卡片（点击/滑动由外层 ListItem 负责，星标自己处理点击） */
@Component
export struct DeviceCard {
  @Prop deviceId: string = '';
  @Prop name: string = '';
  @Prop price: number = 0;
  @Prop days: number = 0;
  @Prop avg: number = 0;
  @Prop buyDate: string = '';
  @Prop kindKey: string = 'other';
  @Prop note: string = '';
  @Prop index: number = 0;
  @Prop favorite: boolean = false;
  @Prop theme: AppTheme = LIGHT_THEME;

  /** 收藏回调，交给页面去落库 */
  onStar: (id: string) => void = (id: string) => {
  };

  @State entered: boolean = false;
  // 星标的显示状态：本地维护一份，点下去立刻变色，不等页面回传
  @State favOn: boolean = false;
  // 星标弹跳动效的缩放值
  @State starPop: number = 1;
  // 星标按压缩放
  @State pressedKey: string = '';
  private alive: boolean = true;

  /** 按下缩小、松手回弹 */
  private onPress(e: TouchEvent, key: string): void {
    if (e.type === TouchType.Down) {
      this.pressedKey = key;
    } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
      this.pressedKey = '';
    }
  }

  private sc(key: string): number {
    return this.pressedKey === key ? 0.86 : 1;
  }

  aboutToAppear(): void {
    this.favOn = this.favorite;
    const delay: number = 24 + (this.index < 10 ? this.index : 10) * 42;
    setTimeout(() => {
      if (!this.alive) {
        return;
      }
      animateTo({ duration: 430, curve: Curve.Friction }, () => {
        this.entered = true;
      });
    }, delay);
  }

  aboutToDisappear(): void {
    this.alive = false;
  }

  /** 点星标：先弹大再回落，同时把状态交给页面保存 */
  private tapStar(): void {
    this.favOn = !this.favOn;
    animateTo({ duration: 150, curve: Curve.EaseOut }, () => {
      this.starPop = 1.34;
    });
    setTimeout(() => {
      if (!this.alive) {
        return;
      }
      animateTo({ duration: 260, curve: Curve.Friction }, () => {
        this.starPop = 1;
      });
    }, 150);
    this.onStar(this.deviceId);
  }

  build() {
    Row() {
      // Q 版设备图标
      Stack() {
        Column()
          .width(58)
          .height(58)
          .borderRadius(17)
          .backgroundColor(Fmt.tint(kindColor(this.kindKey), '22'))
        Image(kindIcon(this.kindKey))
          .width(44)
          .height(44)
          .objectFit(ImageFit.Contain)
      }
      .width(58)
      .height(58)

      Column() {
        Row() {
          Text(this.name)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.text)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          Text('¥' + Fmt.money(this.price))
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.text)
            .margin({ left: 8 })
        }
        .width('100%')

        Row() {
          Text(kindLabel(this.kindKey))
            .fontSize(11)
            .fontColor(kindColor(this.kindKey))
            .backgroundColor(Fmt.tint(kindColor(this.kindKey), '22'))
            .borderRadius(5)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          Text(this.buyDate)
            .fontSize(12)
            .fontColor(this.theme.sub)
            .margin({ left: 8 })
          Text('已用 ' + this.days + ' 天 · ' + DateUtil.humanDays(this.days))
            .fontSize(12)
            .fontColor(this.theme.sub)
            .margin({ left: 8 })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
        .width('100%')
        .margin({ top: 7 })
        .alignItems(VerticalAlign.Center)

        Row() {
          Text('日均')
            .fontSize(12)
            .fontColor(this.theme.sub)
          Text('¥' + Fmt.smallMoney(this.avg))
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.accent)
            .margin({ left: 4 })
          // 备注一直参与布局（为空时只是不显示字），这样星标总能被顶到最右边
          Text(this.note)
            .fontSize(11)
            .fontColor(this.theme.sub)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ left: 10 })
            .layoutWeight(1)

          Stack() {
            Image(this.favOn ? $r('app.media.ic_star') : $r('app.media.ic_star_off'))
              .width(19)
              .height(19)
              .objectFit(ImageFit.Contain)
              .scale({ x: this.starPop, y: this.starPop })
          }
          .width(24)
          .height(24)
          .focusable(false)
          .scale({ x: this.sc('star'), y: this.sc('star') })
          .animation({ duration: 140, curve: Curve.EaseOut })
          .onTouch((e: TouchEvent) => {
            this.onPress(e, 'star');
          })
          .onClick(() => {
            this.tapStar();
          })
        }
        .width('100%')
        .margin({ top: 8 })
        .alignItems(VerticalAlign.Center)
      }
      .layoutWeight(1)
      .margin({ left: 12 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(14)
    .borderRadius(18)
    .backgroundColor(this.theme.card)
    .shadow({ radius: 12, color: this.theme.dark ? '#40000000' : '#12000000', offsetX: 0, offsetY: 3 })
    .opacity(this.entered ? 1 : 0)
    .translate({ y: this.entered ? 0 : 26 })
    .scale({ x: this.entered ? 1 : 0.96, y: this.entered ? 1 : 0.96 })
  }
}
