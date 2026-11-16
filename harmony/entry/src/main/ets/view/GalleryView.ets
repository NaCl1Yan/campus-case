/** 收集册一行（endingId / 显示名 / 是否已解锁 / 解锁时间文案）。 */
export class GalleryRow {
  endingId: string;
  name: string;
  unlocked: boolean;
  detail: string;

  constructor(endingId: string, name: string, unlocked: boolean, detail: string) {
    this.endingId = endingId;
    this.name = name;
    this.unlocked = unlocked;
    this.detail = detail;
  }
}

/** 结局收集册（01 §FR-10 / FR-14）：已解锁显示时间，未解锁只给方向性提示。 */
@Component
export struct GalleryView {
  @Prop rows: GalleryRow[] = [];

  build() {
    Column({ space: 12 }) {
      Text('结局收集册')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#111827')
      Text('换个判断，会走向另一条路。')
        .fontSize(12)
        .fontColor('#9CA3AF')

      List({ space: 10 }) {
        ForEach(this.rows, (row: GalleryRow) => {
          ListItem() {
            Column({ space: 6 }) {
              Row() {
                Text(row.unlocked ? row.name : '? ? ?')
                  .fontSize(16)
                  .fontWeight(row.unlocked ? FontWeight.Medium : FontWeight.Normal)
                  .fontColor(row.unlocked ? '#111827' : '#9CA3AF')
                Blank()
                Text(row.unlocked ? '已解锁' : '未解锁')
                  .fontSize(11)
                  .fontColor(row.unlocked ? '#2E7D32' : '#9CA3AF')
              }
              .width('100%')
              Text(row.detail)
                .fontSize(12)
                .fontColor('#6B7280')
            }
            .width('100%')
            .padding(14)
            .backgroundColor(row.unlocked ? '#FFFFFF' : '#F3F4F6')
            .borderRadius(12)
            .border({ width: 1, color: '#E5E7EB' })
          }
        }, (row: GalleryRow) => `${row.endingId}:${row.unlocked}`)
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .alignItems(HorizontalAlign.Start)
  }
}
