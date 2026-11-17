/** 案件简报（01 §FR-02）：委托信息卡 + 目标清单 + 时间线，接案进入探索。 */
@Component
export struct BriefView {
  @Prop fs: number = 1;
  @Prop title: string = '';
  @Prop subtitle: string = '';
  @Prop client: string = '';
  @Prop summary: string = '';
  @Prop objectives: string[] = [];
  @Prop timeline: string[] = [];
  @Prop accepted: boolean = false;

  onAccept: () => void = () => {
  };
  onEnter: () => void = () => {
  };

  @Builder
  sectionLabel(text: string) {
    Text(text)
      .fontSize(11 * this.fs)
      .letterSpacing(1)
      .fontColor($r('app.color.text_tertiary'))
  }

  build() {
    Column({ space: 12 }) {
      Scroll() {
        Column({ space: 14 }) {
          // 标题区
          Column({ space: 6 }) {
            Text('案件简报')
              .fontSize(11 * this.fs)
              .letterSpacing(2)
              .fontColor($r('app.color.brand_text'))
            Text(this.title)
              .fontSize(26 * this.fs)
              .fontWeight(FontWeight.Bold)
              .lineHeight(34 * this.fs)
              .fontColor($r('app.color.text_primary'))
            Text(this.subtitle)
              .fontSize(13.5 * this.fs)
              .fontColor($r('app.color.text_secondary'))
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          // 委托信息
          Row({ space: 10 }) {
            Column({ space: 3 }) {
              this.sectionLabel('委托人')
              Text(this.client)
                .fontSize(13.5 * this.fs)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Column({ space: 3 }) {
              this.sectionLabel('性质')
              Text('校园失窃 · 单一现场')
                .fontSize(13.5 * this.fs)
                .fontColor($r('app.color.text_body'))
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')
          .padding(14)
          .backgroundColor($r('app.color.surface'))
          .borderRadius(16)
          .border({ width: 1, color: $r('app.color.border') })

          // 案情摘要
          Text(this.summary)
            .fontSize(14 * this.fs)
            .lineHeight(23 * this.fs)
            .fontColor($r('app.color.text_body'))

          // 调查目标
          Column({ space: 8 }) {
            Row() {
              this.sectionLabel('调查目标')
              Blank()
              Text(`${this.objectives.length} 项`)
                .fontSize(11 * this.fs)
                .fontColor($r('app.color.text_tertiary'))
            }
            .width('100%')

            ForEach(this.objectives, (item: string, index: number) => {
              Row({ space: 10 }) {
                Text(`${index + 1}`)
                  .fontSize(11 * this.fs)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.brand_text'))
                  .width(22)
                  .height(22)
                  .textAlign(TextAlign.Center)
                  .backgroundColor($r('app.color.chip_bg'))
                  .borderRadius(11)
                Text(item)
                  .fontSize(13 * this.fs)
                  .lineHeight(20)
                  .fontColor($r('app.color.text_body'))
                  .layoutWeight(1)
              }
              .width('100%')
              .alignItems(VerticalAlign.Top)
            }, (item: string, index: number) => `${index}:${item}`)
          }
          .width('100%')
          .padding(14)
          .backgroundColor($r('app.color.surface'))
          .borderRadius(16)
          .border({ width: 1, color: $r('app.color.border') })
          .alignItems(HorizontalAlign.Start)

          // 时间线
          Column({ space: 8 }) {
            this.sectionLabel('已知时间线')
            ForEach(this.timeline, (item: string) => {
              Row({ space: 10 }) {
                Text('·')
                  .fontSize(16 * this.fs)
                  .fontColor($r('app.color.brand_text'))
                Text(item)
                  .fontSize(12.5 * this.fs)
                  .lineHeight(19)
                  .fontColor($r('app.color.text_secondary'))
                  .layoutWeight(1)
              }
              .width('100%')
              .alignItems(VerticalAlign.Top)
            }, (item: string) => item)
          }
          .width('100%')
          .padding(14)
          .backgroundColor($r('app.color.surface_alt'))
          .borderRadius(16)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .align(Alignment.TopStart)

      // 主按钮固定在底部，永远可点
      Text(this.accepted ? '回到校园地图' : '接下这桩案子')
        .width('100%')
        .height(48)
        .fontSize(15.5 * this.fs)
        .fontWeight(FontWeight.Medium)
        .textAlign(TextAlign.Center)
        .fontColor($r('app.color.on_brand'))
        .backgroundColor($r('app.color.brand_solid'))
        .borderRadius(16)
        .onClick(() => {
          if (this.accepted) {
            this.onEnter();
          } else {
            this.onAccept();
          }
        })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 20, right: 20, top: 14, bottom: 12 })
    .alignItems(HorizontalAlign.Start)
  }
}
