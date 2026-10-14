import { AppTheme, LIGHT_THEME } from '../utils/Theme';
import { I18n } from '../utils/I18n';

/** 撤销条的存活时间：给足看清和回手的时间，又不至于一直挡着 */
const LIFE_MS: number = 5000;

/**
 * 删除之后的撤销条：贴在屏幕底部，5 秒内点「撤销」就能把设备原样放回去。
 *
 * 时间一到自己滑走，不占地方也不需要用户去关。
 * 容器设成透明命中，只有条子本身吃点击，不会挡住下面的列表。
 */
@Component
export struct UndoBar {
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
  /**
   * 文案变了说明又删了一台；@Watch 让撤销条重新给足 5 秒。
   *
   * 注意：这是**已本地化的成品文本快照**（Index 用 undo_deleted 拼好后传进来），
   * 不是只有"再删一台"才会变。语言一切换，Index 必须把这段重算并重新赋值，
   * 否则条子上会继续显示旧语言的句子（@Watch 顺带还会把 5 秒重新计时，无副作用）。
   */
  @Prop @Watch('restart') text: string = '';
  /** 点「撤销」 */
  onUndo: () => void = () => {
  };
  /** 时间到、条子彻底消失（页面在这里把状态收掉） */
  onExpire: () => void = () => {
  };

  @State shown: boolean = false;
  private enterId: number = -1;
  private timerId: number = -1;
  private expireId: number = -1;

  aboutToAppear(): void {
    this.restart();
  }

  aboutToDisappear(): void {
    this.cancelTimers();
  }

  /** 入场、到期、退场回调三个定时器都留句柄，重新计数或销毁时一个都不落 */
  private restart(): void {
    this.cancelTimers();
    // 下一帧再淡入，保证从 0 起步能真正看到入场动画
    this.enterId = setTimeout(() => {
      this.enterId = -1;
      this.shown = true;
    }, 20);
    this.timerId = setTimeout(() => {
      this.timerId = -1;
      animateTo({ duration: 200, curve: Curve.EaseIn }, () => {
        this.shown = false;
      });
      this.expireId = setTimeout(() => {
        this.expireId = -1;
        this.onExpire();
      }, 220);
    }, LIFE_MS);
  }

  private cancelTimers(): void {
    if (this.enterId >= 0) {
      clearTimeout(this.enterId);
      this.enterId = -1;
    }
    if (this.timerId >= 0) {
      clearTimeout(this.timerId);
      this.timerId = -1;
    }
    if (this.expireId >= 0) {
      clearTimeout(this.expireId);
      this.expireId = -1;
    }
  }

  build() {
    Column() {
      Row() {
        Text(this.text)
          .fontSize(13)
          .fontColor(this.theme.text2)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)

        Button(this.t('undo_button'))
          .fontSize(13)
          .fontColor(this.theme.primary)
          .backgroundColor(this.theme.primarySoft)
          .borderRadius(10)
          .height(32)
          .padding({ left: 14, right: 14 })
          .margin({ left: 10 })
          .stateEffect(false)
          .focusable(false)
          .onClick(() => {
            this.onUndo();
          })
      }
      .width('92%')
      .padding({ left: 16, right: 12, top: 10, bottom: 10 })
      .backgroundColor(this.theme.card)
      .borderRadius(14)
      .shadow({
        radius: 14,
        color: this.theme.dark ? '#50000000' : '#18000000',
        offsetX: 0,
        offsetY: 4
      })
      .opacity(this.shown ? 1 : 0)
      .translate({ y: this.shown ? 0 : 28 })
      .animation({ duration: 220, curve: Curve.EaseOut })
      .margin({ bottom: 26 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.End)
    .alignItems(HorizontalAlign.Center)
    .hitTestBehavior(HitTestMode.Transparent)
  }
}
