import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { DeviceStore } from '../utils/DeviceStore';

const DOMAIN: number = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // 启动时先读一次上次选择的昼夜模式，让系统控件（输入光标、选择器）也跟着走
    DeviceStore.initByContext(this.context);
    const dark: boolean = DeviceStore.loadDark();
    try {
      this.context.getApplicationContext().setColorMode(
        dark ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK
             : ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
    } catch (err) {
      hilog.warn(DOMAIN, 'DeviceLedger', 'setColorMode failed: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'DeviceLedger', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'DeviceLedger', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    DeviceStore.init(this.context);

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'DeviceLedger', 'Failed to load content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'DeviceLedger', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'DeviceLedger', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'DeviceLedger', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'DeviceLedger', '%{public}s', 'Ability onBackground');
  }
}
