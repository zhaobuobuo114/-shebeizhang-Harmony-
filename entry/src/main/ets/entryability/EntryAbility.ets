import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { DeviceStore } from '../utils/DeviceStore';
import { BackupStore } from '../utils/BackupStore';
import { I18n, Lang } from '../utils/I18n';

const DOMAIN: number = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    DeviceStore.initByContext(this.context);

    // 语言必须排在 setColorMode 之前。
    // setColorMode 会立刻触发一次 onConfigurationUpdate，而那次回调原先抢在 attach 之前跑，
    // 拿不到 context 就去读表（日志里上千条 "load before attach"），
    // 并且会经由 setPreference 再调一次平台接口——正是那条回环把栈打爆的。
    I18n.attach(this.context, DeviceStore.loadLanguage());
    AppStorage.setOrCreate('langVersion', 0);

    // 昼夜模式：让系统控件（输入光标、选择器）也跟着走
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

  /**
   * 系统配置变了（用户在系统设置里改了语言，或平台把 setAppPreferredLanguage 同步回调回来）。
   *
   * 这里**绝不能**调 I18n.setPreference()：那个方法会再调一次 setAppPreferredLanguage，
   * 而它又同步触发本回调 —— 就是 v2.0.0 那个 Stack overflow 闪退的成因。
   * 一律走 refreshFromSystem()，它只重解析并换表，不再触发平台调用。
   */
  onConfigurationUpdate(config: Configuration): void {
    // 未 attach 时什么都不能做；正在应用语言切换时（平台把调用同步回调回来）也直接返回。
    // 这两道判断合起来保证：**本回调里永远不会再触发 setAppPreferredLanguage**。
    if (!I18n.isAttached() || I18n.isApplying()) {
      return;
    }
    // 与 I18n 自己的当前值比，而不是与 Ability 里缓存的字段比：
    // 用户从界面切语言时这条回调是被短路掉的，缓存字段会过期，
    // 过期之后再比就会把"没有变化"误判成"变了"，白刷一次界面。
    const before: Lang = I18n.current();
    const next: Lang = I18n.refreshFromSystem();
    if (next !== before) {
      this.bumpLangVersion();
    }
  }

  private bumpLangVersion(): void {
    const v: number = AppStorage.get<number>('langVersion') ?? 0;
    AppStorage.setOrCreate('langVersion', v + 1);
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'DeviceLedger', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    DeviceStore.init(this.context);
    // 自动备份与导出都要写应用私有目录，这里先把目录的入口交给它
    BackupStore.init(this.context);

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
