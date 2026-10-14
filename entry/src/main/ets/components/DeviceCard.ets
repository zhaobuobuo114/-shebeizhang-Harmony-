import { kindColor, kindIcon, kindLabel } from '../model/DeviceKind';
import { DateUtil } from '../utils/DateUtil';
import { Fmt } from '../utils/Format';
import { I18n } from '../utils/I18n';
import { AppTheme, LIGHT_THEME } from '../utils/Theme';

/** 单台设备卡片（点击/滑动由外层 ListItem 负责，星标自己处理点击） */
@Component
export struct DeviceCard {
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
   * 类型名、日期、金额也要挂语言依赖。
   *
   * 这三处不是"取词"而是"按 key 现查 / 现格式化"，走不到 t() 那条路上，
   * 而它们所在的表达式里读不到任何状态变量，元素就不会为它们建依赖。
   * 眼下切语言时整张卡会随 ForEach 的 key 变化而重建，但那靠的是
   * "框架把 keyGen 里读到 langVersion 也算进 ForEach 的依赖"这条没有文档保证的行为——
   * 所以这里自己把依赖挂上，不指望它。
   * 金额这一条从 v2.0.1 之后是**真有可见后果**的：货币符号改成按语言取
   * （简中/日文 ¥、繁中 NT$、英文 $），不挂依赖的话切了语言符号还是旧的。
   */
  private kindName(key: string): string {
    const v: number = this.langVersion;
    return v < 0 ? key : kindLabel(key);
  }

  private dateText(date: string): string {
    const v: number = this.langVersion;
    return v < 0 ? date : DateUtil.displayDate(date);
  }

  private money(n: number): string {
    return this.t('fmt_currency') + Fmt.money(n);
  }

  private smallMoney(n: number): string {
    return this.t('fmt_currency') + Fmt.smallMoney(n);
  }


  @Prop deviceId: string = '';
  @Prop name: string = '';
  @Prop price: number = 0;
  @Prop days: number = 0;
  @Prop avg: number = 0;
  @Prop buyDate: string = '';
  @Prop kindKey: string = 'other';
  @Prop note: string = '';
  @Prop index: number = 0;
  /**
   * 收藏状态要挂 @Watch。
   *
   * 星标画的是本地 @State favOn（点下去要立刻变色），而它原先只在 aboutToAppear 里
   * 从 @Prop favorite 取一次。恢复备份/回滚快照是**整表替换** deviceList，
   * 而 ForEach 的 key 刻意不含 favorite（含了会让卡片重建、重播入场动画）→
   * 组件被复用、aboutToAppear 不再执行 → 数据里已经取消收藏了，那颗星还亮着。
   * 安卓端不会有这个问题：DiffUtil 比的是整个 DeviceItem，favorite 变了就重绑。
   */
  @Prop @Watch('onFavoriteChange') favorite: boolean = false;
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

  /** 外部（恢复快照、整表替换）改了收藏状态时，把本地镜像同步回来 */
  private onFavoriteChange(): void {
    this.favOn = this.favorite;
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
          Text(this.money(this.price))
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.text)
            .margin({ left: 8 })
        }
        .width('100%')

        Row() {
          Text(this.kindName(this.kindKey))
            .fontSize(11)
            .fontColor(kindColor(this.kindKey))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            // 类型名让位给"已用 …"那句：英文类型名（Robot vac / VR headset）比中文长，
            // 但真正承载信息量的是使用天数，被挤的应该是标签而不是整句
            .flexShrink(1)
            .backgroundColor(Fmt.tint(kindColor(this.kindKey), '22'))
            .borderRadius(5)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          Text(this.dateText(this.buyDate))
            .fontSize(12)
            .fontColor(this.theme.sub)
            .maxLines(1)
            .margin({ left: 8 })
          Text(this.t('card_used_days',
            this.qt('p_days', this.days, this.days),
            DateUtil.humanDays(this.days)))
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
          Text(this.t('card_avg_label'))
            .fontSize(12)
            .fontColor(this.theme.sub)
            .maxLines(1)
          Text(this.smallMoney(this.avg))
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
