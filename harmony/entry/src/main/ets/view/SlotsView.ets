/** 存档槽行数据。 */
export class SlotRow {
  slotId: number;
  title: string;
  detail: string;
  empty: boolean;

  constructor(slotId: number, title: string, detail: string, empty: boolean) {
    this.slotId = slotId;
    this.title = title;
    this.detail = detail;
    this.empty = empty;
  }
}

/** 存档/读档/重开（01 §FR-13）：自动槽 + 3 手动槽，覆盖与删除都要确认。 */
@Component
export struct SlotsView {
  @Prop fs: number = 1;
  @Prop rows: SlotRow[] = [];
  @Prop canSave: boolean = true;

  onSave: (slotId: number) => void = () => {
  };
  onLoad: (slotId: number) => void = () => {
  };
  onDelete: (slotId: number) => void = () => {
  };
  onRestart: () => void = () => {
  };

  private confirmSave(slotId: number, title: string): void {
    this.getUIContext().showAlertDialog({
      title: '覆盖存档',
      message: `${title} 已有内容，覆盖后无法恢复。`,
      primaryButton: {
        value: '取消',
        action: () => {
        },
      },
      secondaryButton: {
        value: '覆盖',
        fontColor: '#B3261E',
        action: () => this.onSave(slotId),
      },
    });
  }

  private confirmDelete(slotId: number, title: string): void {
    this.getUIContext().showAlertDialog({
      title: '删除存档',
      message: `${title} 将被删除，无法恢复。`,
      primaryButton: {
        value: '取消',
        action: () => {
        },
      },
      secondaryButton: {
        value: '删除',
        fontColor: '#B3261E',
        action: () => this.onDelete(slotId),
      },
    });
  }

  build() {
    Column({ space: 12 }) {
      Text('存档')
        .fontSize(20 * this.fs)
        .fontWeight(FontWeight.Bold)
        .fontColor('#111827')
      Text('自动存档在每次调查后更新；手动槽用于回滚到某个时刻。')
        .fontSize(12 * this.fs)
        .fontColor('#9CA3AF')

      List({ space: 10 }) {
        ForEach(this.rows, (row: SlotRow) => {
          ListItem() {
            Column({ space: 8 }) {
              Row() {
                Text(row.title)
                  .fontSize(14 * this.fs)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#111827')
                Blank()
                Text(row.empty ? '空' : row.detail)
                  .fontSize(11 * this.fs)
                  .fontColor(row.empty ? '#9CA3AF' : '#4B5563')
              }
              .width('100%')

              Row({ space: 8 }) {
                if (row.slotId > 0) {
                  Button(row.empty ? '存档' : '覆盖')
                    .height(32)
                    .fontSize(12 * this.fs)
                    .backgroundColor('#EEF2F7')
                    .fontColor('#26324A')
                    .enabled(this.canSave)
                    .onClick(() => {
                      if (row.empty) {
                        this.onSave(row.slotId);
                      } else {
                        this.confirmSave(row.slotId, row.title);
                      }
                    })
                }
                Button('读取')
                  .height(32)
                  .fontSize(12 * this.fs)
                  .backgroundColor('#26324A')
                  .enabled(!row.empty)
                  .onClick(() => this.onLoad(row.slotId))
                if (!row.empty) {
                  Button('删除')
                    .height(32)
                    .fontSize(12 * this.fs)
                    .backgroundColor('#00000000')
                    .fontColor('#B3261E')
                    .onClick(() => this.confirmDelete(row.slotId, row.title))
                }
              }
              .width('100%')
            }
            .width('100%')
            .padding(14)
            .backgroundColor('#FFFFFF')
            .borderRadius(12)
            .border({ width: 1, color: '#E5E7EB' })
          }
        }, (row: SlotRow) => `${row.slotId}:${row.empty}:${row.detail}`)
      }
      .layoutWeight(1)
      .width('100%')

      Button('重开本局（清空进度）')
        .width('100%')
        .height(44)
        .fontSize(14 * this.fs)
        .backgroundColor('#FFFFFF')
        .fontColor('#B3261E')
        .border({ width: 1, color: '#F3C1BE' })
        .onClick(() => this.onRestart())
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .alignItems(HorizontalAlign.Start)
  }
}