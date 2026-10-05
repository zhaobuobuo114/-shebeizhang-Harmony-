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

产物：`entry/build/default/outputs/default/entry-default-signed.hap`（约 1.3 MB），
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
| 距今天数 | 按自然日计算，「已用 730 天 · 约 2 年」 |
| 日均成本 | 价格 ÷ 已用天数，购买当天算第 1 天 |
| 汇总看板 | 设备台数、总投入、日均合计、最划算设备，新增记录即时刷新（数字滚动动画） |
| 扇形统计图 | Canvas 环图，可按 **金额 / 台数** 切换，带扇形展开动画与图例百分比 |
| 设备图标 | 41 种设备各有专属 **Q 版插画**（见 `resources/base/media/dev_*.png`） |
| 设备类型 | 手机 / 笔记本 / 平板 / … / 扫地机器人 / 电动牙刷 / 其他，共 41 类 |
| 排序 | 日均最高 / 价格最高 / 最近购买 / 用最久 |
| 收藏 | 卡片右下角星标切换收藏；「★ 收藏 N」胶囊可只看收藏 |
| 回顶部 | 向下滚过 320vp 浮出圆钮，按距离自适应（≤460ms）滚回顶部 |
| 编辑 | 点卡片直接改，日期回显 |
| 删除 | 列表左滑 → 删除，二次确认 |
| 持久化 | `Preferences` 本地存储，杀进程 / 重启不丢 |
| 昼夜模式 | 右上角太阳 / 月亮按钮切换，选择会被记住；两套配色 + 系统色模式同步 |

## 三、目录结构

```
DeviceLedger
├── AppScope/                     应用级配置与图标
├── entry/src/main/ets
│   ├── entryability/EntryAbility.ets   入口 Ability（初始化存储 / 恢复主题）
│   ├── pages/Index.ets                 主页面（列表 + 汇总 + 图表 + 编辑面板）
│   ├── components/
│   │   ├── SummaryCard.ets             顶部总览卡（数字滚动动画）
│   │   ├── ChartCard.ets               环形扇形统计图（Canvas 手绘 + 展开动画）
│   │   └── DeviceCard.ets              单台设备卡（错峰入场动画）
│   ├── model/
│   │   ├── DeviceItem.ets              数据模型 + 天数 / 日均计算
│   │   ├── DeviceKind.ets              41 种设备类型表（标签 / 配色 / 图标映射）
│   │   └── ChartData.ets               按类型聚合成饼图数据
│   └── utils/
│       ├── DateUtil.ets                日期解析、天数差、人性化文案
│       ├── DeviceStore.ets             Preferences 增删改查 + 主题持久化
│       ├── Theme.ets                   昼夜两套配色
│       ├── SystemUi.ets                同步系统色模式（状态栏 / 系统控件）
│       └── Format.ets                  金额格式化（千分位、日均、色值透明度）
└── entry/src/main/resources
    ├── base/media/dev_*.png            41 张 Q 版设备插画
    ├── base/media/ic_*.png             主题图标与空态插画
    └── dark/element/color.json         深色模式资源
```

## 四、核心算法（model/DeviceItem.ets）

```ts
daysUsed  = 今天是第几天（购买当天为 1 天）
avgPerDay = price / daysUsed
```

天数按**自然日**计算（`DateUtil.daysSince`），不受时、分、秒和时区影响；
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
  这样编辑后卡片能正确重建。
- `ChartCard` 用 Canvas 命令式绘制，主题切换不会自动重绘，所以在 `theme` 上挂 `@Watch` 手动 `draw()`。

## 六、想再加点什么

- **导出 CSV / 备份**：在 `DeviceStore` 里把 JSON 写到 `filesDir` 即可。
- **换数据库**：数据量大时改用 `relationalStore`（关系型数据库），`DeviceStore` 是对外唯一出入口，替换不影响页面。
- **加新设备类型**：在 `model/DeviceKind.ets` 的 `DEVICE_KINDS` 里加一行，再往 `kindIcon()` 的 switch 里补一条，
  并把对应的 Q 版 PNG 放进 `resources/base/media/`（命名 `dev_<key>.png`），其余逻辑自动生效。

## 七、版本历史

| 版本 | 内容 |
| --- | --- |
| v1.4 | 扇形图中心金额放大、回顶部圆钮、41 类图标默认收一行、收藏（最爱） |
| v1.3 | 按压反馈覆盖到全部可点组件；圆心文字宽度按弦长计算 |
| v1.2 | 整页滚动 + 置顶迷你汇总条；去掉点击焦点框；全应用按压动效 |
| v1.1 | 首个可运行版本：记账、天数与日均、总览看板、扇形统计图 |

各版本详见 [`CHANGELOG.md`](./CHANGELOG.md)。

---

作者：**浮梁卖茶人**
