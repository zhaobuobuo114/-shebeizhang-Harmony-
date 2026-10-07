import { DeviceCalc, DeviceItem } from '../model/DeviceItem';
import { DEVICE_KINDS, kindIcon, kindLabel } from '../model/DeviceKind';
import { ChartData } from '../model/ChartData';
import { DeviceStore } from '../utils/DeviceStore';
import { DateUtil } from '../utils/DateUtil';
import { Fmt } from '../utils/Format';
import { AppTheme, LIGHT_THEME, themeOf } from '../utils/Theme';
import { applyColorMode } from '../utils/SystemUi';
import { common } from '@kit.AbilityKit';
import { SummaryCard } from '../components/SummaryCard';
import { ChartCard } from '../components/ChartCard';
import { DeviceCard } from '../components/DeviceCard';

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

@Entry
@Component
struct Index {
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

  // 空态图标的呼吸动画
  @State bob: boolean = false;

  // 向下滚动后是否钉住顶部那一小行汇总
  @State stickyOn: boolean = false;

  // 回顶部圆钮
  @State showTop: boolean = false;
  @State topScale: number = 1;
  @State topAlpha: number = 0;

  // 按压动效：记录当前被按下的控件标识
  @State pressedKey: string = '';

  private todayStr: string = DateUtil.today();
  /** 整页列表的滚动控制器，回顶部要用 */
  private scroller: Scroller = new Scroller();
  /** 当前滚动位置（用于算回顶部的时长） */
  private scrollOffset: number = 0;
  /** 回顶部圆钮的逻辑状态（不参与渲染，只用来防抖） */
  private topShown: boolean = false;
  private topTimer: number = -1;

  /* ------------------------------ 生命周期 ------------------------------ */

  aboutToAppear(): void {
    this.theme = themeOf(DeviceStore.loadDark());
    this.deviceList = DeviceStore.load();
    this.refreshStats();
    setTimeout(() => {
      this.bob = true;
    }, 400);
  }

  onPageShow(): void {
    // 回到前台时对齐一次磁盘数据（跨天时天数也会重算）
    const disk: DeviceItem[] = DeviceStore.load();
    if (disk.length !== this.deviceList.length) {
      this.deviceList = disk;
    }
    this.refreshStats();
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
    let list: DeviceItem[] = this.deviceList.slice();
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
        label: asc ? '日均最低' : '日均最高',
        type: 'avg',
        selected: this.sortType === 'avg',
        key: ''
      },
      {
        label: asc ? '价格最低' : '价格最高',
        type: 'price',
        selected: this.sortType === 'price',
        key: ''
      },
      {
        label: asc ? '最早购买' : '最近购买',
        type: 'date',
        selected: this.sortType === 'date',
        key: ''
      },
      {
        label: asc ? '用最短' : '用最久',
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

  /** 切换排序方向（点箭头，或点当前已选中的那个排序胶囊） */
  private toggleSortDir(): void {
    animateTo({ duration: 260, curve: Curve.Friction }, () => {
      this.sortAsc = !this.sortAsc;
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
        label: DEVICE_KINDS[i].label,
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

  private openEditor(item: DeviceItem | undefined): void {
    this.errMsg = '';
    if (item === undefined) {
      this.editId = '';
      this.editName = '';
      this.editPrice = '';
      this.editKind = 'phone';
      this.editNote = '';
      this.editFavorite = false;
      this.editDate = new Date();
    } else {
      this.editId = item.id;
      this.editName = item.name;
      this.editPrice = item.price.toString();
      this.editKind = item.category;
      this.editNote = item.note;
      this.editFavorite = item.favorite;
      this.editDate = DateUtil.parse(item.buyDate);
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

  private onSave(): void {
    const name: string = this.editName.trim();
    const price: number = parseFloat(this.editPrice);
    const buyDate: string = DateUtil.format(
      this.editDate.getFullYear(), this.editDate.getMonth() + 1, this.editDate.getDate());

    if (name.length === 0) {
      this.errMsg = '请填写设备名称';
      return;
    }
    if (this.editPrice.trim().length === 0) {
      this.errMsg = '请填写购买价格';
      return;
    }
    if (!(price > 0)) {
      this.errMsg = '请填写有效的购买价格';
      return;
    }
    if (buyDate > this.todayStr) {
      this.errMsg = '购买日期不能晚于今天';
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

    this.deviceList = list;
    DeviceStore.save(list);
    this.refreshStats();
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

  private confirmDelete(): void {
    const id: string = this.pendingDeleteId;
    if (id.length === 0) {
      return;
    }
    const list: DeviceItem[] = [];
    for (let i: number = 0; i < this.deviceList.length; i++) {
      if (this.deviceList[i].id !== id) {
        list.push(this.deviceList[i]);
      }
    }
    this.deviceList = list;
    DeviceStore.save(list);
    this.refreshStats();
    animateTo({ duration: 200, curve: Curve.EaseIn }, () => {
      this.pendingDeleteId = '';
    });
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
                  Text('设备账')
                    .fontSize(24)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.theme.text)
                  Text('买了多久 · 花了多少 · 每天多少钱')
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

                Button('＋ 记一笔')
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
                  Text('排序')
                    .fontSize(12)
                    .fontColor(this.theme.sub)
                    .margin({ right: 2 })
                  /* 正序 / 倒序：上下两个箭头，当前方向的那一个点亮 */
                  Column() {
                    Text('▲')
                      .fontSize(9)
                      .fontColor(this.sortAsc ? this.theme.primary : this.theme.sub)
                      .opacity(this.sortAsc ? 1 : 0.45)
                    Text('▼')
                      .fontSize(9)
                      .fontColor(this.sortAsc ? this.theme.sub : this.theme.primary)
                      .opacity(this.sortAsc ? 0.45 : 1)
                      .margin({ top: 2 })
                  }
                  .alignItems(HorizontalAlign.Center)
                  .padding({ left: 6, right: 6, top: 3, bottom: 3 })
                  .borderRadius(8)
                  .margin({ right: 4 })
                  .focusable(false)
                  .scale({ x: this.sc('sortDir'), y: this.sc('sortDir') })
                  .animation({ duration: 140, curve: Curve.EaseOut })
                  .onTouch((e: TouchEvent) => {
                    this.onPress(e, 'sortDir');
                  })
                  .onClick(() => {
                    this.toggleSortDir();
                  })
                  // 胶囊多了会超出一屏，这里让整行可以横向滑动，"排序"两个字固定不动
                  Scroll() {
                    Row() {
                      Text(this.statFav > 0 ? ('★ 收藏 ' + this.statFav) : '★ 收藏')
                        .fontSize(12)
                        .fontColor(this.favOnly ? Color.White : this.theme.gold)
                        .backgroundColor(this.favOnly ? this.theme.gold : this.theme.chipBg)
                        .borderRadius(13)
                        .padding({ left: 11, right: 11, top: 5, bottom: 5 })
                        .margin({ left: 7 })
                        .focusable(false)
                        .scale({ x: this.sc('favOnly'), y: this.sc('favOnly') })
                        .animation({ duration: 140, curve: Curve.EaseOut })
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
                      }, (opt: SortOption) => opt.key)
                    }
                    .alignItems(VerticalAlign.Center)
                  }
                  .scrollable(ScrollDirection.Horizontal)
                  .scrollBar(BarState.Off)
                  .edgeEffect(EdgeEffect.Spring)
                  .layoutWeight(1)
                  .align(Alignment.Start)
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
                Text(this.favOnly ? '还没有收藏的设备' : '还没有设备记录')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.theme.text)
                  .margin({ top: 10 })
                Text(this.favOnly ? '点设备卡片右下角的星标，' : '记下第一台设备的购买日期和价格，')
                  .fontSize(13)
                  .fontColor(this.theme.sub)
                  .margin({ top: 8 })
                Text(this.favOnly ? '把最爱的设备收进来。' : '它会告诉你这台设备每天花了多少钱。')
                  .fontSize(13)
                  .fontColor(this.theme.sub)
                  .margin({ top: 2 })
                Button(this.favOnly ? '看全部设备' : '添加设备')
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
            }, (item: DeviceItem) => DeviceCalc.key(item))
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
            Text('¥' + Fmt.money(this.statTotal))
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme.text)
            Column()
              .width(1)
              .height(13)
              .backgroundColor(this.theme.line)
              .margin({ left: 11, right: 11 })
            Text(this.statCount + ' 台')
              .fontSize(12)
              .fontColor(this.theme.sub)
            Column()
              .width(1)
              .height(13)
              .backgroundColor(this.theme.line)
              .margin({ left: 11, right: 11 })
            Text('日均 ¥' + Fmt.smallMoney(this.statAvg))
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
        .transition(
          TransitionEffect.OPACITY
            .combine(TransitionEffect.move(TransitionEdge.TOP))
            .animation({ duration: 240, curve: Curve.EaseOut })
        )
      }

      /* ============ 回顶部圆钮 ============ */
      /* 滚过 320vp 才浮出来：先弹到 1.12 倍再回落；点一下按距离自适应地快速滚回顶部 */
      if (this.showTop) {
        Column() {
          Stack() {
            Image($r('app.media.ic_top'))
              .width(20)
              .height(20)
              .objectFit(ImageFit.Contain)
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
            this.scrollToTop();
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
              Text(this.editId.length > 0 ? '编辑设备' : '添加设备')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.theme.text)
                .layoutWeight(1)
              Text('关闭')
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
                Text('设备名称')
                  .fontSize(12)
                  .fontColor(this.theme.sub)
                  .width('100%')
                  .margin({ bottom: 6 })
                TextInput({ placeholder: '例如：MacBook Pro 14', text: this.editName })
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

                Text('购买价格（元）')
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

                Text('设备类型')
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
                          .fontColor(tile.selected ? this.theme.primary : this.theme.chipText)
                          .maxLines(1)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
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
                    }, (tile: KindTile) => tile.rowKey)
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
                    Text(this.kindExpanded ? '收起' : ('展开全部 ' + DEVICE_KINDS.length + ' 类'))
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

                Text('购买日期')
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

                Text('备注（可选）')
                  .fontSize(12)
                  .fontColor(this.theme.sub)
                  .width('100%')
                  .margin({ top: 16, bottom: 6 })
                TextArea({ placeholder: '保修到什么时候、配件花了多少……', text: this.editNote })
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
                  Text('收藏为最爱')
                    .fontSize(14)
                    .fontColor(this.theme.text)
                    .layoutWeight(1)
                  Text(this.editFavorite ? '已收藏' : '未收藏')
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
              Button('取消')
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
              Button('保存')
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
              animateTo({ duration: 180, curve: Curve.EaseIn }, () => {
                this.pendingDeleteId = '';
              });
            })

          Column() {
            Text('确定删除这台设备？')
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme.text)
            Text(this.deleteName())
              .fontSize(14)
              .fontColor(this.theme.sub)
              .margin({ top: 8 })

            Row() {
              Button('取消')
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
                  animateTo({ duration: 180, curve: Curve.EaseIn }, () => {
                    this.pendingDeleteId = '';
                  });
                })
              Button('删除')
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
              animateTo({ duration: 180, curve: Curve.EaseIn }, () => {
                this.pendingDeleteId = '';
              });
            })
        }
        .width('100%')
        .height('100%')
        .backgroundColor(this.theme.scrim)
        .transition(TransitionEffect.OPACITY.animation({ duration: 200 }))
      }
    }
    .width('100%')
    .height('100%')
  }

  /* ============ 滑动删除按钮 ============ */
  @Builder
  deleteSwipe(id: string) {
    Row() {
      Text('删除')
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
