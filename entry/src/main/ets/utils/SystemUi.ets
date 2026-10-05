import { ConfigurationConstant, common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0002;
const TAG: string = 'SystemUi';

/**
 * 切换昼夜模式时同步应用级配色模式。
 * 这样状态栏文字、系统输入框光标、选择器等系统控件都会跟着变，
 * 否则深色界面配黑色状态栏图标会看不清。
 */
export function applyColorMode(ctx: common.UIAbilityContext, dark: boolean): void {
  try {
    ctx.getApplicationContext().setColorMode(
      dark ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK
           : ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
  } catch (e) {
    hilog.warn(DOMAIN, TAG, 'setColorMode failed');
  }
}
