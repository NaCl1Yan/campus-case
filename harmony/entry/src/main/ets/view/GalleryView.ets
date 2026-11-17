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
  @Prop fs: number = 1;
  @Prop rows: GalleryRow[] = [];

  build() {
    Column({ space: 12 }) {
      Column({ space: 3 }) {
        Text('结局收集册')
          .fontSize(22 * this.fs)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text('换个判断，会走向另一条路')
          .fontSize(11.5 * this.fs)
          .fontColor($r('app.color.text_tertiary'))
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      List({ space: 10 }) {
        ForEach(this.rows, (row: GalleryRow) => {
          ListItem() {
            Column({ space: 6 }) {
              Row() {
                Text(row.unlocked ? row.name : '? ? ?')
                  .fontSize(16 * this.fs)
                  .fontWeight(row.unlocked ? FontWeight.Medium : FontWeight.Normal)
                  .fontColor(row.unlocked ? $r('app.color.text_primary') : $r('app.color.text_tertiary'))
                Blank()
                Text(row.unlocked ? '已解锁' : '未解锁')
                  .fontSize(11 * this.fs)
                  .fontColor(row.unlocked ? $r('app.color.success_text') : $r('app.color.text_tertiary'))
              }
              .width('100%')
              Text(row.detail)
                .fontSize(12 * this.fs)
                .fontColor($r('app.color.text_secondary'))
            }
            .width('100%')
            .padding(15)
            .backgroundColor(row.unlocked ? $r('app.color.surface') : $r('app.color.surface_muted'))
            .borderRadius(16)
            .border({ width: 1, color: $r('app.color.border') })
          }
        }, (row: GalleryRow) => `${row.endingId}:${row.unlocked}`)
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 8 })
    .alignItems(HorizontalAlign.Start)
  }
}