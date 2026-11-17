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
        fontColor: $r('app.color.danger_text'),
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
        fontColor: $r('app.color.danger_text'),
        action: () => this.onDelete(slotId),
      },
    });
  }

  build() {
    Column({ space: 12 }) {
      Column({ space: 3 }) {
        Text('存档')
          .fontSize(22 * this.fs)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text('自动槽每次调查后更新；手动槽用于回滚到某个时刻')
          .fontSize(11.5 * this.fs)
          .fontColor($r('app.color.text_tertiary'))
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      List({ space: 10 }) {
        ForEach(this.rows, (row: SlotRow) => {
          ListItem() {
            Column({ space: 8 }) {
              Row() {
                Text(row.title)
                  .fontSize(14 * this.fs)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))
                Blank()
                Text(row.empty ? '空' : row.detail)
                  .fontSize(11 * this.fs)
                  .fontColor(row.empty ? $r('app.color.text_tertiary') : $r('app.color.text_body'))
              }
              .width('100%')

              Row({ space: 8 }) {
                if (row.slotId > 0) {
                  Button(row.empty ? '存档' : '覆盖')
                    .height(34)
                    .fontSize(12 * this.fs)
                    .backgroundColor($r('app.color.chip_bg'))
                    .fontColor($r('app.color.brand_text'))
                    .borderRadius(10)
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
                  .height(34)
                  .fontSize(12 * this.fs)
                  .backgroundColor($r('app.color.brand_solid'))
                  .borderRadius(10)
                  .enabled(!row.empty)
                  .onClick(() => this.onLoad(row.slotId))
                if (!row.empty) {
                  Button('删除')
                    .height(34)
                    .fontSize(12 * this.fs)
                    .backgroundColor($r('app.color.chip_bg'))
                    .fontColor($r('app.color.danger_text'))
                    .borderRadius(10)
                    .onClick(() => this.confirmDelete(row.slotId, row.title))
                }
              }
              .width('100%')
            }
            .width('100%')
            .padding(15)
            .backgroundColor($r('app.color.surface'))
            .borderRadius(16)
            .border({ width: 1, color: $r('app.color.border') })
          }
        }, (row: SlotRow) => `${row.slotId}:${row.empty}:${row.detail}`)
      }
      .layoutWeight(1)
      .width('100%')

      Button('重开本局（清空进度）')
        .width('100%')
        .height(44)
        .fontSize(14 * this.fs)
        .backgroundColor($r('app.color.surface'))
        .fontColor($r('app.color.danger_text'))
        .border({ width: 1, color: $r('app.color.danger_soft_border') })
        .onClick(() => this.onRestart())
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 8 })
    .alignItems(HorizontalAlign.Start)
  }
}