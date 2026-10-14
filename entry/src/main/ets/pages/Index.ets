import { DeviceCalc, DeviceItem } from '../model/DeviceItem';
import { DEVICE_KINDS, kindIcon } from '../model/DeviceKind';
import { ChartData } from '../model/ChartData';
import { I18n } from '../utils/I18n';
import { DeviceStore } from '../utils/DeviceStore';
import { DateUtil } from '../utils/DateUtil';
import { Fmt } from '../utils/Format';
import { AppTheme, LIGHT_THEME, themeOf } from '../utils/Theme';
import { applyColorMode } from '../utils/SystemUi';
import { promptAction } from '@kit.ArkUI';
import { BackupFile, BackupStore, Snapshot } from '../utils/BackupStore';
import { BadgeDef, Badges } from '../model/Badge';
import { TrashItem } from '../model/TrashItem';
import { SummaryCard } from '../components/SummaryCard';
import { ChartCard } from '../components/ChartCard';
import { DeviceCard } from '../components/DeviceCard';
import { PrivacyDialog } from '../components/PrivacyDialog';
import { DataSheet } from '../components/DataSheet';
import { TrashSheet } from '../components/TrashSheet';
import { BadgeCell, BadgeWall } from '../components/BadgeWall';
import { BadgeCelebration, CelebrationItem } from '../components/BadgeCelebration';
import { UndoBar } from '../components/UndoBar';
import { common, Want } from '@kit.AbilityKit';

/**
 * 页脚那条链接指向作者的 GitHub。安卓端 `MainActivity.kt` 顶部有同一个常量，值必须一致。
 * 放进代码而不是文案表：四门语言的 `footer_github` 都只是「我的 GitHub：{0}」这个句式，
 * URL 是数据，不该有机会被译歪。
 */
const GITHUB_URL: string = 'https://github.com/zhaobuobuo114';

interface SortOption {
  label: string;
  type: string;
  selected: boolean;
  key: string;
}

interface KindTile {
  key: string;
  label: string;
  selected: boolean;
  rowKey: string;
}

/** 一个排序胶囊在行里的横向位置（相对行首），只在初次布局时量一次 */
interface ChipGeo {
  key: string;
  x: number;
  w: number;
}

/** 胶囊的 3D 变形量：归属、绕 Y 轴转多少度、还剩多少不透明度 */
interface ChipFx {
  key: string;
  rot: number;
  alpha: number;
}

@Entry
@Component
struct Index {
  /**
   * 语言版本号：ArkUI 只在表达式里"读到"状态变量时才建立依赖，
   * this.t() 自己不是状态，所以切语言不会让这行字重画。
   * 取词一律走下面的 t() / qt()，它们读一次这个值，把依赖挂上。
   */
  @StorageProp('langVersion') @Watch('onLangChange') langVersion: number = 0;

  private t(key: string, ...args: (string | number)[]): string {
    const v: number = this.langVersion;
    return v < 0 ? key : I18n.t(key, ...args);
  }

  private qt(key: string, count: number, ...args: (string | number)[]): string {
    const v: number = this.langVersion;
    return v < 0 ? key : I18n.qt(key, count, ...args);
  }

  /**
   * 金额：符号按语言取（简中/日文 ¥、繁中 NT$、英文 $），所以符号必须走 this.t() 现取。
   * 直接调 Fmt.moneyLabel() 的那条路上读不到 langVersion，切完语言符号还是旧的。
   */
  private money(n: number): string {
    return this.t('fmt_currency') + Fmt.money(n);
  }

  private smallMoney(n: number): string {
    return this.t('fmt_currency') + Fmt.smallMoney(n);
  }


  @State deviceList: DeviceItem[] = [];
  @State theme: AppTheme = LIGHT_THEME;
  @State sortType: string = 'avg';
  /** 排序方向：false = 倒序（大在前，默认），true = 正序（小在前） */
  @State sortAsc: boolean = false;

  // 汇总数据（单独存成状态，保证总览整块能稳定刷新）
  @State statCount: number = 0;
  @State statTotal: number = 0;
  @State statAvg: number = 0;
  @State statBestName: string = '';
  @State statBestAvg: number = 0;
  @State statFav: number = 0;
  @State dataVersion: number = 0;

  // 图表数据（JSON 字符串）
  @State chartAmount: string = '[]';
  @State chartCount: string = '[]';

  // 是否只看收藏
  @State favOnly: boolean = false;

  // 编辑面板
  @State showEditor: boolean = false;
  @State editId: string = '';
  @State editName: string = '';
  @State editPrice: string = '';
  @State editKind: string = 'phone';
  @State editNote: string = '';
  @State editFavorite: boolean = false;
  @State editDate: Date = new Date();
  @State errMsg: string = '';

  // 设备类型格子：默认只铺一行，点"展开全部"再看全部
  @State kindExpanded: boolean = false;
  @State kindCols: number = 4;
  @State kindGridH: number = 60;

  // 删除确认
  @State pendingDeleteId: string = '';
  /** 「清空回收站」的二次确认：这是全应用唯一不可逆的操作 */
  @State pendingClearTrash: boolean = false;

  // 回收站：删掉的设备在这里留满保留期，期间可以原样恢复
  @State trashList: TrashItem[] = [];
  @State showTrash: boolean = false;

  // 勋章：判定状态本身不参与渲染，界面用一份格子数组
  private badgeState: Map<string, number> = new Map<string, number>();
  @State badgeCellList: BadgeCell[] = [];
  @State showBadges: boolean = false;
  // 达成弹屏：本次新点亮的几枚，多枚可以在弹屏里左右划着看
  @State showCelebration: boolean = false;
  @State celebrationItems: CelebrationItem[] = [];

  // 数据与备份面板（导出 / 导入 / 自动备份）
  @State showDataSheet: boolean = false;
  @State backups: BackupFile[] = [];

  // 删除之后的撤销条
  @State showUndo: boolean = false;
  @State undoText: string = '';
  /** 撤销条管着的这台设备，时间到了就作废 */
  private undoTrash: TrashItem | undefined = undefined;

  // 首次启动的条款确认：没勾选同意之前，不把本机数据读进界面
  @State showPrivacy: boolean = false;

  // 空态图标的呼吸动画
  @State bob: boolean = false;

  // 向下滚动后是否钉住顶部那一小行汇总
  @State stickyOn: boolean = false;

  // 回顶部圆钮
  @State showTop: boolean = false;
  @State topScale: number = 1;
  @State topAlpha: number = 0;
  // 点圆钮时那一段"起飞"特效：本体脉冲、图标送出、光环扩散
  @State topIconY: number = 0;
  @State topIconAlpha: number = 1;
  @State topRingScale: number = 0.62;
  @State topRingAlpha: number = 0;

  // 排序方向切换时，整个上下箭头组绕 X 轴翻半圈
  @State sortFlip: number = 0;
  // 翻过半圈之后，写在上面的那个三角其实落到了下面：配色按"翻完之后谁在上面"给
  @State sortFlipped: boolean = false;

  // 排序胶囊的立体转动
  /** Scroll 视口宽度：判断整行装不装得下、以及右边被切掉多少 */
  private chipViewW: number = 0;
  /** 胶囊行的实际宽度：比视口宽才需要做"越过边线转开"的效果 */
  private chipRowW: number = 0;
  /** Scroll 当前的横向滚动距离 */
  private chipScrollX: number = 0;
  /** 胶囊行左边界的全局横坐标：各胶囊的静态位置都以它为基准 */
  private chipRowX: number = 0;
  /** 行的边界量到了才记胶囊位置，否则坐标没有基准 */
  private chipRowReady: boolean = false;
  /** 各胶囊相对行首的静态位置（只在初次布局时量一次） */
  private chipGeos: ChipGeo[] = [];
  /** 每个胶囊此刻的转角与透明度。做成 @State：整份重算一次刷一遍，比逐个改属性省事 */
  @State chipFxs: ChipFx[] = [];

  // 按压动效：记录当前被按下的控件标识
  @State pressedKey: string = '';

  /** 整页列表的滚动控制器，回顶部要用；用 ListScroller 才拿得到 closeAllSwipeActions */
  private scroller: ListScroller = new ListScroller();
  /** 排序胶囊那一行的横向滚动控制器：用它读偏移，好把胶囊转到该有的角度 */
  private chipScroller: Scroller = new Scroller();
  /** 当前滚动位置（用于算回顶部的时长） */
  private scrollOffset: number = 0;
  /** 回顶部圆钮的逻辑状态（不参与渲染，只用来防抖） */
  private topShown: boolean = false;
  private topTimer: number = -1;
  /** "起飞"特效里负责补回箭头的那一步 */
  private topLaunch: number = -1;
  /** 空态图标呼吸的起手延时 */
  private bobTimer: number = -1;

  /* ------------------------------ 生命周期 ------------------------------ */

  aboutToAppear(): void {
    this.theme = themeOf(DeviceStore.loadDark());
    // 第一次进来先确认条款，同意之后才读本机数据
    this.showPrivacy = !DeviceStore.loadAgreed();
    if (!this.showPrivacy) {
      this.deviceList = DeviceStore.load();
      this.trashList = DeviceStore.loadTrash(BackupStore.KEEP_DAYS);
      this.badgeState = DeviceStore.loadBadges();
      this.refreshStats();
      this.checkBadges(false);
    }
    this.bobTimer = setTimeout(() => {
      this.bobTimer = -1;
      this.bob = true;
    }, 400);
  }

  /** 页面销毁时把还在排队的动画一次性清掉，否则回调会打在已经没了的组件上 */
  aboutToDisappear(): void {
    if (this.bobTimer !== -1) {
      clearTimeout(this.bobTimer);
      this.bobTimer = -1;
    }
    if (this.topTimer !== -1) {
      clearTimeout(this.topTimer);
      this.topTimer = -1;
    }
    if (this.topLaunch !== -1) {
      clearTimeout(this.topLaunch);
      this.topLaunch = -1;
    }
  }

  onPageShow(): void {
    if (this.showPrivacy) {
      // 条款还没确认，这一屏不做任何数据刷新
      return;
    }
    // 回到前台时对齐一次磁盘数据（跨天时天数也会重算）
    const disk: DeviceItem[] = DeviceStore.load();
    if (disk.length !== this.deviceList.length) {
      this.deviceList = disk;
    }
    // 跨天之后回收站里可能有记录到期，重读一次顺手清掉
    this.trashList = DeviceStore.loadTrash(BackupStore.KEEP_DAYS);
    this.refreshStats();
  }

  /**
   * 返回键：先把最上层的弹层关掉，关完了才让系统退出应用。
   * 整页是单页面 + Stack 覆盖层，不拦的话一按返回就退到桌面、弹层还原地挂着，
   * 再进来时面板还开着，用户以为是应用卡住了。
   */
  onBackPress(): boolean {
    if (this.showPrivacy) {
      // 条款还没确认，这一屏不给返回
      return true;
    }
    if (this.showCelebration) {
      // 庆祝弹屏压在最上层，返回键先关它
      this.showCelebration = false;
      this.celebrationItems = [];
      return true;
    }
    if (this.pendingDeleteId.length > 0) {
      this.closeDeleteConfirm();
      return true;
    }
    if (this.pendingClearTrash) {
      this.pendingClearTrash = false;
      return true;
    }
    if (this.showEditor) {
      this.closeEditor();
      return true;
    }
    if (this.showTrash || this.showBadges) {
      // 回收站与勋章墙是从"数据与备份"里点进去的，退回上一层就是那里
      this.showTrash = false;
      this.showBadges = false;
      this.openDataSheet();
      return true;
    }
    if (this.showDataSheet) {
      this.showDataSheet = false;
      return true;
    }
    return false;
  }

  /* ------------------------------ 计算 ------------------------------ */

  private totalSpent(): number {
    let sum: number = 0;
    for (let i: number = 0; i < this.deviceList.length; i++) {
      sum += this.deviceList[i].price;
    }
    return sum;
  }

  private totalAvg(): number {
    let sum: number = 0;
    for (let i: number = 0; i < this.deviceList.length; i++) {
      sum += DeviceCalc.avgPerDay(this.deviceList[i]);
    }
    return sum;
  }

  private bestDevice(): DeviceItem | undefined {
    if (this.deviceList.length === 0) {
      return undefined;
    }
    let best: DeviceItem = this.deviceList[0];
    for (let i: number = 1; i < this.deviceList.length; i++) {
      if (DeviceCalc.avgPerDay(this.deviceList[i]) < DeviceCalc.avgPerDay(best)) {
        best = this.deviceList[i];
      }
    }
    return best;
  }

  /**
   * 语言变了。
   *
   * 页面上直接写的文案靠 t() 里的 langVersion 依赖自动重画，但有几处是"算好存进状态"的文字快照，
   * 不重算就会留着上一门语言：图表那两个 JSON 字符串里烘着了设备类型名，
   * 勋章格子里烘着了勋章名与达成条件。
   */
  private onLangChange(): void {
    this.refreshStats();
    this.refreshBadgeCells();
    // 撤销条那句是删除那一刻定型的，驻留 5 秒；这期间进面板切语言会整段留着旧语言
    if (this.showUndo && this.undoTrash !== undefined) {
      this.undoText = this.t('undo_deleted', this.nameOf(this.undoTrash.item));
    }
    // 庆祝弹屏那几页：CelebrationItem 的 name/dateText 是"算好的成品字符串"
    // （组件接口就是 string，见 BadgeCelebration.ets 顶上那段注释），语言一变必须自己重算。
    // 安卓端对应 BadgeCelebration.retext()。
    if (this.showCelebration && this.celebrationItems.length > 0) {
      const again: CelebrationItem[] = [];
      for (let i: number = 0; i < this.celebrationItems.length; i++) {
        const def: BadgeDef | undefined = Badges.byId(this.celebrationItems[i].id);
        if (def === undefined) {
          again.push(this.celebrationItems[i]);
          continue;
        }
        again.push({
          id: def.id,
          name: Badges.nameOf(def),
          dateText: Badges.dateText(this.badgeState.get(def.id) ?? 0),
          icon: def.icon
        });
      }
      this.celebrationItems = again;
    }
    // 排序胶囊的文案长短会变，而 chipGeos 里存的是按旧尺寸量出来的 x/w，
    // 横滚时的转角与透明度会照旧几何算 → 清掉，让下一次 onAreaChange 重新量
    this.resetChipGeos();
    // 切完语言回到主页面：面板、回收站、勋章墙都是"打开那一刻搭好的字"，留着就是半中半英。
    // 面板里那三处 @Builder（回收站行、勋章行、导出按钮）现在把键名传进去、在 builder 体内取词，
    // 已经跟着 langVersion 一起刷了，不需要再靠"关掉重开"兜——何况真机实测那条路在
    // 「跟随系统」下根本兜不住（平台不推配置回调），见 _存疑清单.md 8.3。
    // 编辑层不关：它的文字全是 build() 里现取的 this.t()，会自己跟着换。
    this.showDataSheet = false;
    this.showTrash = false;
    this.showBadges = false;
    this.pendingClearTrash = false;
    this.pendingDeleteId = '';
  }

  /** 把汇总数据同步到状态里；数字没变就不动，避免重复播放动画 */
  private refreshStats(): void {
    // 图表数据始终重新算：只改设备类型时总金额可能不变，但构成变了
    const jsonAmount: string = ChartData.json(this.deviceList, true);
    const jsonCount: string = ChartData.json(this.deviceList, false);
    if (jsonAmount !== this.chartAmount) {
      this.chartAmount = jsonAmount;
    }
    if (jsonCount !== this.chartCount) {
      this.chartCount = jsonCount;
    }

    let fav: number = 0;
    for (let i: number = 0; i < this.deviceList.length; i++) {
      if (this.deviceList[i].favorite) {
        fav = fav + 1;
      }
    }
    if (fav !== this.statFav) {
      this.statFav = fav;
    }

    const c: number = this.deviceList.length;
    const tot: number = this.totalSpent();
    const av: number = this.totalAvg();
    const best: DeviceItem | undefined = this.bestDevice();
    const bn: string = best === undefined ? '' : best.name;
    const ba: number = best === undefined ? 0 : DeviceCalc.avgPerDay(best);

    if (this.dataVersion > 0 && c === this.statCount && tot === this.statTotal &&
      av === this.statAvg && bn === this.statBestName && ba === this.statBestAvg) {
      return;
    }
    this.statCount = c;
    this.statTotal = tot;
    this.statAvg = av;
    this.statBestName = bn;
    this.statBestAvg = ba;
    this.dataVersion = this.dataVersion + 1;
  }

  private sortedList(): DeviceItem[] {
    // 读一次语言版本号：ForEach 的数据表达式必须依赖 langVersion。
    // 卡片里的类型名与日期是"按 key 现查 / 现格式化"出来的，元素自身不建语言依赖，
    // 全靠切语言时整列表随 key 重建；而"keyGen 里读到 langVersion 算不算 ForEach 的依赖"
    // 这条没有文档保证，所以在这里显式挂上（v 恒 >= 0，那个分支只是把读取变成使用）。
    const v: number = this.langVersion;
    let list: DeviceItem[] = v < 0 ? [] : this.deviceList.slice();
    // 只看收藏时先过筛，再排序
    if (this.favOnly) {
      const fav: DeviceItem[] = [];
      for (let i: number = 0; i < list.length; i++) {
        if (list[i].favorite) {
          fav.push(list[i]);
        }
      }
      list = fav;
    }
    // 倒序是默认方向：下面的比较器都按"大在前"写，正序时整体取反即可
    const dir: number = this.sortAsc ? -1 : 1;
    if (this.sortType === 'price') {
      list.sort((a: DeviceItem, b: DeviceItem): number => dir * (b.price - a.price));
    } else if (this.sortType === 'date') {
      list.sort((a: DeviceItem, b: DeviceItem): number => {
        let r: number = 0;
        if (a.buyDate < b.buyDate) {
          r = 1;
        } else if (a.buyDate > b.buyDate) {
          r = -1;
        }
        return dir * r;
      });
    } else if (this.sortType === 'days') {
      list.sort((a: DeviceItem, b: DeviceItem): number =>
        dir * (DeviceCalc.daysUsed(b) - DeviceCalc.daysUsed(a)));
    } else {
      list.sort((a: DeviceItem, b: DeviceItem): number =>
        dir * (DeviceCalc.avgPerDay(b) - DeviceCalc.avgPerDay(a)));
    }
    return list;
  }

  private findById(id: string): DeviceItem | undefined {
    for (let i: number = 0; i < this.deviceList.length; i++) {
      if (this.deviceList[i].id === id) {
        return this.deviceList[i];
      }
    }
    return undefined;
  }

  private deleteName(): string {
    const target: DeviceItem | undefined = this.findById(this.pendingDeleteId);
    return target === undefined ? '' : target.name;
  }

  /* ------------------------------ 动效 ------------------------------ */

  /** 按下时缩小、松手回弹（替掉系统默认焦点框和按压态） */
  private onPress(e: TouchEvent, key: string): void {
    if (e.type === TouchType.Down) {
      this.pressedKey = key;
    } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
      this.pressedKey = '';
    }
  }

  private sc(key: string): number {
    return this.pressedKey === key ? 0.92 : 1;
  }

  /** 整页滚动：大总览卡滑出屏幕后，在顶部钉住一小行汇总；再往下滚一点就浮出回顶部圆钮 */
  private onListScroll(offset: number): void {
    this.scrollOffset = offset;
    const need: boolean = this.deviceList.length > 0 && offset > 200;
    if (need !== this.stickyOn) {
      this.stickyOn = need;
    }
    this.setTopBtn(this.deviceList.length > 0 && offset > 320);
  }

  /**
   * 回顶部圆钮的显隐：先挂上再弹出来（170ms 冲到 1.12 倍再做 140ms 回落），
   * 收起时反过来快速缩掉，整个过程不超过 300ms，干净利索。
   */
  private setTopBtn(show: boolean): void {
    if (show === this.topShown) {
      return;
    }
    this.topShown = show;
    if (this.topTimer !== -1) {
      clearTimeout(this.topTimer);
      this.topTimer = -1;
    }
    if (show) {
      this.showTop = true;
      this.topScale = 0.3;
      this.topAlpha = 0;
      // 先让"0.3 倍"这一帧落下去，下一帧再动画到目标值，否则会从 1 开始弹
      this.topTimer = setTimeout(() => {
        this.topTimer = -1;
        animateTo({ duration: 170, curve: Curve.Friction }, () => {
          this.topScale = 1.12;
          this.topAlpha = 1;
        });
        this.topTimer = setTimeout(() => {
          this.topTimer = -1;
          animateTo({ duration: 140, curve: Curve.EaseInOut }, () => {
            this.topScale = 1;
          });
        }, 170);
      }, 16);
    } else {
      animateTo({ duration: 140, curve: Curve.EaseIn }, () => {
        this.topScale = 0.4;
        this.topAlpha = 0;
      });
      this.topTimer = setTimeout(() => {
        this.topTimer = -1;
        this.showTop = false;
      }, 140);
    }
  }

  /** 圆钮按下：快速压扁；松手：回弹（回弹用 Friction，收得干脆） */
  private onTopPress(e: TouchEvent): void {
    if (e.type === TouchType.Down) {
      animateTo({ duration: 90, curve: Curve.EaseOut }, () => {
        this.topScale = 0.84;
      });
    } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
      animateTo({ duration: 210, curve: Curve.Friction }, () => {
        this.topScale = this.topShown ? 1 : 0.4;
      });
    }
  }

  /**
   * 点回顶部圆钮要走的一整套：页面照常滚回去，圆钮自己再送一段"起飞"。
   *
   * 四件事同时开始：
   *   1. 本体先压一下再弹回来（90ms 压到 0.86、210ms Friction 弹回）；
   *   2. 箭头向上飞出圆钮并淡掉（300ms EaseIn）；
   *   3. 一圈主色光晕从圆钮大小扩到两倍再褪掉（420ms EaseOut）；
   *   4. 300ms 后箭头从下方补回原位（260ms Friction），收成一记完整的"送一趟"。
   */
  private launchTopAction(): void {
    if (this.topLaunch >= 0) {
      clearTimeout(this.topLaunch);
      this.topLaunch = -1;
    }

    this.scrollToTop();

    // 1) 本体脉冲：先矮下去再弹回来，整个动作才有"被按下去"的实感
    this.topScale = 0.86;
    animateTo({ duration: 210, curve: Curve.Friction }, () => {
      this.topScale = this.topShown ? 1 : 0.4;
    });

    // 2) 箭头起飞
    animateTo({ duration: 300, curve: Curve.EaseIn }, () => {
      this.topIconY = -26;
      this.topIconAlpha = 0;
    });

    // 3) 光晕扩散：先把初值硬设回去（写在这两行里不带动画），再放飞
    this.topRingScale = 0.62;
    this.topRingAlpha = 0.5;
    animateTo({ duration: 420, curve: Curve.EaseOut }, () => {
      this.topRingScale = 2.1;
      this.topRingAlpha = 0;
    });

    // 4) 落定的那一枚从下方补回来
    this.topLaunch = setTimeout(() => {
      this.topLaunch = -1;
      this.topIconY = 16;
      this.topIconAlpha = 0;
      animateTo({ duration: 260, curve: Curve.Friction }, () => {
        this.topIconY = 0;
        this.topIconAlpha = 1;
      });
    }, 300);
  }

  /** 回顶部：时长跟着滚动距离走，最远 460ms，曲线用 EaseOut 收尾 */
  private scrollToTop(): void {
    const off: number = this.scrollOffset;
    const span: number = off > 0 ? off : 0;
    const dur: number = span > 0 ? Math.min(460, Math.round(200 + span * 0.3)) : 260;
    this.scroller.scrollTo({
      xOffset: 0,
      yOffset: 0,
      animation: { duration: dur, curve: Curve.EaseOut }
    });
  }

  /** 排序按钮数据（每次都生成新数组，保证 ForEach 会重跑） */
  private sortOptions(): SortOption[] {
    // 正序时文案跟着反过来，免得"日均最高"配上一行从低到高的数据自相矛盾
    const asc: boolean = this.sortAsc;
    const opts: SortOption[] = [
      {
        label: asc ? this.t('sort_avg_asc') : this.t('sort_avg_desc'),
        type: 'avg',
        selected: this.sortType === 'avg',
        key: ''
      },
      {
        label: asc ? this.t('sort_price_asc') : this.t('sort_price_desc'),
        type: 'price',
        selected: this.sortType === 'price',
        key: ''
      },
      {
        label: asc ? this.t('sort_date_asc') : this.t('sort_date_desc'),
        type: 'date',
        selected: this.sortType === 'date',
        key: ''
      },
      {
        label: asc ? this.t('sort_days_asc') : this.t('sort_days_desc'),
        type: 'days',
        selected: this.sortType === 'days',
        key: ''
      }
    ];
    for (let i: number = 0; i < opts.length; i++) {
      // key 里带上方向，方向一变 ForEach 才会重跑、文案才会跟着换
      opts[i].key = opts[i].type + (opts[i].selected ? '1' : '0') + (asc ? 'a' : 'd');
    }
    return opts;
  }

  /** Area 里的量可能是数字也可能是带单位的字符串，还可能是空，统一换算成数字 */
  private lenOf(v: Length | undefined): number {
    if (v === undefined) {
      return 0;
    }
    if (typeof v === 'number') {
      return v;
    }
    const f: number = parseFloat(v.toString());
    return Number.isNaN(f) ? 0 : f;
  }

  /**
   * 记下某个胶囊在行里的横向位置（相对行首）。
   * 只需要量一次：这一行横向滚动时胶囊相对行首的位置是不变的，
   * 变的是整行被推走的距离，那部分直接读滚动控制器的偏移就行。
   */
  private recordChipGeo(key: string, area: Area): void {
    if (!this.chipRowReady) {
      // 行的左边界还没量到，记下来的坐标没有基准，先跳过
      return;
    }
    const x: number = this.lenOf(area.globalPosition.x) - this.chipRowX;
    const w: number = this.lenOf(area.width);
    let known: boolean = false;
    for (let i: number = 0; i < this.chipGeos.length; i++) {
      if (this.chipGeos[i].key === key) {
        known = true;
        break;
      }
    }
    if (!known) {
      this.chipGeos.push({ key: key, x: x, w: w });
      this.refreshChipFx();
    }
  }

  /** 每次结构性变化时清掉旧尺寸（切换排序方向会让胶囊文案变长变短） */
  private resetChipGeos(): void {
    this.chipGeos = [];
    this.chipFxs = [];
  }

  /**
   * 重算每个胶囊的转角与透明度，一次刷到 @State 里。
   * 横向滚动、初次量出几何尺寸时各调一次。
   *
   * 变形的依据是"这一颗被可见范围切掉了多少"，而不是"离这一行的中心多远"：
   * 后者会在整行明明装得下、一颗都没被挡住的时候，也把最边上那颗转掉、压暗，
   * 静止状态看着就像坏了。改成按遮挡量算之后——
   *   - 整行装得下：一颗都不动，全是正的；
   *   - 装不下：只有真的越过左右边线的那几颗才顺着透视转开、淡掉。
   */
  private refreshChipFx(): void {
    const viewW: number = this.chipViewW;
    const out: ChipFx[] = [];
    const n: number = this.chipGeos.length;
    // 整行比视口宽出来的部分；<=0 表示全都能看见，那就没有可转的东西
    const overflow: number = this.chipRowW - viewW;
    if (viewW <= 0) {
      // 视口还不知道多宽，先给个"没变形"的默认态
      for (let i: number = 0; i < n; i++) {
        out.push({ key: this.chipGeos[i].key, rot: 0, alpha: 1 });
      }
      this.chipFxs = out;
      return;
    }
    for (let i: number = 0; i < n; i++) {
      const geo: ChipGeo = this.chipGeos[i];
      if (overflow <= 0.5) {
        out.push({ key: geo.key, rot: 0, alpha: 1 });
        continue;
      }
      const w: number = geo.w;
      // 左边界是"排序"那一侧，右边界是屏幕边缘：分别量一下被它们盖掉多宽
      let hiddenLeft: number = this.chipScrollX - geo.x;
      let hiddenRight: number = (geo.x + w) - (this.chipScrollX + viewW);
      if (hiddenLeft < 0) {
        hiddenLeft = 0;
      }
      if (hiddenLeft > w) {
        hiddenLeft = w;
      }
      if (hiddenRight < 0) {
        hiddenRight = 0;
      }
      if (hiddenRight > w) {
        hiddenRight = w;
      }
      let frac: number = w > 0 ? (hiddenLeft + hiddenRight) / w : 0;
      if (frac > 1) {
        frac = 1;
      }
      out.push({
        key: geo.key,
        // 往右滚出去（被右边切掉）转向一侧，往左没进"排序"里的转向另一侧
        rot: w > 0 ? (hiddenRight - hiddenLeft) / w * 42 : 0,
        // 遮挡越多掉得越快：刚压线时几乎看不出来，越往外越淡
        alpha: 1 - 0.92 * Math.pow(frac, 1.6)
      });
    }
    this.chipFxs = out;
  }

  /** 取某个胶囊此刻的变形量（几何还没量出来时是没变形的默认态） */
  private chipFx(key: string): ChipFx {
    for (let i: number = 0; i < this.chipFxs.length; i++) {
      if (this.chipFxs[i].key === key) {
        return this.chipFxs[i];
      }
    }
    return { key: key, rot: 0, alpha: 1 };
  }

  /**
   * 上下三角该不该点亮。
   * 整组绕 X 轴翻过半圈以后，两个三角是互换位置的：写在上头的那个会转到下头去，
   * 顺带把自己镜像成朝下的形状。所以"点亮哪一个"要看翻完之后谁落在上面，
   * 而不是看谁被写在前面 —— 不然无论切几次方向，亮着的总是下面那一个。
   */
  private arrowOn(up: boolean): boolean {
    const upOnTop: boolean = !this.sortFlipped;
    const onTop: boolean = up ? upOnTop : !upOnTop;
    return onTop === this.sortAsc;
  }

  /** 切换排序方向（点箭头，或点当前已选中的那个排序胶囊） */
  private toggleSortDir(): void {
    // 文案长短会变，几何位置重量一遍
    this.resetChipGeos();
    animateTo({ duration: 260, curve: Curve.Friction }, () => {
      this.sortAsc = !this.sortAsc;
      // 整组箭头翻半圈：两个三角在 X 轴上转着交接，"点亮的那一个"同步换手
      this.sortFlip = this.sortFlip + 180;
      // 布尔量在 animateTo 里是立刻生效的，配色因此能整段 260ms 渐变到翻完后的目标
      this.sortFlipped = !this.sortFlipped;
    });
  }

  /** 设备类型格子（含选中态，key 里带上选中态） */
  private kindTiles(): KindTile[] {
    const tiles: KindTile[] = [];
    for (let i: number = 0; i < DEVICE_KINDS.length; i++) {
      const k: string = DEVICE_KINDS[i].key;
      const on: boolean = this.editKind === k;
      tiles.push({
        key: k,
        label: this.t(DEVICE_KINDS[i].labelKey),
        selected: on,
        rowKey: k + (on ? '1' : '0')
      });
    }
    return tiles;
  }

  /* ---------------------- 设备类型：收一行 / 展开全部 ---------------------- */

  /** 一行放得下几个格子（按容器实际宽度算，跟屏幕宽度无关） */
  private calcKindCols(widthVp: number): number {
    if (!(widthVp > 0)) {
      return 4;
    }
    const cols: number = Math.floor((widthVp + 6) / 66);
    return cols < 3 ? 3 : cols;
  }

  /** 收起时只铺一行，展开时铺满；66 是格子步长（60 格 + 6 间距），最后一行的底部间距不要 */
  private targetGridH(): number {
    const rows: number = this.kindExpanded
      ? Math.ceil(DEVICE_KINDS.length / this.kindCols)
      : 1;
    return rows * 66 - 6;
  }

  /** 收起时只渲染第一行的格子，展开后全给 */
  private visibleKindTiles(): KindTile[] {
    const all: KindTile[] = this.kindTiles();
    if (this.kindExpanded || this.kindCols >= all.length) {
      return all;
    }
    return all.slice(0, this.kindCols);
  }

  /** 一行就放得下时不用给展开按钮 */
  private needKindToggle(): boolean {
    return this.kindCols < DEVICE_KINDS.length;
  }

  /** 展开 / 收起：容器高度做 260ms 拉伸，格子被 clip 着一层层露出来 */
  private toggleKindExpand(): void {
    animateTo({ duration: 260, curve: Curve.Friction }, () => {
      this.kindExpanded = !this.kindExpanded;
      this.kindGridH = this.targetGridH();
    });
  }

  /** 类型格子容器宽度变化（横竖屏、折叠展开）时重算列数与高度 */
  private onKindArea(w: Length): void {
    let wv: number = 0;
    if (typeof w === 'number') {
      wv = w;
    } else {
      wv = parseFloat(w.toString());
    }
    const cols: number = this.calcKindCols(wv);
    if (cols !== this.kindCols) {
      this.kindCols = cols;
      this.kindGridH = this.targetGridH();
    }
  }

  /** 打开编辑面板时：选中的类型若不在第一行，自动展开，别让用户找不到 */
  private ensureKindVisible(): void {
    let idx: number = -1;
    for (let i: number = 0; i < DEVICE_KINDS.length; i++) {
      if (DEVICE_KINDS[i].key === this.editKind) {
        idx = i;
        break;
      }
    }
    this.kindExpanded = idx >= this.kindCols;
    this.kindGridH = this.targetGridH();
  }

  /* ------------------------------ 交互 ------------------------------ */

  private toggleTheme(): void {
    const next: AppTheme = themeOf(!this.theme.dark);
    applyColorMode(getContext(this) as common.UIAbilityContext, next.dark);
    animateTo({ duration: 260, curve: Curve.EaseInOut }, () => {
      this.theme = next;
    });
    DeviceStore.saveDark(next.dark);
  }

  /** 按 id 回查在册列表里最新的那份，找不到返回 undefined */
  private findLive(id: string): DeviceItem | undefined {
    for (let i: number = 0; i < this.deviceList.length; i++) {
      if (this.deviceList[i].id === id) {
        return this.deviceList[i];
      }
    }
    return undefined;
  }

  private openEditor(item: DeviceItem | undefined): void {
    this.errMsg = '';
    // 传进来的可能是刚才点过星标之前的旧对象：ForEach 的 key 故意不含 favorite，
    // 那条卡片组件不会重跑，闭包里的 item 还停在收藏前的样子。
    // 一律按 id 回查在册的最新一份，否则面板会把旧收藏状态回显、一保存就把刚点的收藏抹掉。
    const current: DeviceItem | undefined = item === undefined ? undefined : (this.findLive(item.id) ?? item);
    if (current === undefined) {
      this.editId = '';
      this.editName = '';
      this.editPrice = '';
      this.editKind = 'phone';
      this.editNote = '';
      this.editFavorite = false;
      this.editDate = new Date();
    } else {
      this.editId = current.id;
      this.editName = current.name;
      this.editPrice = current.price.toString();
      this.editKind = current.category;
      this.editNote = current.note;
      this.editFavorite = current.favorite;
      this.editDate = DateUtil.parse(current.buyDate);
    }
    // 类型区默认收成一行；选中的类型不在第一行就自动展开
    this.ensureKindVisible();
    animateTo({ duration: 280, curve: Curve.EaseOut }, () => {
      this.showEditor = true;
    });
  }

  private closeEditor(): void {
    this.errMsg = '';
    animateTo({ duration: 240, curve: Curve.EaseIn }, () => {
      this.showEditor = false;
    });
  }

  /** 关掉删除确认，同时把还拨开的左滑条收回——否则红色删除按钮会一直露在那一行上 */
  private closeDeleteConfirm(): void {
    animateTo({ duration: 180, curve: Curve.EaseIn }, () => {
      this.pendingDeleteId = '';
    });
    this.scroller.closeAllSwipeActions();
  }

  private onSave(): void {
    const name: string = this.editName.trim();
    const price: number = Fmt.parsePrice(this.editPrice);
    const buyDate: string = DateUtil.format(
      this.editDate.getFullYear(), this.editDate.getMonth() + 1, this.editDate.getDate());

    if (name.length === 0) {
      this.errMsg = this.t('err_name');
      return;
    }
    if (this.editPrice.trim().length === 0) {
      this.errMsg = this.t('err_price_empty');
      return;
    }
    if (!(price > 0) || price > DeviceCalc.MAX_PRICE) {
      // 上限必须与 DeviceCalc.normalize 的钳制同一条：否则一个 13 位的价格能录进来、
      // 当场显示正常，杀掉进程重开却被清洗规则静默归零（数据没了）
      this.errMsg = this.t('err_price_invalid');
      return;
    }
    if (buyDate > DateUtil.today()) {
      this.errMsg = this.t('err_date_future');
      return;
    }

    const list: DeviceItem[] = this.deviceList.slice();
    if (this.editId.length === 0) {
      list.push({
        id: DeviceStore.newId(),
        name: name,
        price: price,
        buyDate: buyDate,
        category: this.editKind,
        note: this.editNote.trim(),
        favorite: this.editFavorite,
        createdAt: Date.now()
      });
    } else {
      for (let i: number = 0; i < list.length; i++) {
        if (list[i].id === this.editId) {
          list[i] = {
            id: list[i].id,
            name: name,
            price: price,
            buyDate: buyDate,
            category: this.editKind,
            note: this.editNote.trim(),
            favorite: this.editFavorite,
            createdAt: list[i].createdAt
          };
          break;
        }
      }
    }

    // 覆盖写库之前留一份快照；勋章在落库之后重新判定一次
    BackupStore.maybeBackup(this.currentSnapshot());
    this.deviceList = list;
    DeviceStore.save(list);
    this.refreshStats();
    this.checkBadges(true);
    this.closeEditor();
  }

  /** 点设备卡右下角的星标：切换收藏并落库 */
  private toggleFavorite(id: string): void {
    const list: DeviceItem[] = [];
    for (let i: number = 0; i < this.deviceList.length; i++) {
      const it: DeviceItem = this.deviceList[i];
      if (it.id === id) {
        list.push({
          id: it.id,
          name: it.name,
          price: it.price,
          buyDate: it.buyDate,
          category: it.category,
          note: it.note,
          favorite: !it.favorite,
          createdAt: it.createdAt
        });
      } else {
        list.push(it);
      }
    }
    this.deviceList = list;
    DeviceStore.save(list);
    this.refreshStats();
    // 收藏数本身就是勋章条件，改完顺手判一次
    this.checkBadges(true);
  }

  /** 只看收藏：筛选 + 立刻把列表滚回顶部（不然筛完停在半空很奇怪） */
  private setFavOnly(on: boolean): void {
    if (this.favOnly === on) {
      return;
    }
    animateTo({ duration: 220, curve: Curve.Friction }, () => {
      this.favOnly = on;
    });
    if (this.scrollOffset > 0) {
      this.scrollToTop();
    }
  }

  /** 确认删除：设备不直接抹掉，先移进回收站，同时弹一条撤销 */
  private confirmDelete(): void {
    const id: string = this.pendingDeleteId;
    if (id.length === 0) {
      return;
    }
    const target: DeviceItem | undefined = this.findById(id);
    animateTo({ duration: 200, curve: Curve.EaseIn }, () => {
      this.pendingDeleteId = '';
    });
    if (target === undefined) {
      return;
    }

    // 大动作之前先留一份底，真删错了还有回滚的余地
    BackupStore.maybeBackup(this.currentSnapshot());

    const list: DeviceItem[] = [];
    for (let i: number = 0; i < this.deviceList.length; i++) {
      if (this.deviceList[i].id !== id) {
        list.push(this.deviceList[i]);
      }
    }
    const trashed: TrashItem = { item: target, deletedAt: Date.now() };
    this.deviceList = list;
    this.trashList = [trashed].concat(this.trashList);
    DeviceStore.save(list);
    DeviceStore.saveTrash(this.trashList);
    this.refreshStats();

    this.undoTrash = trashed;
    this.undoText = this.t('undo_deleted', this.nameOf(target));
    this.showUndo = true;
  }

  /** 点撤销条上的「撤销」：把刚删的那台原样放回去 */
  private undoDelete(): void {
    const t: TrashItem | undefined = this.undoTrash;
    this.showUndo = false;
    this.undoTrash = undefined;
    if (t === undefined) {
      return;
    }
    this.restoreFromTrash(t.item.id);
  }

  /* ------------------------------ 回收站 ------------------------------ */

  /** 原样放回设备列表 */
  private restoreFromTrash(id: string): void {
    const idx: number = this.findTrashIndex(id);
    if (idx < 0) {
      return;
    }
    // 同 id 的设备已经在册（多半是跨端合并留下的），再塞一次列表里就有两条同 id：
    // 收藏会整组串号、汇总台数双算、下次合并还会静默丢一条。这里只把它从回收站清掉。
    for (let i: number = 0; i < this.deviceList.length; i++) {
      if (this.deviceList[i].id === id) {
        const restOnly: TrashItem[] = this.trashList.slice();
        restOnly.splice(idx, 1);
        this.trashList = restOnly;
        DeviceStore.saveTrash(restOnly);
        this.toast(this.t('import_duplicate'));
        return;
      }
    }
    const t: TrashItem = this.trashList[idx];
    const list: DeviceItem[] = this.deviceList.slice();
    list.push(t.item);
    const rest: TrashItem[] = this.trashList.slice();
    rest.splice(idx, 1);
    this.deviceList = list;
    this.trashList = rest;
    DeviceStore.save(list);
    DeviceStore.saveTrash(rest);
    this.refreshStats();
    this.checkBadges(false);
  }

  /** 彻底删除：删掉之后找不回来 */
  private deleteForever(id: string): void {
    const rest: TrashItem[] = [];
    for (let i: number = 0; i < this.trashList.length; i++) {
      if (this.trashList[i].item.id !== id) {
        rest.push(this.trashList[i]);
      }
    }
    this.trashList = rest;
    DeviceStore.saveTrash(rest);
  }

  /**
   * 「清空回收站」先问一句再动手。
   *
   * 这是全应用唯一一个不可逆的操作（其余都有 30 天回收站或 5 秒撤销兜底），
   * 而安卓端一直有这句确认（`MainActivity.askClearTrash`）。鸿蒙端原先一点就清空，
   * `clear_trash_title` / `clear_trash_message` / `clear_trash_confirm` 三条文案
   * 在主表里躺了很久、零引用——不是换了措辞，是整段确认缺失。
   */
  private askClearTrash(): void {
    if (this.trashList.length === 0) {
      return;
    }
    this.pendingClearTrash = true;
  }

  private confirmClearTrash(): void {
    this.pendingClearTrash = false;
    this.clearTrash();
  }

  private clearTrash(): void {
    this.trashList = [];
    DeviceStore.saveTrash([]);
  }

  private findTrashIndex(id: string): number {
    for (let i: number = 0; i < this.trashList.length; i++) {
      if (this.trashList[i].item.id === id) {
        return i;
      }
    }
    return -1;
  }

  private nameOf(item: DeviceItem): string {
    return item.name.length > 0 ? item.name : this.t('trash_unnamed');
  }

  /* ------------------------------ 勋章 ------------------------------ */

  /** 勋章只增不减：达成即点亮并记下时间，之后数字回落也不熄灭 */
  private checkBadges(announce: boolean): void {
    const fresh: BadgeDef[] = Badges.evaluate(this.deviceList, this.badgeState);
    this.refreshBadgeCells();
    if (fresh.length === 0) {
      return;
    }
    DeviceStore.saveBadges(this.badgeState);
    this.refreshBadgeCells();
    if (announce) {
      // 达成反馈只走弹屏这一条路径，不再叠一条 Toast（与安卓版一致）
      const items: CelebrationItem[] = [];
      for (let i: number = 0; i < fresh.length; i++) {
        items.push({
          id: fresh[i].id,
          name: Badges.nameOf(fresh[i]),
          dateText: Badges.dateText(this.badgeState.get(fresh[i].id) ?? 0),
          icon: fresh[i].icon
        });
      }
      this.celebrationItems = items;
      this.showCelebration = true;
    }
  }

  /** 把判定状态摊平成界面能直接渲染的格子数组 */
  private refreshBadgeCells(): void {
    const cells: BadgeCell[] = [];
    for (let i: number = 0; i < Badges.ALL.length; i++) {
      const def = Badges.ALL[i];
      const at: number | undefined = this.badgeState.get(def.id);
      cells.push({
        id: def.id,
        name: Badges.nameOf(def),
        desc: Badges.descOf(def),
        icon: def.icon,
        at: at === undefined ? 0 : at
      });
    }
    this.badgeCellList = cells;
  }

  private badgeUnlockedCount(): number {
    let n: number = 0;
    for (let i: number = 0; i < this.badgeCellList.length; i++) {
      if (this.badgeCellList[i].at > 0) {
        n += 1;
      }
    }
    return n;
  }

  /* ------------------------------ 导出 / 导入 / 备份 ------------------------------ */

  private currentSnapshot(): Snapshot {
    return {
      devices: this.deviceList.slice(),
      recycle: this.trashList.slice(),
      badges: new Map<string, number>(this.badgeState),
      exportedAt: Date.now()
    };
  }

  /** 把一份数据整体落在本机：设备、回收站、勋章一起写，再整屏刷新 */
  private applySnapshot(s: Snapshot): void {
    this.deviceList = s.devices;
    // 同一台设备不能既在册又在回收站，否则在回收站点一次"恢复"就多出一台重复项
    const live: Set<string> = new Set<string>();
    for (let i: number = 0; i < this.deviceList.length; i++) {
      live.add(this.deviceList[i].id);
    }
    const recycle: TrashItem[] = [];
    for (let i: number = 0; i < s.recycle.length; i++) {
      if (!live.has(s.recycle[i].item.id)) {
        recycle.push(s.recycle[i]);
      }
    }
    this.trashList = recycle;
    // 勋章只增不减：整体替换会让那次快照之后点亮的勋章凭空消失，
    // 重新判定虽然能再点亮，达成日期却被改写成今天，原始时间就丢了。这里是并入而非覆盖。
    s.badges.forEach((at: number, id: string) => {
      const has: number | undefined = this.badgeState.get(id);
      if (has === undefined || at < has) {
        this.badgeState.set(id, at);
      }
    });
    DeviceStore.save(this.deviceList);
    DeviceStore.saveTrash(this.trashList);
    DeviceStore.saveBadges(this.badgeState);
    this.refreshStats();
    this.checkBadges(false);
  }

  private openDataSheet(): void {
    this.backups = BackupStore.listBackups();
    this.showDataSheet = true;
  }

  /** 弹系统文件选择器存成一个 .json */
  private async exportData(): Promise<void> {
    const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const ok: boolean = await BackupStore.saveViaPicker(ctx, this.currentSnapshot());
    if (ok) {
      // 与安卓版同一句：报台数，不然用户不知道到底带走了多少条
      this.toast(this.t('import_exported', this.deviceList.length));
    }
  }

  /** 弹系统文件选择器挑一个 .json 进来 */
  private async importData(): Promise<void> {
    const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const snap: Snapshot | undefined = await BackupStore.pickViaPicker(ctx);
    if (snap === undefined) {
      return;
    }
    // 导入前先把当前状态强制留一份底；留底没成功就不能动本机数据
    if (!BackupStore.forceBackup(this.currentSnapshot())) {
      this.toast(this.t('import_rollback_import'));
      return;
    }
    const before: number = this.deviceList.length;
    this.applySnapshot(BackupStore.merge(this.currentSnapshot(), snap));
    this.showDataSheet = false;
    // 报"新增了几台"，而不是合并后的总台数——后者会让人以为文件里的设备全都进来了
    const added: number = this.deviceList.length - before;
    this.toast(added > 0 ? this.t('import_done', added) : this.t('import_nothing_new'));
  }

  /** 回滚到某一槽位的自动备份 */
  private restoreBackup(slot: number): void {
    const snap: Snapshot | undefined = BackupStore.readBackup(slot);
    if (snap === undefined) {
      this.toast(this.t('import_backup_unreadable'));
      return;
    }
    if (!BackupStore.forceBackup(this.currentSnapshot())) {
      this.toast(this.t('import_rollback_restore'));
      return;
    }
    this.applySnapshot(snap);
    this.showDataSheet = false;
    this.toast(this.t('restore_done_point'));
  }

  /**
   * 换语言。
   *
   * 鸿蒙的原生资源限定目录要冷启动才生效，所以文案表是运行时从 rawfile 读进内存的，
   * 这里只需要三步：落库 -> 重读表 -> 把 langVersion 加一。
   * 界面上所有走 t() 的文字随之重画；几处"算好存进状态"的文字快照由 onLangChange 补算。
   */
  private pickLanguage(tag: string): void {
    if (I18n.preferred() === tag) {
      return;
    }
    DeviceStore.saveLanguage(tag);
    I18n.setPreference(tag);
    const next: number = (AppStorage.get<number>('langVersion') ?? 0) + 1;
    AppStorage.setOrCreate('langVersion', next);
  }

  private toast(msg: string): void {
    try {
      promptAction.showToast({ message: msg, duration: 2000 });
    } catch (e) {
      // 提示失败不该影响数据本身
    }
  }

  /**
   * 用系统浏览器打开作者的 GitHub。机器上没有可打开的浏览器时静默失败——
   * 与隐私弹窗里那两个链接同一套做法（`PrivacyDialog.openUrl`）：点不动就是点不动，
   * 不该拿一条报错打断用户。
   */
  private openGitHub(): void {
    try {
      const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const want: Want = {
        action: 'ohos.want.action.viewData',
        entities: ['entity.system.browsable'],
        uri: GITHUB_URL
      };
      ctx.startAbility(want).catch(() => {
        // 没有可用浏览器，保持原样
      });
    } catch (e) {
      // 同上
    }
  }

  /* ------------------------------ 界面 ------------------------------ */

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        /* ============ 整页一个 List：顶部区域随列表一起滚走 ============ */
        List({ space: 12, scroller: this.scroller }) {
          ListItem() {
            Column() {
              /* ============ 顶栏 ============ */
              Row() {
                Column() {
                  Text(this.t('app_name'))
                    .fontSize(24)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.theme.text)
                  Text(this.t('top_slogan'))
                    .fontSize(12)
                    .fontColor(this.theme.sub)
                    .margin({ top: 3 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Stack() {
                  Image(this.theme.dark ? $r('app.media.ic_moon') : $r('app.media.ic_sun'))
                    .width(22)
                    .height(22)
                    .rotate({ z: 1, angle: this.theme.dark ? 20 : 0 })
                }
                .width(38)
                .height(38)
                .borderRadius(19)
                .backgroundColor(this.theme.card)
                .shadow({ radius: 8, color: this.theme.dark ? '#40000000' : '#10000000', offsetX: 0, offsetY: 2 })
                .focusable(false)
                .scale({ x: this.sc('theme'), y: this.sc('theme') })
                .animation({ duration: 140, curve: Curve.EaseOut })
                .onTouch((e: TouchEvent) => {
                  this.onPress(e, 'theme');
                })
                .onClick(() => {
                  this.toggleTheme();
                })

                Stack() {
                  Text('⋯')
                    .fontSize(20)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.theme.text2)
                }
                .width(38)
                .height(38)
                .borderRadius(19)
                .backgroundColor(this.theme.card)
                .shadow({ radius: 8, color: this.theme.dark ? '#40000000' : '#10000000', offsetX: 0, offsetY: 2 })
                .margin({ left: 10 })
                .focusable(false)
                .scale({ x: this.sc('more'), y: this.sc('more') })
                .animation({ duration: 140, curve: Curve.EaseOut })
                .onTouch((e: TouchEvent) => {
                  this.onPress(e, 'more');
                })
                .onClick(() => {
                  this.openDataSheet();
                })

                Button(this.t('top_add'))
                  .fontSize(14)
                  .fontColor(Color.White)
                  .backgroundColor(this.theme.primary)
                  .borderRadius(19)
                  .height(38)
                  .padding({ left: 16, right: 16 })
                  .margin({ left: 10 })
                  .stateEffect(false)
                  .focusable(false)
                  .scale({ x: this.sc('add'), y: this.sc('add') })
                  .animation({ duration: 140, curve: Curve.EaseOut })
                  .onTouch((e: TouchEvent) => {
                    this.onPress(e, 'add');
                  })
                  .onClick(() => {
                    this.openEditor(undefined);
                  })
              }
              .width('100%')
              .padding({ left: 2, right: 2, top: 14, bottom: 12 })
              .alignItems(VerticalAlign.Center)

              /* ============ 总览 ============ */
              SummaryCard({
                version: this.dataVersion,
                count: this.statCount,
                total: this.statTotal,
                avg: this.statAvg,
                bestName: this.statBestName,
                bestAvg: this.statBestAvg,
                badgeCount: this.badgeUnlockedCount(),
                badgeTotal: Badges.ALL.length,
                onOpenBadges: () => {
                  this.showBadges = true;
                },
                theme: this.theme
              })

              /* ============ 扇形统计图 ============ */
              ChartCard({
                dataAmount: this.chartAmount,
                dataCount: this.chartCount,
                theme: this.theme
              })
                .margin({ top: 12 })

              /* ============ 排序 + 收藏筛选（没有数据时不显示） ============ */
              if (this.deviceList.length > 0) {
                Row() {
                  /* 「排序」两个字连同右边的上下双箭头是一整块热区：点哪儿都是切换方向 */
                  Row() {
                    Text(this.t('sort_label'))
                      .fontSize(12)
                      .fontColor(this.theme.sub)
                      .margin({ right: 2 })
                    /* 正序 / 倒序：两个实心小三角，当前方向的那一个点亮。
                       整组在切换时会绕 X 轴翻半圈，两个三角转着交接 */
                    Column() {
                      Polygon({ width: 10, height: 6 })
                        .points([[0, 6], [5, 0], [10, 6]])
                        .fill(this.arrowOn(true) ? this.theme.primary : this.theme.sub)
                        .strokeWidth(1.4)
                        .stroke(this.arrowOn(true) ? this.theme.primary : this.theme.sub)
                        .strokeLineJoin(LineJoinStyle.Round)
                        .opacity(this.arrowOn(true) ? 1 : 0.45)
                      Polygon({ width: 10, height: 6 })
                        .points([[0, 0], [5, 6], [10, 0]])
                        .fill(this.arrowOn(false) ? this.theme.primary : this.theme.sub)
                        .strokeWidth(1.4)
                        .stroke(this.arrowOn(false) ? this.theme.primary : this.theme.sub)
                        .strokeLineJoin(LineJoinStyle.Round)
                        .opacity(this.arrowOn(false) ? 1 : 0.45)
                        .margin({ top: 2 })
                    }
                    .alignItems(HorizontalAlign.Center)
                    // 翻转量只在 toggleSortDir 的 animateTo（260ms Friction）里推进；
                    // perspective 给一点透视，转的过程中才有"从平面里立起来"的厚度
                    .rotate({
                      x: 1, y: 0, z: 0,
                      angle: this.sortFlip,
                      centerX: '50%', centerY: '50%',
                      perspective: 240
                    })
                  }
                  .alignItems(VerticalAlign.Center)
                  // 左右各留 6 的内边距，再用 -6 的外边距顶回去：字的位置不动，热区变大
                  .padding({ left: 6, right: 6, top: 5, bottom: 5 })
                  .margin({ left: -6, right: 4 })
                  .borderRadius(8)
                  .focusable(false)
                  .scale({ x: this.sc('sortDir'), y: this.sc('sortDir') })
                  // 这条 .animation 只管按下的缩放回弹。箭头的配色不写在它"之上"，
                  // 因此不受它影响，交给 toggleSortDir 里的 animateTo（260ms Friction）——
                  // 同一个属性同时挂 .animation 和 animateTo，官方没有定义优先级，表现不可靠
                  .animation({ duration: 140, curve: Curve.EaseOut })
                  .onTouch((e: TouchEvent) => {
                    this.onPress(e, 'sortDir');
                  })
                  .onClick(() => {
                    this.toggleSortDir();
                  })
                  // 胶囊多了会超出一屏，这里让整行可以横向滑动，"排序"两个字固定不动
                  Scroll(this.chipScroller) {
                    Row() {
                      Text(this.statFav > 0 ? this.t('sort_fav_count', this.statFav) : this.t('sort_fav'))
                        .fontSize(12)
                        .fontColor(this.favOnly ? Color.White : this.theme.gold)
                        .backgroundColor(this.favOnly ? this.theme.gold : this.theme.chipBg)
                        .borderRadius(13)
                        .padding({ left: 11, right: 11, top: 5, bottom: 5 })
                        .margin({ left: 7 })
                        .focusable(false)
                        .scale({ x: this.sc('favOnly'), y: this.sc('favOnly') })
                        .animation({ duration: 140, curve: Curve.EaseOut })
                        // 立体转动写在 .animation 之后：它管不着这两项，
                        // 于是每帧都直接落到终值，手指拨到哪儿胶囊就转到哪儿，不带惯性尾巴
                        .rotate({
                          y: 1, z: 0,
                          angle: this.chipFx('fav').rot,
                          centerX: '50%', centerY: '50%',
                          perspective: 300
                        })
                        .opacity(this.chipFx('fav').alpha)
                        .onAreaChange((_o: Area, n: Area) => {
                          this.recordChipGeo('fav', n);
                        })
                        .onTouch((e: TouchEvent) => {
                          this.onPress(e, 'favOnly');
                        })
                        .onClick(() => {
                          this.setFavOnly(!this.favOnly);
                        })
                      ForEach(this.sortOptions(), (opt: SortOption) => {
                        Text(opt.label)
                          .fontSize(12)
                          .fontColor(opt.selected ? this.theme.onPrimary : this.theme.chipText)
                          .backgroundColor(opt.selected ? this.theme.primary : this.theme.chipBg)
                          .borderRadius(13)
                          .padding({ left: 11, right: 11, top: 5, bottom: 5 })
                          .margin({ left: 7 })
                          .focusable(false)
                          .scale({ x: this.sc('sort:' + opt.type), y: this.sc('sort:' + opt.type) })
                          .animation({ duration: 140, curve: Curve.EaseOut })
                          // 和收藏胶囊同一套：转角由它离这一行中心多远决定，
                          // 拨到左右边缘就顺着透视转到后头去了
                          .rotate({
                            y: 1, z: 0,
                            angle: this.chipFx('sort:' + opt.type).rot,
                            centerX: '50%', centerY: '50%',
                            perspective: 300
                          })
                          .opacity(this.chipFx('sort:' + opt.type).alpha)
                          .onAreaChange((_o: Area, n: Area) => {
                            this.recordChipGeo('sort:' + opt.type, n);
                          })
                          .onTouch((e: TouchEvent) => {
                            this.onPress(e, 'sort:' + opt.type);
                          })
                          .onClick(() => {
                            if (this.sortType === opt.type) {
                              // 点的就是当前这一项：翻方向，不改变排序字段
                              this.toggleSortDir();
                            } else {
                              animateTo({ duration: 260, curve: Curve.Friction }, () => {
                                this.sortType = opt.type;
                              });
                            }
                          })
                      }, (opt: SortOption) => this.langVersion + '|' + opt.key)
                    }
                    .alignItems(VerticalAlign.Center)
                    .onAreaChange((_o: Area, n: Area) => {
                      // 行首的全局横坐标：每个胶囊的静态位置都以它为起点
                      this.chipRowX = this.lenOf(n.globalPosition.x);
                      this.chipRowW = this.lenOf(n.width);
                      this.chipRowReady = true;
                      this.refreshChipFx();
                    })
                  }
                  .scrollable(ScrollDirection.Horizontal)
                  .scrollBar(BarState.Off)
                  .edgeEffect(EdgeEffect.Spring)
                  .layoutWeight(1)
                  .align(Alignment.Start)
                  .onAreaChange((_o: Area, n: Area) => {
                    this.chipViewW = this.lenOf(n.width);
                    this.refreshChipFx();
                  })
                  .onDidScroll(() => {
                    // 横向滚动一寸就重算一次：谁在中间谁就正面朝人，两侧的顺着透视转开
                    this.chipScrollX = this.chipScroller.currentOffset().xOffset;
                    this.refreshChipFx();
                  })
                }
                .width('100%')
                .padding({ top: 14, bottom: 10 })
                .alignItems(VerticalAlign.Center)
              }
            }
            .width('100%')
          }

          /* ============ 列表 / 空态 ============ */
          if (this.sortedList().length === 0) {
            ListItem() {
              Column() {
                Image($r('app.media.ic_empty'))
                  .width(120)
                  .height(120)
                  .objectFit(ImageFit.Contain)
                  .translate({ y: this.bob ? -8 : 0 })
                  .animation({ duration: 1500, curve: Curve.EaseInOut, iterations: -1, playMode: PlayMode.Alternate })
                Text(this.favOnly ? this.t('empty_fav_title') : this.t('empty_all_title'))
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.theme.text)
                  .margin({ top: 10 })
                Text(this.favOnly ? this.t('empty_fav_desc1') : this.t('empty_all_desc1'))
                  .fontSize(13)
                  .fontColor(this.theme.sub)
                  .margin({ top: 8 })
                Text(this.favOnly ? this.t('empty_fav_desc2') : this.t('empty_all_desc2'))
                  .fontSize(13)
                  .fontColor(this.theme.sub)
                  .margin({ top: 2 })
                Button(this.favOnly ? this.t('empty_fav_action') : this.t('empty_all_action'))
                  .fontSize(15)
                  .fontColor(Color.White)
                  .backgroundColor(this.theme.primary)
                  .borderRadius(20)
                  .height(42)
                  .padding({ left: 26, right: 26 })
                  .margin({ top: 18 })
                  .stateEffect(false)
                  .focusable(false)
                  .scale({ x: this.sc('emptyAdd'), y: this.sc('emptyAdd') })
                  .animation({ duration: 140, curve: Curve.EaseOut })
                  .onTouch((e: TouchEvent) => {
                    this.onPress(e, 'emptyAdd');
                  })
                  .onClick(() => {
                    if (this.favOnly) {
                      this.setFavOnly(false);
                    } else {
                      this.openEditor(undefined);
                    }
                  })
              }
              .width('100%')
              .height(330)
              .justifyContent(FlexAlign.Center)
            }
          } else {
            ForEach(this.sortedList(), (item: DeviceItem, index: number) => {
              ListItem() {
                DeviceCard({
                  deviceId: item.id,
                  name: item.name,
                  price: item.price,
                  days: DeviceCalc.daysUsed(item),
                  avg: DeviceCalc.avgPerDay(item),
                  buyDate: item.buyDate,
                  kindKey: item.category,
                  note: item.note,
                  index: index,
                  favorite: item.favorite,
                  theme: this.theme,
                  onStar: (id: string) => {
                    this.toggleFavorite(id);
                  }
                })
              }
              .borderRadius(18)
              // 关闭系统焦点框：API 12+ 带 onClick 的组件默认可获焦，点击会画出蓝色边框
              .focusable(false)
              .swipeAction({
                end: {
                  builder: () => {
                    this.deleteSwipe(item.id);
                  }
                }
              })
              .onClick(() => {
                this.openEditor(item);
              })
            }, (item: DeviceItem) => this.langVersion + '|' + DeviceCalc.key(item))
          }

          /* ============ 页脚：作者的 GitHub ============ */
          /* 整页最后一项，空列表时也在（安卓端是 NestedScrollView 里最后一个 TextView）。
             文字走 this.t() 所以跟着语言刷；URL 是常量，不进文案表。 */
          ListItem() {
            Text(this.t('footer_github', GITHUB_URL))
              .fontSize(12)
              .fontColor(this.theme.primary)
              .textAlign(TextAlign.Center)
              .width('100%')
              .padding({ top: 10, bottom: 10 })
              .focusable(false)
              .onClick(() => {
                this.openGitHub();
              })
          }
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16, bottom: 20 })
        .edgeEffect(EdgeEffect.Spring)
        .scrollBar(BarState.Off)
        .onDidScroll(() => {
          // List 的滚动回调给的是"这一次的增量偏移"，不是当前滚到哪了。
          // 绝对位置必须直接从控制器上读，否则「滚过 320」这种判断永远不成立。
          this.onListScroll(this.scroller.currentOffset().yOffset);
        })
      }
      .width('100%')
      .height('100%')
      .linearGradient({
        angle: 180,
        colors: [[this.theme.bgTop, 0.0], [this.theme.bg, 0.28], [this.theme.bg, 1.0]]
      })

      /* ============ 置顶迷你汇总条 ============ */
      /* 向下滚动到大卡片滑出屏幕后，这一小行固定钉在最上方：总价 / 台数 / 日均 */
      if (this.stickyOn) {
        Column() {
          Row() {
            Text(this.money(this.statTotal))
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme.text)
            Column()
              .width(1)
              .height(13)
              .backgroundColor(this.theme.line)
              .margin({ left: 11, right: 11 })
            Text(this.qt('p_sticky_count', this.statCount, this.statCount))
              .fontSize(12)
              .fontColor(this.theme.sub)
            Column()
              .width(1)
              .height(13)
              .backgroundColor(this.theme.line)
              .margin({ left: 11, right: 11 })
            Text(this.t('sticky_avg', this.smallMoney(this.statAvg)))
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme.accent)
          }
          .width('100%')
          .padding({ left: 14, right: 14, top: 9, bottom: 9 })
          .backgroundColor(this.theme.card)
          .borderRadius(14)
          .shadow({ radius: 10, color: this.theme.dark ? '#40000000' : '#12000000', offsetX: 0, offsetY: 2 })
          // 点这一条也能直接回到顶部（和右下角圆钮同一个动作）
          .focusable(false)
          .scale({ x: this.sc('sticky'), y: this.sc('sticky') })
          .animation({ duration: 140, curve: Curve.EaseOut })
          .onTouch((e: TouchEvent) => {
            this.onPress(e, 'sticky');
          })
          .onClick(() => {
            this.scrollToTop();
          })
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .linearGradient({ angle: 180, colors: [[this.theme.bgTop, 0.0], [this.theme.bg, 1.0]] })
        // 出现 / 消失都作用在这一整层上（连背后的渐变一起淡），不再只动里头那张卡。
        // 早先把过渡挂在卡片上，外面这层深色渐变是硬切出来 / 硬切收回的，
        // 滑回顶部时会先留一帧深色的横条再消失，看着像闪过一道黑框
        .transition(
          TransitionEffect.OPACITY
            .animation({ duration: 240, curve: Curve.EaseOut })
        )
      }

      /* ============ 回顶部圆钮 ============ */
      /* 滚过 320vp 才浮出来：先弹到 1.12 倍再回落；点一下按距离自适应地快速滚回顶部 */
      if (this.showTop) {
        Column() {
          Stack() {
            // 点击时向四周扩出去的一圈光晕：从圆钮那么大扩到两倍、同时褪掉。
            // 这里千万不能裁剪，否则扩出圆钮边界的那截会被切一刀
            Circle({ width: 46, height: 46 })
              .fill(this.theme.primary)
              .opacity(this.topRingAlpha)
              .scale({ x: this.topRingScale, y: this.topRingScale })
              .zIndex(0)
            Image($r('app.media.ic_top'))
              .width(20)
              .height(20)
              .objectFit(ImageFit.Contain)
              .opacity(this.topIconAlpha)
              .translate({ y: this.topIconY })
              .zIndex(1)
          }
          .width(46)
          .height(46)
          .borderRadius(23)
          .backgroundColor(this.theme.primary)
          .shadow({ radius: 14, color: this.theme.dark ? '#66000000' : '#332B5CFF', offsetX: 0, offsetY: 6 })
          .focusable(false)
          .opacity(this.topAlpha)
          .scale({ x: this.topScale, y: this.topScale })
          .onTouch((e: TouchEvent) => {
            this.onTopPress(e);
          })
          .onClick(() => {
            this.launchTopAction();
          })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.End)
        .alignItems(HorizontalAlign.End)
        .padding({ right: 18, bottom: 26 })
        // 空白区域要能穿透到下面的列表，不然整页都滑不动了
        .hitTestBehavior(HitTestMode.Transparent)
      }

      /* ============ 编辑面板 ============ */
      if (this.showEditor) {
        Column() {
          Column()
            .width('100%')
            .layoutWeight(1)
            .focusable(false)
            .onClick(() => {
              this.closeEditor();
            })

          Column() {
            Row() {
              Text(this.editId.length > 0 ? this.t('editor_title_edit') : this.t('editor_title_add'))
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.theme.text)
                .layoutWeight(1)
              Text(this.t('editor_close'))
                .fontSize(14)
                .fontColor(this.theme.sub)
                .focusable(false)
                .scale({ x: this.sc('close'), y: this.sc('close') })
                .animation({ duration: 140, curve: Curve.EaseOut })
                .onTouch((e: TouchEvent) => {
                  this.onPress(e, 'close');
                })
                .onClick(() => {
                  this.closeEditor();
                })
            }
            .width('100%')
            .padding({ left: 20, right: 20, top: 16, bottom: 8 })
            .alignItems(VerticalAlign.Center)

            Scroll() {
              Column() {
                Text(this.t('editor_name_label'))
                  .fontSize(12)
                  .fontColor(this.theme.sub)
                  .width('100%')
                  .margin({ bottom: 6 })
                TextInput({ placeholder: this.t('editor_name_hint'), text: this.editName })
                  .fontSize(15)
                  .height(46)
                  .fontColor(this.theme.text)
                  .placeholderColor(this.theme.sub)
                  .caretColor(this.theme.primary)
                  .backgroundColor(this.theme.field)
                  .borderRadius(12)
                  .onChange((value: string) => {
                    this.editName = value;
                  })

                Text(this.t('editor_price_label', this.t('fmt_currency')))
                  .fontSize(12)
                  .fontColor(this.theme.sub)
                  .width('100%')
                  .margin({ top: 16, bottom: 6 })
                TextInput({ placeholder: '0.00', text: this.editPrice })
                  .type(InputType.NUMBER_DECIMAL)
                  .fontSize(15)
                  .height(46)
                  .fontColor(this.theme.text)
                  .placeholderColor(this.theme.sub)
                  .caretColor(this.theme.primary)
                  .backgroundColor(this.theme.field)
                  .borderRadius(12)
                  .onChange((value: string) => {
                    this.editPrice = value;
                  })

                Text(this.t('editor_kind_label'))
                  .fontSize(12)
                  .fontColor(this.theme.sub)
                  .width('100%')
                  .margin({ top: 16, bottom: 8 })
                // 默认只铺一行，点下面的"展开全部"再全放出来：高度做 260ms 拉伸，格子被裁着一层层露出
                Column() {
                  Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
                    ForEach(this.visibleKindTiles(), (tile: KindTile) => {
                      Column() {
                        Image(kindIcon(tile.key))
                          .width(32)
                          .height(32)
                          .objectFit(ImageFit.Contain)
                        Text(tile.label)
                          .fontSize(10)
                          // 英文名（Smart speaker / Drawing tablet / Fitness band）一行装不下：
                          // 与安卓 item_kind.xml 同规则 —— 两行 + 8~10fp 之间缩放 + 固定 24vp 高。
                          // 格子总高不变（32 图标 + 2 + 24 = 58 ≤ 60），只是不再把尾巴裁掉。
                          // （这个 SDK 的 Text 没有 adaptiveTextSize，min/maxFontSize 就是那套自动缩放）
                          .minFontSize(8)
                          .maxFontSize(10)
                          .fontColor(tile.selected ? this.theme.primary : this.theme.chipText)
                          .maxLines(2)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                          .height(24)
                          .textAlign(TextAlign.Center)
                          .margin({ top: 2 })
                      }
                      .width(60)
                      .height(60)
                      .justifyContent(FlexAlign.Center)
                      .borderRadius(13)
                      .backgroundColor(tile.selected ? this.theme.primarySoft : this.theme.card2)
                      .border({
                        width: tile.selected ? 1.5 : 0,
                        color: tile.selected ? this.theme.primary : this.theme.line
                      })
                      .margin({ right: 6, bottom: 6 })
                      .focusable(false)
                      .scale({ x: this.sc('kind:' + tile.key), y: this.sc('kind:' + tile.key) })
                      .animation({ duration: 140, curve: Curve.EaseOut })
                      .onTouch((e: TouchEvent) => {
                        this.onPress(e, 'kind:' + tile.key);
                      })
                      .onClick(() => {
                        animateTo({ duration: 200, curve: Curve.Friction }, () => {
                          this.editKind = tile.key;
                        });
                      })
                    }, (tile: KindTile) => this.langVersion + '|' + tile.rowKey)
                  }
                  .width('100%')
                }
                .width('100%')
                .height(this.kindGridH)
                .clip(true)
                .onAreaChange((oldArea: Area, newArea: Area) => {
                  this.onKindArea(newArea.width);
                })

                if (this.needKindToggle()) {
                  Row() {
                    Text(this.kindExpanded ? this.t('editor_kind_collapse') : this.t('editor_kind_expand', DEVICE_KINDS.length))
                      .fontSize(12)
                      .fontColor(this.theme.primary)
                    Text('▲')
                      .fontSize(9)
                      .fontColor(this.theme.primary)
                      .margin({ left: 5 })
                      .rotate({ z: 1, angle: this.kindExpanded ? 0 : 180 })
                  }
                  .width('100%')
                  .padding({ top: 4, bottom: 2 })
                  .justifyContent(FlexAlign.Center)
                  .focusable(false)
                  .scale({ x: this.sc('kindToggle'), y: this.sc('kindToggle') })
                  .animation({ duration: 140, curve: Curve.EaseOut })
                  .onTouch((e: TouchEvent) => {
                    this.onPress(e, 'kindToggle');
                  })
                  .onClick(() => {
                    this.toggleKindExpand();
                  })
                }

                Text(this.t('editor_date_label'))
                  .fontSize(12)
                  .fontColor(this.theme.sub)
                  .width('100%')
                  .margin({ top: 10, bottom: 6 })
                CalendarPicker({ hintRadius: 12, selected: this.editDate })
                  .width('100%')
                  .height(52)
                  .edgeAlign(CalendarAlign.END)
                  .borderRadius(12)
                  .borderColor(this.theme.line)
                  .textStyle({ color: this.theme.text, font: { size: 15, weight: FontWeight.Medium } })
                  .onChange((value: Date) => {
                    this.editDate = value;
                  })

                Text(this.t('editor_note_label'))
                  .fontSize(12)
                  .fontColor(this.theme.sub)
                  .width('100%')
                  .margin({ top: 16, bottom: 6 })
                TextArea({ placeholder: this.t('editor_note_hint'), text: this.editNote })
                  .fontSize(14)
                  .height(72)
                  .fontColor(this.theme.text)
                  .placeholderColor(this.theme.sub)
                  .caretColor(this.theme.primary)
                  .backgroundColor(this.theme.field)
                  .borderRadius(12)
                  .onChange((value: string) => {
                    this.editNote = value;
                  })

                Row() {
                  Text(this.t('editor_fav_label'))
                    .fontSize(14)
                    .fontColor(this.theme.text)
                    .layoutWeight(1)
                  Text(this.editFavorite ? this.t('editor_fav_on') : this.t('editor_fav_off'))
                    .fontSize(12)
                    .fontColor(this.editFavorite ? this.theme.gold : this.theme.sub)
                    .margin({ right: 6 })
                  Image(this.editFavorite ? $r('app.media.ic_star') : $r('app.media.ic_star_off'))
                    .width(22)
                    .height(22)
                    .objectFit(ImageFit.Contain)
                }
                .width('100%')
                .height(50)
                .margin({ top: 16 })
                .padding({ left: 14, right: 14 })
                .backgroundColor(this.theme.field)
                .borderRadius(12)
                .focusable(false)
                .scale({ x: this.sc('favSwitch'), y: this.sc('favSwitch') })
                .animation({ duration: 140, curve: Curve.EaseOut })
                .onTouch((e: TouchEvent) => {
                  this.onPress(e, 'favSwitch');
                })
                .onClick(() => {
                  animateTo({ duration: 220, curve: Curve.Friction }, () => {
                    this.editFavorite = !this.editFavorite;
                  });
                })
                Column()
                  .height(10)
              }
              .width('100%')
              .padding({ left: 20, right: 20 })
              .alignItems(HorizontalAlign.Start)
            }
            .layoutWeight(1)
            .scrollBar(BarState.Off)
            .align(Alignment.Top)

            if (this.errMsg.length > 0) {
              Text(this.errMsg)
                .fontSize(12)
                .fontColor(this.theme.danger)
                .width('100%')
                .padding({ left: 20, right: 20, top: 6 })
            }

            Row() {
              Button(this.t('editor_cancel'))
                .fontSize(15)
                .fontColor(this.theme.chipText)
                .backgroundColor(this.theme.field)
                .borderRadius(12)
                .height(46)
                .layoutWeight(1)
                .stateEffect(false)
                .focusable(false)
                .scale({ x: this.sc('cancel'), y: this.sc('cancel') })
                .animation({ duration: 140, curve: Curve.EaseOut })
                .onTouch((e: TouchEvent) => {
                  this.onPress(e, 'cancel');
                })
                .onClick(() => {
                  this.closeEditor();
                })
              Button(this.t('editor_save'))
                .fontSize(15)
                .fontColor(Color.White)
                .backgroundColor(this.theme.primary)
                .borderRadius(12)
                .height(46)
                .layoutWeight(1)
                .margin({ left: 12 })
                .stateEffect(false)
                .focusable(false)
                .scale({ x: this.sc('save'), y: this.sc('save') })
                .animation({ duration: 140, curve: Curve.EaseOut })
                .onTouch((e: TouchEvent) => {
                  this.onPress(e, 'save');
                })
                .onClick(() => {
                  this.onSave();
                })
            }
            .width('100%')
            .padding({ left: 20, right: 20, top: 10, bottom: 22 })
          }
          .width('100%')
          .height('82%')
          .backgroundColor(this.theme.card)
          .borderRadius({ topLeft: 24, topRight: 24 })
          .transition(TransitionEffect.move(TransitionEdge.BOTTOM).animation({ duration: 300, curve: Curve.EaseOut }))
        }
        .width('100%')
        .height('100%')
        .backgroundColor(this.theme.scrim)
        .transition(TransitionEffect.OPACITY.animation({ duration: 220 }))
      }

      /* ============ 删除确认 ============ */
      if (this.pendingDeleteId.length > 0) {
        Column() {
          Column()
            .width('100%')
            .layoutWeight(1)
            .focusable(false)
            .onClick(() => {
              this.closeDeleteConfirm();
            })

          Column() {
            Text(this.t('delete_title'))
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme.text)
            Text(this.deleteName())
              .fontSize(14)
              .fontColor(this.theme.sub)
              .margin({ top: 8 })

            Row() {
              Button(this.t('delete_cancel'))
                .fontSize(15)
                .fontColor(this.theme.chipText)
                .backgroundColor(this.theme.field)
                .borderRadius(12)
                .height(44)
                .layoutWeight(1)
                .stateEffect(false)
                .focusable(false)
                .scale({ x: this.sc('delCancel'), y: this.sc('delCancel') })
                .animation({ duration: 140, curve: Curve.EaseOut })
                .onTouch((e: TouchEvent) => {
                  this.onPress(e, 'delCancel');
                })
                .onClick(() => {
                  this.closeDeleteConfirm();
                })
              Button(this.t('delete_confirm'))
                .fontSize(15)
                .fontColor(Color.White)
                .backgroundColor(this.theme.danger)
                .borderRadius(12)
                .height(44)
                .layoutWeight(1)
                .margin({ left: 12 })
                .stateEffect(false)
                .focusable(false)
                .scale({ x: this.sc('delOk'), y: this.sc('delOk') })
                .animation({ duration: 140, curve: Curve.EaseOut })
                .onTouch((e: TouchEvent) => {
                  this.onPress(e, 'delOk');
                })
                .onClick(() => {
                  this.confirmDelete();
                })
            }
            .width('100%')
            .margin({ top: 20 })
          }
          .width('80%')
          .padding(20)
          .backgroundColor(this.theme.card)
          .borderRadius(18)

          Column()
            .width('100%')
            .layoutWeight(1)
            .focusable(false)
            .onClick(() => {
              this.closeDeleteConfirm();
            })
        }
        .width('100%')
        .height('100%')
        .backgroundColor(this.theme.scrim)
        .transition(TransitionEffect.OPACITY.animation({ duration: 200 }))
      }

      /* ============ 清空回收站的二次确认 ============ */
      if (this.pendingClearTrash) {
        Column() {
          Column()
            .width('100%')
            .layoutWeight(1)
            .focusable(false)
            .onClick(() => {
              this.pendingClearTrash = false;
            })

          Column() {
            Text(this.t('clear_trash_title'))
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme.text)
            Text(this.t('clear_trash_message', this.trashList.length))
              .fontSize(14)
              .fontColor(this.theme.sub)
              .margin({ top: 8 })

            Row() {
              Button(this.t('common_cancel'))
                .fontSize(15)
                .fontColor(this.theme.chipText)
                .backgroundColor(this.theme.field)
                .borderRadius(12)
                .height(44)
                .layoutWeight(1)
                .stateEffect(false)
                .focusable(false)
                .scale({ x: this.sc('clrCancel'), y: this.sc('clrCancel') })
                .animation({ duration: 140, curve: Curve.EaseOut })
                .onTouch((e: TouchEvent) => {
                  this.onPress(e, 'clrCancel');
                })
                .onClick(() => {
                  this.pendingClearTrash = false;
                })
              Button(this.t('clear_trash_confirm'))
                .fontSize(15)
                .fontColor(Color.White)
                .backgroundColor(this.theme.danger)
                .borderRadius(12)
                .height(44)
                .layoutWeight(1)
                .margin({ left: 12 })
                .stateEffect(false)
                .focusable(false)
                .scale({ x: this.sc('clrOk'), y: this.sc('clrOk') })
                .animation({ duration: 140, curve: Curve.EaseOut })
                .onTouch((e: TouchEvent) => {
                  this.onPress(e, 'clrOk');
                })
                .onClick(() => {
                  this.confirmClearTrash();
                })
            }
            .width('100%')
            .margin({ top: 20 })
          }
          .width('80%')
          .padding(20)
          .backgroundColor(this.theme.card)
          .borderRadius(18)

          Column()
            .width('100%')
            .layoutWeight(1)
            .focusable(false)
            .onClick(() => {
              this.pendingClearTrash = false;
            })
        }
        .width('100%')
        .height('100%')
        .backgroundColor(this.theme.scrim)
        .transition(TransitionEffect.OPACITY.animation({ duration: 200 }))
      }

      if (this.showPrivacy) {
        PrivacyDialog({
          theme: this.theme,
          onAgree: () => {
            DeviceStore.saveAgreed(true);
            this.showPrivacy = false;
            this.deviceList = DeviceStore.load();
            this.trashList = DeviceStore.loadTrash(BackupStore.KEEP_DAYS);
            this.badgeState = DeviceStore.loadBadges();
            this.refreshStats();
            this.checkBadges(false);
          },
          onExit: () => {
            try {
              const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
              ctx.terminateSelf();
            } catch (e) {
              // 结束不掉就留在确认页，不做别的处理
            }
          }
        })
      }

      /* ============ 数据与备份 ============ */
      if (this.showDataSheet) {
        DataSheet({
          theme: this.theme,
          deviceCount: this.deviceList.length,
          recycleCount: this.trashList.length,
          badgeCount: this.badgeUnlockedCount(),
          badgeTotal: Badges.ALL.length,
          backups: this.backups,
          languageTag: I18n.preferred(),
          onExport: () => {
            this.exportData();
          },
          onImport: () => {
            this.importData();
          },
          onRestoreBackup: (slot: number) => {
            this.restoreBackup(slot);
          },
          onOpenTrash: () => {
            this.showDataSheet = false;
            this.showTrash = true;
          },
          onOpenBadges: () => {
            this.showDataSheet = false;
            this.showBadges = true;
          },
          onPickLanguage: (tag: string) => {
            this.pickLanguage(tag);
          },
          onClose: () => {
            this.showDataSheet = false;
          }
        })
      }

      /* ============ 回收站 ============ */
      if (this.showTrash) {
        TrashSheet({
          theme: this.theme,
          items: this.trashList,
          keepDays: BackupStore.KEEP_DAYS,
          onRestore: (id: string) => {
            this.restoreFromTrash(id);
          },
          onDeleteForever: (id: string) => {
            this.deleteForever(id);
          },
          onClear: () => {
            this.askClearTrash();
          },
          onClose: () => {
            this.showTrash = false;
          }
        })
      }

      /* ============ 勋章墙 ============ */
      if (this.showBadges) {
        BadgeWall({
          theme: this.theme,
          cells: this.badgeCellList,
          onClose: () => {
            this.showBadges = false;
          }
        })
      }

      /* ============ 删除后的撤销条 ============ */
      if (this.showUndo) {
        UndoBar({
          theme: this.theme,
          text: this.undoText,
          onUndo: () => {
            this.undoDelete();
          },
          onExpire: () => {
            this.showUndo = false;
            this.undoTrash = undefined;
          }
        })
      }

      /* ============ 勋章达成弹屏：压在所有层之上 ============ */
      if (this.showCelebration) {
        BadgeCelebration({
          theme: this.theme,
          items: this.celebrationItems,
          onClose: () => {
            this.showCelebration = false;
            this.celebrationItems = [];
          }
        })
      }
    }
    .width('100%')
    .height('100%')
  }

  /* ============ 滑动删除按钮 ============ */
  @Builder
  deleteSwipe(id: string) {
    Row() {
      Text(this.t('swipe_delete'))
        .fontSize(14)
        .fontColor(Color.White)
    }
    .width(76)
    .height('100%')
    .backgroundColor(this.theme.danger)
    .justifyContent(FlexAlign.Center)
    .focusable(false)
    .scale({ x: this.sc('swipeDel'), y: this.sc('swipeDel') })
    .animation({ duration: 140, curve: Curve.EaseOut })
    .onTouch((e: TouchEvent) => {
      this.onPress(e, 'swipeDel');
    })
    .onClick(() => {
      this.pendingDeleteId = id;
    })
  }
}
