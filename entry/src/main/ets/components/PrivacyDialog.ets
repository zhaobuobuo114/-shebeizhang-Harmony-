import { common, Want } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { AppTheme, LIGHT_THEME } from '../utils/Theme';
import { I18n } from '../utils/I18n';

const URL_PRIVACY: string = 'https://policiesforge.com/p/r5247n23hd';
const URL_TERMS: string = 'https://policiesforge.com/p/r8qza22rha';

/**
 * 首次启动的条款确认：先把隐私条款与服务条款摆在眼前，勾选同意之后才进应用。
 * 两份条款交给系统浏览器打开，应用本身不申请任何网络权限。
 */
@Component
export struct PrivacyDialog {
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
  /** 勾选同意后的回调，由页面去落库并关掉本弹窗 */
  onAgree: () => void = () => {
  };
  /** 点「不同意，退出应用」 */
  onExit: () => void = () => {
  };

  @State checked: boolean = false;
  /** 没勾选就点进入时，勾选行左右抖一下提醒 */
  @State shake: number = 0;
  /** 抖动回落的定时器句柄。工程里其余组件都是"存句柄 + 销毁时清理"，这里原先漏了 */
  private shakeTimer: number = -1;

  aboutToDisappear(): void {
    if (this.shakeTimer !== -1) {
      clearTimeout(this.shakeTimer);
      this.shakeTimer = -1;
    }
  }

  private async openUrl(url: string): Promise<void> {
    try {
      const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const want: Want = {
        action: 'ohos.want.action.viewData',
        entities: ['entity.system.browsable'],
        uri: url
      };
      await ctx.startAbility(want);
    } catch (e) {
      // 机器上没有可打开的浏览器时保持原样，不该因此中断确认流程
    }
  }

  private hint(): void {
    try {
      promptAction.showToast({ message: this.t('privacy_hint'), duration: 1500 });
    } catch (e) {
      // 提示失败也不影响勾选
    }
    animateTo({ duration: 320, curve: Curve.EaseOut }, () => {
      this.shake = 1;
    });
    if (this.shakeTimer !== -1) {
      clearTimeout(this.shakeTimer);
    }
    this.shakeTimer = setTimeout(() => {
      this.shakeTimer = -1;
      animateTo({ duration: 320, curve: Curve.EaseOut }, () => {
        this.shake = 0;
      });
    }, 340);
  }

  build() {
    Stack() {
      Column() {
        Text(this.t('privacy_title'))
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme.text)

        /*
         * 正文放进可滚容器：这个弹框刻意不能点外部关闭，小屏 / 分屏 / 折叠屏半屏下
         * 正文一长就会把下面的按钮顶出卡片，用户既点不到"同意"也退不出去——等于锁死。
         * 安卓那边 dialog_privacy.xml 早就有 ScrollView + weight=1，这里是补同一道保险。
         */
        Scroll() {
          Text(this.t('privacy_body'))
            .fontSize(14)
            .fontColor(this.theme.text2)
            .lineHeight(22)
        }
        .layoutWeight(1)
        .align(Alignment.TopStart)
        .scrollBar(BarState.Auto)
        .margin({ top: 12 })

        Row() {
          Text(this.t('privacy_link_policy'))
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.primary)
            .maxLines(1)
            .padding({ top: 4, bottom: 4, right: 4 })
            .onClick(() => {
              this.openUrl(URL_PRIVACY);
            })
          Text(this.t('privacy_link_terms'))
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.primary)
            .maxLines(1)
            .padding({ top: 4, bottom: 4, left: 16, right: 4 })
            .onClick(() => {
              this.openUrl(URL_TERMS);
            })
          Blank()
        }
        .width('100%')
        .margin({ top: 8 })

        Row() {
          Checkbox()
            .select(this.checked)
            .selectedColor(this.theme.primary)
            .unselectedColor(this.theme.sub)
            .width(20)
            .height(20)
            .onChange((value: boolean) => {
              this.checked = value;
            })
          Text(this.t('privacy_check'))
            .fontSize(14)
            .fontColor(this.checked ? this.theme.text : this.theme.text2)
            // 勾选行是"定宽控件 + 弹性文案"：英文/日文这条比中文长，
            // 挤不动就会顶出弹窗，所以让文案自己换行吸收长度
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
            .margin({ left: 8 })
        }
        .width('100%')
        .margin({ top: 10 })
        .alignItems(VerticalAlign.Top)
        .translate({ x: this.shake * 6 })
        .onClick(() => {
          this.checked = !this.checked;
        })

        Text(this.t('privacy_agree'))
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.checked ? this.theme.onPrimary : this.theme.sub)
          .textAlign(TextAlign.Center)
          .width('100%')
          .height(46)
          .borderRadius(12)
          .backgroundColor(this.checked ? this.theme.primary : this.theme.primarySoft)
          .margin({ top: 14 })
          .onClick(() => {
            if (!this.checked) {
              this.hint();
              return;
            }
            this.onAgree();
          })

        Text(this.t('privacy_exit'))
          .fontSize(13)
          .fontColor(this.theme.sub)
          .textAlign(TextAlign.Center)
          .width('100%')
          .padding({ top: 6, bottom: 6 })
          .margin({ top: 12 })
          .onClick(() => {
            this.onExit();
          })
      }
      .width('86%')
      // 82% 与安卓 SheetKit.MAX_RATIO 同值：正文那段 Scroll 的 layoutWeight 要有上限才滚得起来
      .constraintSize({ maxWidth: 340, maxHeight: '82%' })
      .padding({ left: 22, right: 22, top: 24, bottom: 18 })
      .backgroundColor(this.theme.card)
      .borderRadius(18)
      .border({ width: 1, color: this.theme.line })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme.scrim)
    .transition(TransitionEffect.OPACITY.animation({ duration: 200 }))
  }
}
