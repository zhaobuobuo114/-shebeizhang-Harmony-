import { AppTheme, LIGHT_THEME } from '../utils/Theme';
import { DateUtil } from '../utils/DateUtil';
import { BackupFile } from '../utils/BackupStore';

/**
 * 数据与备份面板：导出、导入、自动备份、回收站、勋章墙的入口。
 *
 * 导出与导入都走系统文件选择器，挑选出来的 .json 与安卓版是同一套格式，
 * 一端导出的文件另一端能原样读进来。整个过程不申请任何存储权限。
 */
@Component
export struct DataSheet {
  @Prop theme: AppTheme = LIGHT_THEME;
  @Prop deviceCount: number = 0;
  @Prop recycleCount: number = 0;
  @Prop badgeCount: number = 0;
  @Prop badgeTotal: number = 14;
  @Prop backups: BackupFile[] = [];

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

  private backupText(b: BackupFile): string {
    return DateUtil.formatClock(b.at) + ' · ' + b.deviceCount + ' 台设备' +
      (b.recycleCount > 0 ? ' · 回收站 ' + b.recycleCount : '');
  }

  @Builder
  private entryView(title: string, value: string, onClick: () => void) {
    Row() {
      Text(title)
        .fontSize(14)
        .fontColor(this.theme.text)
        .layoutWeight(1)
      if (value.length > 0) {
        Text(value)
          .fontSize(12)
          .fontColor(this.theme.sub)
      }
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
  private primaryRowView(text: string, onClick: () => void) {
    Row() {
      Text(text)
        .fontSize(14)
        .fontColor(this.theme.onPrimary)
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
          Text('数据与备份')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.text)
            .layoutWeight(1)
          Text('关闭')
            .fontSize(13)
            .fontColor(this.theme.sub)
            .onClick(() => {
              this.onClose();
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Scroll() {
          Column() {
            Text('当前共 ' + this.deviceCount + ' 台设备' +
              (this.recycleCount > 0 ? '，回收站 ' + this.recycleCount + ' 条' : '') +
              '。导出的文件安卓版与鸿蒙版通用。')
              .fontSize(11.5)
              .fontColor(this.theme.sub)
              .width('100%')
              .margin({ top: 12 })

            Row({ space: 10 }) {
              Column() {
                this.primaryRowView('导出数据', () => {
                  this.onExport();
                });
              }
              .layoutWeight(1)
              Column() {
                Row() {
                  Text('导入数据')
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

            Text('自动备份')
              .fontSize(12)
              .fontColor(this.theme.sub)
              .width('100%')
              .margin({ top: 18, bottom: 8 })

            if (this.backups.length === 0) {
              Text('还没有自动备份。改动数据时会在这里留快照，最多 5 份。')
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
                      Text('点右侧恢复到这个时间点')
                        .fontSize(10.5)
                        .fontColor(this.theme.sub)
                        .margin({ top: 2 })
                    }
                    .alignItems(HorizontalAlign.Start)
                    .layoutWeight(1)

                    Button('恢复')
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
                }, (b: BackupFile) => 'slot' + b.slot)
              }
              .width('100%')
            }

            Text('其他')
              .fontSize(12)
              .fontColor(this.theme.sub)
              .width('100%')
              .margin({ top: 18, bottom: 8 })

            Column({ space: 8 }) {
              this.entryView('回收站', this.recycleCount > 0 ? this.recycleCount + ' 条' : '空', () => {
                this.onOpenTrash();
              })
              this.entryView('里程碑勋章', this.badgeCount + ' / ' + this.badgeTotal, () => {
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
