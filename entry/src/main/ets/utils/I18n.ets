import { i18n } from '@kit.LocalizationKit';
import { util } from '@kit.ArkTS';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0001;
const TAG: string = 'I18n';

/** 支持的语言。tag 用于持久化与 i18n 接口，file 是 rawfile 里的表名。 */
export enum Lang {
  ZH_CN = 'zh-CN',
  ZH_TW = 'zh-TW',
  JA = 'ja-JP',
  EN = 'en'
}

const FILE_OF: Record<string, string> = {
  'zh-CN': 'i18n/zh_CN.json',
  'zh-TW': 'i18n/zh_TW.json',
  'ja-JP': 'i18n/ja_JP.json',
  'en': 'i18n/en_US.json'
};

/**
 * 每张表里 `lang` 字段应有的值。生成器写的是主表的语言键，
 * 与运行时的标签只在日语上不同（主表 'ja' ↔ 标签 'ja-JP'），所以不能直接拿 Lang 比。
 */
const FIELD_OF: Record<string, string> = {
  'zh-CN': 'zh-CN', 'zh-TW': 'zh-TW', 'ja-JP': 'ja', 'en': 'en'
};

interface PluralForms {
  one?: string;
  other?: string;
}

interface LangTable {
  lang?: string;
  strings?: Record<string, string>;
  plurals?: Record<string, PluralForms>;
}

/**
 * 界面语言。
 *
 * 为什么鸿蒙这边不直接用 resources/{locale}/element/string.json：
 * `i18n.System.setAppPreferredLanguage()` 的官方说明写得很清楚——
 * "Resources are loaded in the preferred language when the application is launched"，
 * 也就是**要冷启动才生效**，切完语言必须杀掉重进。安卓的 per-app locale 是即时生效的，
 * 两端行为不该差这么多，所以全量文案另外落在 resources/rawfile/i18n/<locale>.json，
 * 由这里在运行时读进内存，切换立刻见效、不重建页面。
 *
 * element/string.json 里只留桌面图标那几个键（模块名、Ability 名与 label），
 * 那几个是启动器画的，本来就跟冷启动的偏好语言走。
 *
 * 文案的唯一真源是仓库根目录的 _i18n_master.json，四语言与两端资源都由 _i18n_gen.py 派生，
 * 不要手改 rawfile 下的表。
 */
export class I18n {
  /** 持久化里的"跟随系统"哨兵值；传给 i18n 接口时换成 'default' */
  static readonly FOLLOW_SYSTEM: string = 'system';

  private static ctx: common.Context | undefined = undefined;
  private static table: Record<string, string> = {};
  private static pluralTable: Record<string, PluralForms> = {};
  private static cur: Lang = Lang.ZH_CN;
  /**
   * 用户选的语言（`system` 或四种 tag）。
   * 刻意不由 I18n 去读 DeviceStore：DeviceStore → DeviceItem → DateUtil → I18n 会绕成一条循环导入，
   * 而语言是启动时就要定下的东西，让调用方（EntryAbility / Index）把值传进来，依赖方向才是干净的。
   */
  private static pref: string = 'system';

  /**
   * EntryAbility 里调用：拿到 context、按当前偏好把表读进内存。
   * 必须早于任何会触发 onConfigurationUpdate 的调用（setColorMode 就会）。
   */
  static attach(context: common.Context, preferredTag: string): void {
    I18n.ctx = context;
    I18n.pref = preferredTag;
    I18n.cur = I18n.resolve(preferredTag, I18n.systemTag());
    I18n.load(I18n.cur);
  }

  /** 还没 attach 时，配置变更回调必须整个跳过（否则会在没有 context 的情况下去读表） */
  static isAttached(): boolean {
    return I18n.ctx !== undefined;
  }

  /**
   * 把"用户选的"化成"实际用的"。
   *
   * systemTag 是设备语言标签，实测形态并不固定：可能是 `zh`，也可能是
   * `zh-Hans-CN` / `zh-Hant-TW` / `zh_CN` / `en-US`。
   * 早先这里拿整个标签与 'zh' 做全等比较，`zh-Hans-CN` 直接落空、
   * 一路掉到 return Lang.EN —— 这就是中文系统上默认显示英文的根因。
   * 现在按 BCP-47 拆子标签：首段判语言，任一段判书写系统（Hant/Hans）与地区（TW/HK/MO）。
   */
  static resolve(preferred: string, systemTag: string): Lang {
    if (preferred !== I18n.FOLLOW_SYSTEM) {
      if (preferred === Lang.ZH_CN) {
        return Lang.ZH_CN;
      }
      if (preferred === Lang.ZH_TW) {
        return Lang.ZH_TW;
      }
      if (preferred === Lang.JA) {
        return Lang.JA;
      }
      if (preferred === Lang.EN) {
        return Lang.EN;
      }
    }
    // 分隔符可能是 '-' 或 '_'，大小写也不统一。用纯字符串两段拆分，
    // 不依赖正则（ArkTS 下越少动态特性越稳）
    const raw: string = (systemTag ?? '').toLowerCase();
    const parts: string[] = [];
    const byDash: string[] = raw.split('-');
    for (let i: number = 0; i < byDash.length; i++) {
      const byUnder: string[] = byDash[i].split('_');
      for (let j: number = 0; j < byUnder.length; j++) {
        parts.push(byUnder[j]);
      }
    }
    const primary: string = parts.length > 0 ? parts[0] : '';
    if (primary === 'zh') {
      // 书写系统优先（zh-Hant-TW / zh-Hans-CN），没有脚本子标签再退到地区
      if (parts.indexOf('hant') >= 0) {
        return Lang.ZH_TW;
      }
      if (parts.indexOf('hans') >= 0) {
        return Lang.ZH_CN;
      }
      for (let i: number = 1; i < parts.length; i++) {
        const p: string = parts[i];
        if (p === 'tw' || p === 'hk' || p === 'mo') {
          return Lang.ZH_TW;
        }
      }
      return Lang.ZH_CN;
    }
    if (primary === 'ja') {
      return Lang.JA;
    }
    return Lang.EN;
  }

  static current(): Lang {
    return I18n.cur;
  }

  static preferred(): string {
    return I18n.pref;
  }

  /**
   * 正在应用语言切换。
   *
   * `setAppPreferredLanguage()` 会在**同一个调用栈里**同步触发
   * `UIAbility.onConfigurationUpdate()`。而那个回调原先又调本方法，
   * 于是 setPreference → 平台回调 → onConfigurationUpdate → setPreference → …
   * 一路递归到 `RangeError: Stack overflow` 闪退（真机日志已证实）。
   * 这个标记就是兜底：即使回调再打回来，也不会二次进入同一条链路。
   */
  private static applying: boolean = false;

  /**
   * 用户主动切换语言：记住选择、同步给系统的偏好语言（管冷启动与桌面文案）、再把新表读进内存。
   *
   * 全工程只有这里会调 `setAppPreferredLanguage`。配置变更回调一律走 refreshFromSystem()，
   * 那条路不碰平台 API，递归就断了。
   * 落库由调用方做（Index 里紧跟着 DeviceStore.saveLanguage），这里不碰存储。
   */
  static setPreference(tag: string): Lang {
    I18n.pref = tag;
    const target: Lang = I18n.resolve(tag, I18n.systemTag());
    I18n.cur = target;
    I18n.load(target);
    I18n.applying = true;
    try {
      // 这一句管的是冷启动后的资源限定目录匹配与桌面图标名；本进程的文案已由上面的 load() 换好
      i18n.System.setAppPreferredLanguage(tag === I18n.FOLLOW_SYSTEM ? 'default' : target);
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'setAppPreferredLanguage failed: %{public}s', JSON.stringify(e));
    } finally {
      I18n.applying = false;
    }
    return target;
  }

  /** 平台 API 正在被调用时，配置变更回调应当只做一次幂等的重解析，不做任何再触发动作 */
  static isApplying(): boolean {
    return I18n.applying;
  }

  /**
   * 系统配置变了（用户在系统设置里改了语言，或平台把我们的设置回调回来）。
   *
   * 与 setPreference 的关键区别：**不调用 setAppPreferredLanguage**，
   * 因此不会再触发一次配置变更，不存在回环。
   * 返回变化后的语言；没变化就返回原值，调用方据此决定要不要重绘。
   */
  static refreshFromSystem(): Lang {
    const target: Lang = I18n.resolve(I18n.pref, I18n.systemTag());
    if (target !== I18n.cur) {
      I18n.cur = target;
      I18n.load(target);
    }
    return target;
  }

  /** 取文案；{0} {1} 依次用 args 替换 */
  static t(key: string, ...args: (string | number)[]): string {
    const raw: string | undefined = I18n.table[key];
    if (raw === undefined) {
      // 漏键时宁可显示键名，也不要显示空白或让调用点崩掉
      hilog.warn(DOMAIN, TAG, 'missing key: %{public}s', key);
      return key;
    }
    if (args.length === 0) {
      return raw;
    }
    let out: string = raw;
    for (let i: number = 0; i < args.length; i++) {
      const pattern: RegExp = new RegExp('\\{' + i + '\\}', 'g');
      out = out.replace(pattern, String(args[i]));
    }
    return out;
  }

  /**
   * 取带数量的文案。
   * 只有英文分单复数（与安卓 L10n.isOne 同一条规则），其余三种语言恒用 other。
   */
  static qt(key: string, count: number, ...args: (string | number)[]): string {
    const forms: PluralForms | undefined = I18n.pluralTable[key];
    if (forms === undefined) {
      hilog.warn(DOMAIN, TAG, 'missing plural: %{public}s', key);
      return key;
    }
    const one: string | undefined = forms.one;
    const use: string = (I18n.cur === Lang.EN && count === 1 && one !== undefined)
      ? one
      : (forms.other ?? one ?? key);
    if (args.length === 0) {
      return use;
    }
    let out: string = use;
    for (let i: number = 0; i < args.length; i++) {
      const pattern: RegExp = new RegExp('\\{' + i + '\\}', 'g');
      out = out.replace(pattern, String(args[i]));
    }
    return out;
  }

  /** 数字要不要用万/亿这类汉字计数单位（英文改用 K/M） */
  static useWanNumerals(): boolean {
    return I18n.cur !== Lang.EN;
  }

  /** 货币符号（恒为 ¥，与语言无关，但仍从表里取，免得代码里散落 23 个硬编码） */
  static currency(): string {
    return I18n.t('fmt_currency');
  }

  private static load(lang: Lang): void {
    const file: string | undefined = FILE_OF[lang];
    if (file === undefined) {
      return;
    }
    const rm = I18n.ctx?.resourceManager;
    if (rm === undefined) {
      hilog.warn(DOMAIN, TAG, 'load before attach: %{public}s', lang);
      return;
    }
    try {
      const bytes: Uint8Array = rm.getRawFileContentSync(file);
      const text: string = util.TextDecoder.create('utf-8', { ignoreBOM: true }).decodeToString(bytes);
      const parsed: LangTable = JSON.parse(text) as LangTable;
      // 表读到了、也解析成功了，但内容不对（缺 strings、或者是另一门语言的表）时
      // 必须报出来：静默沿用上一份内存表的表现是"切语言没反应"，
      // 而日志里一个字都没有——那种查起来最费时间。
      if (parsed.strings === undefined) {
        hilog.error(DOMAIN, TAG, 'table for %{public}s has no strings', lang);
        return;
      }
      if (parsed.lang !== FIELD_OF[lang]) {
        hilog.error(DOMAIN, TAG, 'table for %{public}s carries lang=%{public}s',
          lang, String(parsed.lang));
        return;
      }
      I18n.table = parsed.strings;
      if (parsed.plurals !== undefined) {
        I18n.pluralTable = parsed.plurals;
      }
    } catch (e) {
      // 读表失败就沿用上一次的内存表：界面有文字可比崩掉重要
      hilog.error(DOMAIN, TAG, 'load table failed for %{public}s: %{public}s', lang, JSON.stringify(e));
    }
  }

  /**
   * 设备当前语言标签，如 `zh-Hans-CN`。
   *
   * 首选 `getSystemLanguage()`：SDK 对它的原话是 "Obtains the current system language"，
   * 没有歧义。`getSystemLanguages()` 只写了 "list of system languages"（到底是"当前在用的
   * 几种"还是"系统支持的几种"，从声明看不出来），所以退居第二；再退到偏好语言列表。
   *
   * 三个都不能换成 `getAppPreferredLanguage()`——那是我们自己用 setAppPreferredLanguage
   * 写进去的覆盖值，拿它当系统语言，"跟随系统"就会被上一次的手动选择粘住。
   */
  private static systemTag(): string {
    try {
      const one: string = i18n.System.getSystemLanguage();
      if (one.length > 0) {
        return one;
      }
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'getSystemLanguage failed: %{public}s', JSON.stringify(e));
    }
    try {
      const sys: Array<string> = i18n.System.getSystemLanguages();
      if (sys.length > 0 && sys[0].length > 0) {
        return sys[0];
      }
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'getSystemLanguages failed: %{public}s', JSON.stringify(e));
    }
    try {
      const pref: Array<string> = i18n.System.getPreferredLanguageList();
      if (pref.length > 0 && pref[0].length > 0) {
        return pref[0];
      }
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'getPreferredLanguageList failed: %{public}s', JSON.stringify(e));
    }
    return 'zh';
  }
}
