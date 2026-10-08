import { common, Want } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { AppTheme, LIGHT_THEME } from '../utils/Theme';

const URL_PRIVACY: string = 'https://policiesforge.com/p/r5247n23hd';
const URL_TERMS: string = 'https://policiesforge.com/p/r8qza22rha';

/**
 * 首次启动的条款确认：先把隐私条款与服务条款摆在眼前，勾选同意之后才进应用。
 * 两份条款交给系统浏览器打开，应用本身不申请任何网络权限。
 */
@Component
export struct PrivacyDialog {
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
      promptAction.showToast({ message: '请先阅读并勾选同意条款', duration: 1500 });
    } catch (e) {
      // 提示失败也不影响勾选
    }
    animateTo({ duration: 320, curve: Curve.EaseOut }, () => {
      this.shake = 1;
    });
    setTimeout(() => {
      animateTo({ duration: 320, curve: Curve.EaseOut }, () => {
        this.shake = 0;
      });
    }, 340);
  }

  build() {
    Stack() {
      Column() {
        Text($r('app.string.privacy_title'))
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme.text)

        Text($r('app.string.privacy_body'))
          .fontSize(14)
          .fontColor(this.theme.text2)
          .lineHeight(22)
          .margin({ top: 12 })

        Row() {
          Text($r('app.string.privacy_link_policy'))
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.primary)
            .padding({ top: 4, bottom: 4, right: 4 })
            .onClick(() => {
              this.openUrl(URL_PRIVACY);
            })
          Text($r('app.string.privacy_link_terms'))
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.primary)
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
          Text($r('app.string.privacy_check'))
            .fontSize(14)
            .fontColor(this.checked ? this.theme.text : this.theme.text2)
            .margin({ left: 8 })
        }
        .width('100%')
        .margin({ top: 10 })
        .translate({ x: this.shake * 6 })
        .onClick(() => {
          this.checked = !this.checked;
        })

        Text($r('app.string.privacy_agree'))
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

        Text($r('app.string.privacy_exit'))
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
      .constraintSize({ maxWidth: 340 })
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
