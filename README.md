# 设备账（HarmonyOS / ArkTS）

> **作者：浮梁卖茶人**
> 一句话简介：**把每台设备的价格摊到每一天**

记录每一台设备**什么时候买的、花了多少钱、到今天用了多少天、平均每天多少钱**。
用得越久，日均成本越低——一眼看出哪些设备最"值回票价"。

变更记录见 [`CHANGELOG.md`](./CHANGELOG.md)。

## 一、快速开始

1. 打开 DevEco Studio 26.0.0 → `File > Open` → 选择本工程根目录（含 `build-profile.json5` 的那一层）。
2. 等待自动 `Sync` / `hvigor` 同步完成；若提示下载依赖，点 `Run 'ohpm install'`。
3. `File > Project Structure > Signing Configs` 登录华为账号并勾选自动签名（真机运行必需，模拟器可跳过）。
4. 连接手机或启动模拟器 → 点 ▶ 运行。

产物：`entry/build/default/outputs/default/entry-default-signed.hap`（约 2.2 MB），
也可以直接从 [Releases](../../releases) 下载已签名的安装包。

**版本配置**

| 文件 | 字段 | 值 |
| --- | --- | --- |
| `build-profile.json5` | `compatibleSdkVersion` / `targetSdkVersion` | `26.0.0` |
| `oh-package.json5` | `modelVersion` | `26.0.0` |
| `hvigor/hvigor-config.json5` | `modelVersion` | `26.0.0`（**必须与 `oh-package.json5` 一致**） |
| `hvigor/hvigor-config.json5` | `dependencies` | `{}`（留空，用 IDE 内置 hvigor 插件） |

> 若本机 SDK 不是 26.0.0，把上表三处版本号一起改成本机 SDK 的 `platformVersion`。

## 二、功能

| 功能 | 说明 |
| --- | --- |
| 记一笔 | 名称、价格、购买日期（`CalendarPicker`）、设备类型、备注 |
| 距今天数 | 按自然日计算，「已用 730 天 · 约 2 年」；用**正午日序号**相减，跨夏令时也不差一天（与安卓版同一算法） |
| 日均成本 | 价格 ÷ 已用天数，购买当天算第 1 天 |
| 汇总看板 | 设备台数、总投入、日均合计、最划算设备，新增记录即时刷新（数字滚动动画）；右侧一枚勋章胶囊显示已点亮数（如 `3 / 14`） |
| 扇形统计图 | Canvas 环图，可按 **金额 / 台数** 切换，带扇形展开动画，可收起；圆心金额按长度自适应字号，满 10 万起简写为「10.0万」；图例百分比按最大余数法分配，各段相加恒为 **100%**，扇形按累计角度绘制、最后一段收在整圈上 |
| 设备图标 | 41 种设备各有专属 **Q 版插画**（见 `resources/base/media/dev_*.png`） |
| 设备类型 | 手机 / 笔记本 / 平板 / … / 扫地机器人 / 电动牙刷 / 其他，共 41 类 |
| 勋章插画 | 14 枚勋章各一张 Q 版插画，与设备插画同一套描边与色板（`resources/base/media/badge_*.png`）；墙里未解锁的格子用 `.grayscale(1).opacity(0.35)`，不另存一套灰图 |
| 排序 | 日均最高 / 价格最高 / 最近购买 / 用最久 |
| 排序方向 | 「排序」右侧一对自绘小三角（上面尖朝上、下面尖朝下）切换正序 / 倒序，点亮的那一个始终落在对应的一侧；正序时文案变为「日均最低 / 价格最低 / 最早购买 / 用最短」，点当前选中的胶囊也可翻转 |
| 收藏 | 卡片右下角星标切换收藏；「★ 收藏 N」胶囊可只看收藏 |
| 排序胶囊 | 排序栏可以横向拨动，每颗胶囊按被可见范围盖掉多少绕 Y 轴转开、同步淡出——往左没进「排序」一侧的、往右被屏幕边缘切掉的，都像绕到后面去了；整行装得下时一颗都不动 |
| 回顶部 | 向下滚过 320vp 浮出圆钮，按距离自适应（≤460ms）滚回顶部；点下去圆钮会送出一段「起飞」动效 |
| 编辑 | 点卡片直接改，日期回显 |
| 删除 | 列表左滑 → 删除，二次确认；删掉的不真删，先进回收站，底部撤销条可当场捞回 |
| 回收站 | 被删设备保留 30 天，满期自动清除；可单独还原或彻底删除 |
| 持久化 | `Preferences` 本地存储，杀进程 / 重启不丢；写入用 `flushSync`，避免删除后立刻被强杀丢数据 |
| 里程碑勋章 | 14 枚（首台、十台、万元户、用满三年、回本达人……）；点总览卡右侧胶囊开勋章墙，未解锁的灰着并写明达成条件；拿到过就永远亮着，删设备让数字回落也不熄灭 |
| 达成弹屏 | 点亮勋章时全屏庆祝：勋章自下方升起转半圈、落位轻弹，背后一朵短小烟花（Canvas 逐帧）；一次点亮多枚可左右划看（`Swiper` + 自绘页码）。**不主动震动**——振动接口要 `ohos.permission.VIBRATE`，本应用守住零权限 |
| 备份与恢复 | 自动滚动备份 5 份、保留 30 天，连回收站与勋章一起走；可从文件恢复，覆盖前必先留底，留底失败即中止。导出文件只写设备与勋章 id，`FORMAT / VERSION / 41 类 key / 14 枚 id` 是与安卓版的互通契约 |
| 界面语言 | 简体中文 / 繁體中文 / 日本語 / English，默认跟随系统（系统语言不在这四种之内时走英文）；也可在「⋯」面板最前面的语言栏里手动换，**切换立刻生效、不重启** |
| 昼夜模式 | 右上角太阳 / 月亮按钮切换，选择会被记住；两套配色 + 系统色模式同步 |
| 首次启动 | 装完打开直接进主页面，没有开屏条款确认，也不拦新用户；本应用零权限、不联网，数据只存本机 |

## 三、目录结构

```
DeviceLedger
├── AppScope/                     应用级配置与图标
├── entry/src/main/ets
│   ├── entryability/EntryAbility.ets   入口 Ability（初始化存储 / 恢复主题）
│   ├── pages/Index.ets                 主页面（列表 + 汇总 + 图表 + 编辑面板 + 各弹层的叠放与返回键）
│   ├── components/
│   │   ├── SummaryCard.ets             顶部总览卡（数字滚动动画 + 勋章胶囊入口）
│   │   ├── ChartCard.ets               环形扇形统计图（Canvas 手绘 + 展开动画）
│   │   ├── DeviceCard.ets              单台设备卡（错峰入场动画）
│   │   ├── BadgeWall.ets               勋章墙（未解锁去饱和 + 35% 透明）
│   │   ├── BadgeCelebration.ets        达成庆祝弹屏（升起转半圈 + Canvas 逐帧烟花 + Swiper 翻页）
│   │   ├── TrashSheet.ets              回收站弹层（还原 / 彻底删除）
│   │   ├── DataSheet.ets               备份与恢复弹层（5 份槽位、导入导出）
│   │   └── UndoBar.ets                 底部撤销条（删除后限时捞回）
│   ├── model/
│   │   ├── DeviceItem.ets              数据模型 + 天数 / 日均计算 + 脏数据清洗
│   │   ├── DeviceKind.ets              41 种设备类型表（标签 / 配色 / 图标映射）
│   │   ├── TrashItem.ets               回收站条目（被删设备 + 删除时间，30 天后清除）
│   │   ├── Badge.ets                   14 枚里程碑勋章清单与判定（id / 名称 / 达成条件是双端契约）
│   │   └── ChartData.ets               按类型聚合成饼图数据
│   └── utils/
│       ├── I18n.ets                    语言中枢：运行时读 rawfile 文案表、取词与复数、解析"跟随系统"
│       ├── DateUtil.ets                日期解析、天数差（正午日序号）、脏日期修复；存储恒为 yyyy-MM-dd，展示按语言
│       ├── DeviceStore.ets             Preferences 增删改查 + 回收站 + 主题与语言持久化（写入用 flushSync）
│       ├── BackupStore.ets             5 份滚动自动备份与恢复（校验 format / version，覆盖前先留底）
│       ├── Theme.ets                   昼夜两套配色
│       ├── SystemUi.ets                同步系统色模式（状态栏 / 系统控件）
│       └── Format.ets                  金额格式化（千分位、日均、万/亿 或 K/M/B、色值透明度）
└── entry/src/main/resources
    ├── rawfile/i18n/*.json             四语言全量文案表（由根目录 _i18n_master.json 生成，勿手改）
    ├── base/media/dev_*.png            41 张 Q 版设备插画
    ├── base/media/badge_*.png          14 枚勋章插画 + badge_medal（胶囊门面）
    ├── base/media/ic_*.png             主题、收藏、置顶、排序等功能图标与空态插画
    ├── {base,zh_CN,zh_TW,ja_JP,en_US}/element/string.json   只放桌面可见的模块名与 Ability 名
    └── dark/element/color.json         深色模式资源
```

## 四、核心算法（model/DeviceItem.ets）

```ts
daysUsed  = 今天是第几天（购买当天为 1 天）
avgPerDay = price / daysUsed
```

天数按**自然日**计算（`DateUtil.daysSince`）：取两天各自正午所在的天序号相减，
所以不受时、分、秒影响，跨夏令时那一天（只有 23 小时）也不会少算一天——与安卓版用的是同一套算法。
日均金额小于 0.01 元时显示 `<0.01`，避免误导性的 `0.00`。

## 五、组件划分约定

ArkUI 里 `@Builder` 的**参数是按值传递**的：写在父组件里的 `@Builder` 方法，
拿到的是调用那一刻的值，父组件状态变化不会让它重新求值。
因此凡是需要跟着数据刷新的 UI，都拆成**独立的自定义组件**并用 `@Prop` 接收数据——
`@Prop` 是响应式引用，父组件一改就重渲染。本页面按这条规则划分：

- 汇总卡拆成 `SummaryCard`（`@Prop` 接收汇总数据）。
- `ChartCard` 的图表数据用 JSON **字符串**传递（`@Prop dataAmount: string`），
  避免数组引用不变导致 `@Watch` 不触发。
- `ForEach` 的 key 用 `DeviceCalc.key(item)`，把名称 / 价格 / 日期 / 类型 / 备注都拼进去，
  这样编辑后卡片能正确重建。**v2.0.0 起还要在 key 前面掺语言版本号**（`this.langVersion + '|' + …`）：
  行内文字是渲染时现取的，key 不含语言时框架判定"每一项都没变"，切语言后列表会整体留着上一门语言。
- `ChartCard` 用 Canvas 命令式绘制，主题切换不会自动重绘，所以在 `theme` 上挂 `@Watch` 手动 `draw()`。

### 语言切换为什么不能靠 `$r()`

两条硬限制叠在一起：

1. `i18n.System.setAppPreferredLanguage()` 的官方说明是 "Resources are loaded in the preferred
   language **when the application is launched**"——原生资源限定目录**要冷启动才生效**；
2. `$r('app.string.x')` 的参数必须是编译期字面量，连"按 key 动态取一条"都做不到。

所以全量文案落在 `resources/rawfile/i18n/<locale>.json`，由 `utils/I18n.ets` 在运行时读进内存，
切换立刻生效、不重建页面。`element/string.json` 只留桌面看得见的模块名与 Ability 名。

第二条限制还带来一个 ArkUI 特有的坑：**状态依赖只在"表达式里读到"时才建立**。
`I18n.t('x')` 不是状态变量，所以切语言后那行字不会重画。因此每个组件都挂
`@StorageProp('langVersion')`，取词统一走组件自己的 `this.t()` / `this.qt()`——它们内部读一次该值，
把依赖挂上。另有几处是"算好存进状态"的**文字快照**（含类型名的图表 JSON、勋章名与条件、
弹屏条目），不重算就会留着旧语言，由 `Index.onLangChange()` 显式刷新。

安卓端没有这两个限制（`AppCompatDelegate.setApplicationLocales()` 即时生效），
所以那一端用的是原生 `values-*/strings.xml`。两端文案同源于根目录的 `_i18n_master.json`。

### `onConfigurationUpdate` 里绝不能碰平台 API

`i18n.System.setAppPreferredLanguage()` **不是**"写完就算"，它会同步把配置变更投递回
`UIAbility.onConfigurationUpdate()`。所以"回调里再调一次 `setPreference()`"这种看起来很自然的写法
是一条自我调用的回环，实测 59 轮就把栈打爆了（v2.0.0 的切语言闪退）。

固化下来的规矩只有三条，改这块之前先想清楚：

1. 界面里那条主动路径（`Index.pickLanguage`）是唯一能调 `I18n.setPreference()` 的地方，
   它负责落库、换表、把 `langVersion` 加一；
2. `onConfigurationUpdate()` 只走 `I18n.refreshFromSystem()`——重解析、换表，不调任何平台 API；
3. `setPreference()` 用 `applying` 标志把平台调用包住（`try/finally` 复位），
   同步回调回来时一眼认出"这是我自己"，配合 `isAttached()` 一起直接返回。

`_check_lang_loop.py` 按大括号配平取出方法体来验这三条，全文搜关键字不行——文档注释里也写着这些方法名。

### 「跟随系统」读的是设备语言，不是应用偏好

`getAppPreferredLanguage()` 存的是**本应用**的覆盖值（正是 `setAppPreferredLanguage` 写进去的那份），
拿它当"系统语言"会让用户切回跟随系统时仍停在上一次的手动选择。
`I18n.systemTag()` 因此按 SDK 说明的确定程度取值：`getSystemLanguage()`（原话 "Obtains the current
system language"）→ `getSystemLanguages()`（只说 "list of system languages"，看不出是"当前在用"还是
"系统支持"，退居第二）→ 偏好列表 → 兜底 `zh`；
安卓端是同一个坑，对应的是 `LocaleManager.systemLocales`（33+；`Resources.getSystem()` 在
per-app locale 成为系统能力后也已经被进程级覆盖过，不能用），24–32 才退回 `Resources.getSystem()`。

## 六、想再加点什么

- **导出 CSV**：JSON 备份已经有了（`utils/BackupStore.ets`，5 份滚动槽位、保留 30 天、连回收站与勋章一起走），
  要给人对着看的表格，在它之上再加一层 CSV 写出即可。
- **换数据库**：数据量大时改用 `relationalStore`（关系型数据库），`DeviceStore` 是对外唯一出入口，替换不影响页面。
- **加新设备类型**：在 `model/DeviceKind.ets` 的 `DEVICE_KINDS` 里加一行，再往 `kindIcon()` 的 switch 里补一条，
  并把对应的 Q 版 PNG 放进 `resources/base/media/`（命名 `dev_<key>.png`），其余逻辑自动生效。

## 七、版本历史

| 版本 | 内容 |
| --- | --- |
| v2.0.2 | `versionName 2.0.2` / `versionCode 2000200`。三件事：① **删掉开屏的条款确认页**，新老用户装完直接进主页面（只改鸿蒙，安卓保留；`PrivacyDialog.ets` 移出工程，`privacy_agreed` 那条偏好链路的读方一并删）。② 页脚 GitHub 链接收进文字里，只露 `GitHub` 一个词（`Text(){Span+Span}`，点击挂父 `Text` 否则双触发）。③ **修导出数据是 0 字节空壳、导入找不到文件（P0）**，三个独立成因：`writeText` 拿 picker 的 `file://` URI 去做 `accessSync`/`mkdirSync`（这俩只收沙箱路径，实测抛 `13900012`，选择器已建好的空文件就此留成空壳，而调用方只 `if (ok)` 不吭声）；`fileSuffixChoices=['json']` 少个点（官方格式「描述\|后缀」，整串都是后缀，于是文件名成了 `…-1155json`）；导入选择器默认停在「最近」页，那一页对 `.json` 一个都不列。改后 URI 走 `openSync(READ_WRITE\|CREATE)`+`truncateSync`、写完比对字节数，`readText` 不再 `statSync(URI)` 而是循环读到 EOF，`fileSuffixChoices` 补点，两个选择器带 `defaultFilePathUri`，返回值换 `ExportOutcome`/`ImportOutcome` 把「取消」与「真失败」分开并各自出声。真机：导出 toast `Exported 11 devices`、文件管理实拍 2.43 KB、导入直接落在 Download 并列出备份、`Nothing new to merge`、hilog 零错误；`_test_lang_device_harmony.py` 102 条断言 0 失败。 |
| v2.0.1 | 修 v2.0.0 多语言在鸿蒙上的三处问题：① 切语言必崩 `RangeError: Stack overflow!`——`setAppPreferredLanguage` 会**同步**回调 `onConfigurationUpdate`，而该回调里又调了 `setPreference`，两个帧交替重复 59 轮打爆栈；现回调只走新增的 `refreshFromSystem()`（不再碰平台 API），并以 `applying` 标志 + `isAttached()` 两道判断保证回环不可能出现。② 简体中文设备显示英文——`resolve()` 拿整串标签和 `'zh'` 比，真机报的是 `zh-Hans-CN`，永远不相等；改成拆子标签、脚本优先于地区。③ 「跟随系统」粘在上一次手动选择——`getPreferredLanguage()` 返回的是应用自己的覆盖值，改读 `getSystemLanguages()`。另：`attach()` 提到 `setColorMode` 之前（后者也会触发一次配置回调，日志里 239 条 `load before attach` 就是这么来的）。新增 `_test_lang_resolve.mjs`（30 条用例，与安卓 `LangResolveTest` 同表）与 `_check_lang_loop.py`（14 条结构不变量）。**复查第二轮**又修：`onSave` 用 `parseFloat` 把价格**静默截断**（`12abc`→12、`1234,56`→1234，存进账本还不报错；安卓是整串拒绝，两端行为也不同）→ 改严格解析 `Fmt.parsePrice`；`@Builder` 按值传参的三处文案（回收站行、勋章行、导出按钮）永远不随语言变 → 切语言时关掉重开面板；`ChartCard` 的 `langVersion` 没挂 `@Watch`，空数据或简繁同名类型时圆心与图例不重绘 → 补 `onLang`（只重画不重播动画）；设备卡的类型名与日期原先只靠"`ForEach` key 变化会重建子组件"这条未文档保证 → 各自挂上依赖、`sortedList()` 也显式读一次；`onLangChange` 漏算撤销条文案与排序胶囊几何；总览卡「已点亮/总数」读的是不建依赖的普通 Map；金额缩写补跨档进位与 NaN 兜底；`I18n.load` 读错表时静默 → 校验并报错；导入价格补上界 `1e12`。。这些后来在 Mate 90 Pro 模拟器上按 `tools/_test_lang_device_harmony.py` 跑过 **97 条文本树断言、0 失败**——崩溃只认 `/data/log/faultlog/faultlogger` 里多出来的 jscrash 文件，不认肉眼看到的画面。**第三轮（六项改动）**：货币符号按语言（简体中文与日语 `¥`、繁體中文 `NT$`、英文 `$`，数值不换算）；「⋯」面板标题由「数据与备份」改为「菜单」；选完语言直接回到主页面；勋章墙补 `layoutWeight` 修最下方兜不住、格子露出卡片；列表底部新增可点击的个人主页链接；扇形统计图重做材质（圆角扇端 + 每片径向渐变 + 内圈高光 + 底部阴影环）。**第四轮（拍商店截图时查出）**：回收站落盘形状与读取形状不一致——`saveTrash` 曾把内存里的 `TrashItem[]` 整坨写成嵌套 `{item:{…},deletedAt}`，而 `loadTrash` 认的是扁平字段，于是重启后每条回收站记录都变成「未命名 · ¥0 · 今天」，点「恢复」会把一台空设备塞回台账；现在写扁平（与安卓版及两端通用备份格式一致），读取两种形状都认，已落盘的旧数据下次启动即正常显示。同轮另修：汇总卡「最划算」漏货币符号、编辑器价格标签固定写「（元）/（CNY）」。 |
| v2.0.0 | 全应用多语言（简中 / 繁中 / 日 / 英），默认跟随系统、可在「⋯」面板最前面的语言栏手动切换。原生资源限定目录要冷启动才生效（`setAppPreferredLanguage` 官方说明），故全量文案落在 `resources/rawfile/i18n/*.json` 由 `utils/I18n.ets` 运行时读取，切换原地生效；原先 208 处中文字面量全部入表（与安卓同源：`tools/_i18n_master.json` → `_i18n_gen.py`）。因 ArkUI 只在表达式读到状态时才建依赖，各组件挂 `@StorageProp('langVersion')` 并统一走 `this.t()`，8 处 `ForEach` 的 key 掺入语言版本号，文字快照由 `onLangChange` 重算。`¥` 与数字保持 ASCII、万/亿 在英文下改 K/M/B、存储日期恒为 `yyyy-MM-dd`；修 4 处拉丁字母下破版的布局（勋章格行数、图表头五项一行、卡片类型行挤压、条款回落）；`LEGACY_MAP` 那 7 条中文是数据键，未翻译 |
| v1.9.1 | 与安卓版同步：14 枚勋章由 emoji 换成专属 Q 版插画（与安卓同一批 PNG 文件）；达成改为全屏庆祝弹屏——升起转半圈、落位轻弹、Canvas 逐帧烟花、多枚可 `Swiper` 左右划；总览卡右侧新增勋章胶囊。烟花粒子表与安卓 `SparkleView` 的 `SPARKS` 逐行相同。为守住零权限不做主动震动 |
| v1.9.0 | 一轮彻底排查的修复，与安卓版同步落地：导入校验 format / version 与 devices 数组（此前随便一份 JSON 选覆盖会清空整库）、留底失败即中止、回收站与在册同 id 去重、勋章改为并入而非整体替换、normalize 只判 undefined 导致的 null 崩溃与 `¥NaN` 扩散；天数改用与安卓一致的"正午日序号"（旧写法跨夏令时少算一天）；写盘 `flush` 改 `flushSync`；返回键先关弹层、取消删除收回左滑条、定时器全部留句柄；回收站 / 勋章 / 自动备份三件套首次入库 |
| v1.8.0 | 首次启动先确认《隐私条款》与《服务条款》：两份条款交给系统浏览器打开，勾选同意后才能进入应用，不同意可直接退出，确认过一次后不再打扰 |
| v1.7.1 | 排序方向箭头上下各画一个朝向（上面尖朝上、下面尖朝下），切换方向翻半圈后点亮的那一个交接到正确一侧 |
| v1.7.0 | 扇形图百分比按最大余数法分配（各段相加恒为 100%）、扇形按累计角度绘制；排序胶囊横向拨动的 Y 轴立体转动；排序箭头改为自绘实心三角 + 切换方向整组翻转；置顶汇总条整体渐隐；回顶部圆钮新增「起飞」动效 |
| v1.6.1 | 动效的播放时机补进双端基准（进场完整播放、换肤原地渐变、展开重播扇形） |
| v1.6 | 动效参数定为双端基准（曲线、时长、缩放值），安卓版按此逐帧对齐 |
| v1.5.1 | 排序方向热区扩大到「排序」文字、箭头间距收紧、方向切换与收藏切换改为渐变过渡 |
| v1.5 | 排序方向（正序 / 倒序）切换、扇形图圆心金额自适应与大额简写、回顶部圆钮 |
| v1.4 | 扇形图中心金额放大、回顶部圆钮、41 类图标默认收一行、收藏（最爱） |
| v1.3 | 按压反馈覆盖到全部可点组件；圆心文字宽度按弦长计算 |
| v1.2 | 整页滚动 + 置顶迷你汇总条；去掉点击焦点框；全应用按压动效 |
| v1.1 | 首个可运行版本：记账、天数与日均、总览看板、扇形统计图 |

各版本详见 [`CHANGELOG.md`](./CHANGELOG.md)。

---

作者：**浮梁卖茶人**
