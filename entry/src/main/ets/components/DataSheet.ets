import { AppTheme, LIGHT_THEME } from '../utils/Theme';
import { DateUtil } from '../utils/DateUtil';
import { I18n } from '../utils/I18n';
import { BackupFile, BackupStore } from '../utils/BackupStore';
import { Lang } from '../utils/I18n';

/** 语言栏里的一行 */
interface LangOption {
  tag: string;
  name: string;
}

/**
 * 数据与备份面板：导出、导入、自动备份、回收站、勋章墙的入口。
 *
 * 导出与导入都走系统文件选择器，挑选出来的 .json 与安卓版是同一套格式，
 * 一端导出的文件另一端能原样读进来。整个过程不申请任何存储权限。
 */
@Component
export struct DataSheet {
  /**
   * 语言版本号：ArkUI 只在表达式里"读到"状态变量时才建立依赖，
   * I18n.t() 自己不是状态，所以切语言不会让这行字重画。
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
  @Prop deviceCount: number = 0;
  @Prop recycleCount: number = 0;
  @Prop badgeCount: number = 0;
  @Prop badgeTotal: number = 14;
  @Prop backups: BackupFile[] = [];
  /** 当前选择的语言（`system` 或四种 tag），用来给语言栏打勾 */
  @Prop languageTag: string = 'system';

  /** 选语言：落库与重渲染都归 Index，这里只把 tag 传出去 */
  onPickLanguage: (tag: string) => void = () => {
  };

  /** 弹出系统文件选择器，把当前数据存成一个 .json */
  onExport: () => void = () => {
  };
  /** 弹出系统文件选择器挑一个 .json 进来 */
  onImport: () => void = () => {
  };
  /** 回滚到某一槽位的自动备份 */
  onRestoreBackup: (slot: number) => void = () => {
  };
  onOpenTrash: () => void = () => {
  };
  onOpenBadges: () => void = () => {
  };
  onClose: () => void = () => {
  };

  @State shown: boolean = false;

  aboutToAppear(): void {
    setTimeout(() => {
      this.shown = true;
    }, 20);
  }

  /**
   * 一条自动备份的说明：时间 · 台数 ·（回收站条数）。
   *
   * data_snapshot_row 四种语言都是同形的 `{0} · {1}`，所以可以放心套两层：
   * 外层接时间和后面那串，内层接台数和回收站。三段各自都是完整资源
   * （data_snapshot_devices / data_snapshot_trash），这里没有一个字是拼出来的。
   */
  private backupText(b: BackupFile): string {
    const counts: string = b.recycleCount > 0
      ? this.t('data_snapshot_row',
        this.t('data_snapshot_devices', b.deviceCount),
        this.t('data_snapshot_trash', b.recycleCount))
      : this.t('data_snapshot_devices', b.deviceCount);
    return this.t('data_snapshot_row', DateUtil.formatClock(b.at), counts);
  }

  /**
   * 面板开头那句统计。整句走复数表 p_data_intro（英文一台是 "There is 1 device"，
   * 两台才是 "There are 2 devices"；中文与日文只有一个形态，other 通吃）。
   * 中间那个 {1} 交给 data_intro_trash_tail（各语言的括号/逗号写法都不一样：
   * 中文「，回收站 3 条」/ 日语「（ゴミ箱 3 件）」/ 英文「, 3 in trash」），
   * 没有回收站就传空串，整句仍然通顺。
   */
  private introText(): string {
    return this.qt('p_data_intro', this.deviceCount, this.deviceCount,
      this.recycleCount > 0 ? this.t('data_intro_trash_tail', this.recycleCount) : '');
  }

  private langOptions(): LangOption[] {
    const out: LangOption[] = [];
    out.push({ tag: I18n.FOLLOW_SYSTEM, name: this.t('lang_system') });
    out.push({ tag: Lang.ZH_CN, name: this.t('lang_zh_cn') });
    out.push({ tag: Lang.ZH_TW, name: this.t('lang_zh_tw') });
    out.push({ tag: Lang.JA, name: this.t('lang_ja') });
    out.push({ tag: Lang.EN, name: this.t('lang_en') });
    return out;
  }

  @Builder
  private langRowView(o: LangOption) {
    Row() {
      Text(o.name)
        .fontSize(14)
        .fontColor(this.theme.text)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      if (this.languageTag === o.tag) {
        Text('✓')
          .fontSize(14)
          .fontColor(this.theme.primary)
          .margin({ left: 8 })
      }
    }
    .width('100%')
    .padding({ left: 13, right: 12, top: 11, bottom: 11 })
    .backgroundColor(this.theme.card2)
    .borderRadius(12)
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.onPickLanguage(o.tag);
    })
  }

  /**
   * 注意：下面这两个 @Builder（三处调用）收的是**键名与开关**，不是算好的句子。
   *
   * @Builder 按值传参时，调用它的那句只在初次渲染时执行一次，父组件重跑 build 也不会
   * 重新求值——切完语言，回收站行、勋章行、导出按钮这三处就会留着旧语言。
   * 真机实测还补了一刀：`Index.onLangChange()` 那套"关掉面板再重开"只在**显式选某门语言**
   * 时兜得住（平台会跟着推一次 UpdateConfigurationSyncForAll，整棵组件树重搭），
   * 选「跟随系统」时平台走的是 setAppPreferredLanguage('default')，一条配置回调都不发，
   * 重开也没能把这三处刷过来（Mate 90 Pro 实测：切完仍显示上一门语言的「データを書き出す」）。
   * 所以取词必须发生在 builder 体内：这里只把键名与一个布尔开关传进去，句子由 this.t()/this.qt() 现拼，
   * 数字仍从各 @Prop 上读，依赖照旧挂在 langVersion 与这些 @Prop 上。
   */
  private entryValueText(trashRow: boolean): string {
    if (trashRow) {
      return this.recycleCount > 0
        ? this.qt('p_items', this.recycleCount, this.recycleCount)
        : this.t('data_trash_row_empty');
    }
    return this.t('data_badges_row', this.badgeCount, this.badgeTotal);
  }

  @Builder
  private entryView(titleKey: string, trashRow: boolean, onClick: () => void) {
    Row() {
      Text(this.t(titleKey))
        .fontSize(14)
        .fontColor(this.theme.text)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        // 标题是本行唯一的弹性元素：右侧 value（如「12 of 14 earned」）变长时，
        // 挤掉的是标题的尾巴，两个都定长就会把整行顶出去
        .layoutWeight(1)
      Text(this.entryValueText(trashRow))
        .fontSize(12)
        .fontColor(this.theme.sub)
        .maxLines(1)
        .margin({ left: 8 })
      Text('›')
        .fontSize(15)
        .fontColor(this.theme.sub)
        .margin({ left: 6 })
    }
    .width('100%')
    .padding({ left: 13, right: 12, top: 12, bottom: 12 })
    .backgroundColor(this.theme.card2)
    .borderRadius(12)
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      onClick();
    })
  }

  @Builder
  private primaryRowView(textKey: string, onClick: () => void) {
    Row() {
      Text(this.t(textKey))
        .fontSize(14)
        .fontColor(this.theme.onPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .height(44)
    .backgroundColor(this.theme.primary)
    .borderRadius(12)
    .onClick(() => {
      onClick();
    })
  }

  build() {
    Column() {
      Column()
        .width('100%')
        .layoutWeight(1)
        .focusable(false)
        .onClick(() => {
          this.onClose();
        })

      Column() {
        Row() {
          Text(this.t('data_title'))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.text)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          Text(this.t('editor_close'))
            .fontSize(13)
            .fontColor(this.theme.sub)
            .maxLines(1)
            .margin({ left: 8 })
            .onClick(() => {
              this.onClose();
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Scroll() {
          Column() {
            Text(this.t('data_lang_title'))
              .fontSize(12)
              .fontColor(this.theme.sub)
              .width('100%')
              .margin({ top: 12, bottom: 8 })

            Column({ space: 8 }) {
              // key 里带上 langVersion：否则切完语言 ForEach 认为每项没变，列表不重建，
              // 这一栏会一直停在上一门语言的名字上
              ForEach(this.langOptions(), (o: LangOption) => {
                this.langRowView(o);
              }, (o: LangOption) => this.langVersion + '|' + o.tag)
            }
            .width('100%')
            .margin({ top: 0 })

            Text(this.introText())
              .fontSize(11.5)
              .fontColor(this.theme.sub)
              .width('100%')
              .margin({ top: 12 })

            Row({ space: 10 }) {
              Column() {
                this.primaryRowView('data_export_short', () => {
                  this.onExport();
                });
              }
              .layoutWeight(1)
              Column() {
                Row() {
                  Text(this.t('data_import_short'))
                    .fontSize(14)
                    .fontColor(this.theme.text2)
                    .layoutWeight(1)
                    .textAlign(TextAlign.Center)
                }
                .width('100%')
                .height(44)
                .backgroundColor(this.theme.card2)
                .borderRadius(12)
                .onClick(() => {
                  this.onImport();
                })
              }
              .layoutWeight(1)
            }
            .width('100%')
            .margin({ top: 14 })

            Text(this.t('data_auto_title'))
              .fontSize(12)
              .fontColor(this.theme.sub)
              .width('100%')
              .margin({ top: 18, bottom: 8 })

            if (this.backups.length === 0) {
              Text(this.t('data_no_auto_backups', BackupStore.SLOTS))
                .fontSize(12)
                .fontColor(this.theme.sub)
                .width('100%')
                .padding({ left: 13, right: 13, top: 12, bottom: 12 })
                .backgroundColor(this.theme.card2)
                .borderRadius(12)
            } else {
              Column({ space: 8 }) {
                ForEach(this.backups, (b: BackupFile) => {
                  Row() {
                    Column() {
                      Text(this.backupText(b))
                        .fontSize(13)
                        .fontColor(this.theme.text)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                      Text(this.t('data_snapshot_restore_hint'))
                        .fontSize(10.5)
                        .fontColor(this.theme.sub)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .margin({ top: 2 })
                    }
                    .alignItems(HorizontalAlign.Start)
                    .layoutWeight(1)

                    Button(this.t('data_snapshot_restore'))
                      .fontSize(12)
                      .fontColor(this.theme.primary)
                      .backgroundColor(this.theme.primarySoft)
                      .borderRadius(9)
                      .height(30)
                      .padding({ left: 12, right: 12 })
                      .stateEffect(false)
                      .focusable(false)
                      .onClick(() => {
                        this.onRestoreBackup(b.slot);
                      })
                  }
                  .width('100%')
                  .padding({ left: 12, right: 12, top: 10, bottom: 10 })
                  .backgroundColor(this.theme.card2)
                  .borderRadius(12)
                  .alignItems(VerticalAlign.Center)
                }, (b: BackupFile) => this.langVersion + '|slot' + b.slot)
              }
              .width('100%')
            }

            Text(this.t('kind_other'))
              .fontSize(12)
              .fontColor(this.theme.sub)
              .width('100%')
              .margin({ top: 18, bottom: 8 })

            Column({ space: 8 }) {
              this.entryView('data_section_trash', true, () => {
                this.onOpenTrash();
              })
              this.entryView('data_section_badges', false, () => {
                this.onOpenBadges();
              })
            }
            .width('100%')
          }
          .width('100%')
        }
        .width('100%')
        .constraintSize({ maxHeight: '62%' })
        .margin({ top: 4 })
        .scrollBar(BarState.Off)
      }
      .width('92%')
      .constraintSize({ maxHeight: '82%' })
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
