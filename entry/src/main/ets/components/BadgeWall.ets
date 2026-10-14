import { AppTheme, LIGHT_THEME } from '../utils/Theme';
import { Badges } from '../model/Badge';
import { I18n } from '../utils/I18n';

/** 墙上的一格：勋章本体 + 点亮状态（没点亮就是 0） */
export interface BadgeCell {
  id: string;
  name: string;
  desc: string;
  icon: Resource;
  at: number;
}

/**
 * 勋章墙：14 枚里程碑一字排开，点亮的是彩色，没拿到的是灰的并显示达成条件。
 *
 * 拿到过的永远亮着——即便之后数字回落（比如删了设备导致总投入下降）也不会熄灭，
 * 这一点和 QQ 的勋章墙一致。
 */
@Component
export struct BadgeWall {
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
  @Prop cells: BadgeCell[] = [];
  onClose: () => void = () => {
  };

  @State shown: boolean = false;

  private unlockedCount(): number {
    let n: number = 0;
    for (let i: number = 0; i < this.cells.length; i++) {
      if (this.cells[i].at > 0) {
        n += 1;
      }
    }
    return n;
  }

  aboutToAppear(): void {
    setTimeout(() => {
      this.shown = true;
    }, 20);
  }

  /**
   * 一格勋章。
   *
   * 宽度账：面板 92% 屏宽（360vp 屏约 331）- 内边距 36 = 295，三列两间距 20 → 每格 91.7，
   * 再减去格子左右各 6 的内边距 = 可用 79.7vp。
   * 按这个宽度实测主表里的英文名：Kind Collector / A Year Together / Three Year Club /
   * Well Provided 都有 13~15 字符，12fp 下约 84~90vp，**一行放不下**，
   * 原来 maxLines(1) 会把勋章名砍成 "Kind Collec…"。
   * 所以名称放宽到两行、条件说明放宽到三行（英文 "A device used for 1095 days"
   * 按词边界折行是 2 行，留一行余量给更长的译名）。
   * 格子本来就没有固定高度（Column 由内容撑开，Grid 行高取该行最高的一格），
   * 所以放宽行数只会让格子长高，不会裁字——整个 Grid 是可滚的。
   */
  @Builder
  private cellView(cell: BadgeCell) {
    Column() {
      // 专属插画自带圆盘、描边与丝带；没点亮的走灰度 + 压暗，
      // 与安卓端 ColorMatrix 去饱和 + alpha 0.35 同一套语义
      Image(cell.icon)
        .width(52)
        .height(52)
        .grayscale(cell.at > 0 ? 0 : 1)
        .opacity(cell.at > 0 ? 1 : 0.35)
      Text(cell.name)
        .fontSize(12)
        .fontWeight(cell.at > 0 ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(cell.at > 0 ? this.theme.text : this.theme.sub)
        .margin({ top: 6 })
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.Center)
        .wordBreak(WordBreak.BREAK_WORD)
      Text(cell.at > 0
        ? this.t('badge_unlocked_at', Badges.dateText(cell.at))
        : cell.desc)
        .fontSize(9.5)
        .fontColor(this.theme.sub)
        .margin({ top: 3 })
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.Center)
        .wordBreak(WordBreak.BREAK_WORD)
    }
    .width('100%')
    .padding({ left: 6, right: 6, top: 12, bottom: 12 })
    .backgroundColor(cell.at > 0 ? this.theme.primarySoft : this.theme.card2)
    .borderRadius(12)
    .border({
      width: cell.at > 0 ? 1 : 0,
      color: cell.at > 0 ? this.theme.primary : Color.Transparent
    })
  }

  build() {
    Column() {
      // 遮罩：点一下就关
      Column()
        .width('100%')
        .layoutWeight(1)
        .focusable(false)
        .onClick(() => {
          this.onClose();
        })

      Column() {
        Row() {
          Column() {
            Text(this.t('badge_wall_short'))
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme.text)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.t('badge_wall_subtitle'))
              .fontSize(11.5)
              .fontColor(this.theme.sub)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: 3 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Text(this.t('sum_badge_progress', this.unlockedCount(), this.cells.length))
            .fontSize(13)
            .fontColor(this.theme.primary)
            .maxLines(1)
            .margin({ left: 8 })
            .backgroundColor(this.theme.primarySoft)
            .borderRadius(10)
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Grid() {
          ForEach(this.cells, (cell: BadgeCell) => {
            GridItem() {
              this.cellView(cell);
            }
          }, (cell: BadgeCell) => this.langVersion + '|' + cell.id)
        }
        .columnsTemplate('1fr 1fr 1fr')
        .columnsGap(10)
        .rowsGap(10)
        .width('100%')
        // 必须占满剩余空间而不是"要多高就多高"：外层卡片是 maxHeight 78% 封顶的，
        // 以前这里没写 layoutWeight，Grid 就按 14 个格子自然撑到卡片外面，
        // 底部那行勋章直接压在圆角外面（"兜不住、勋章露出来"），关闭按钮也被顶没。
        // 给了权重之后卡片高度不变，Grid 自己出滚动条（Grid 默认可滚）。
        .layoutWeight(1)
        .margin({ top: 16 })

        Button(this.t('badge_wall_close'))
          .fontSize(15)
          .fontColor(this.theme.primary)
          .backgroundColor(this.theme.primarySoft)
          .borderRadius(12)
          .height(44)
          .width('100%')
          .margin({ top: 16 })
          .stateEffect(false)
          .focusable(false)
          .onClick(() => {
            this.onClose();
          })
      }
      .width('92%')
      .constraintSize({ maxHeight: '78%' })
      .padding(18)
      .backgroundColor(this.theme.card)
      .borderRadius(20)

      Column()
        .width('100%')
        .layoutWeight(1)
        .focusable(false)
        .onClick(() => {
          this.onClose();
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.shown ? this.theme.scrim : Color.Transparent)
    .animation({ duration: 200, curve: Curve.EaseOut })
  }
}
