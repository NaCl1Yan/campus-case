/** 结局页（01 §FR-10）：黑场 → 结局名 → 逐段文案，禁止误触返回。 */
@Component
export struct EndingView {
  @Prop fs: number = 1;
  @Prop endingName: string = '';
  @Prop segments: string[] = [];
  @State shown: number = 0;
  @State nameOpacity: number = 0;

  onRestart: () => void = () => {
  };
  onHome: () => void = () => {
  };

  aboutToAppear(): void {
    this.getUIContext().animateTo({ duration: 600, curve: Curve.EaseOut }, () => {
      this.nameOpacity = 1;
    });
    setTimeout(() => {
      this.shown = this.segments.length;
    }, 1200);
  }

  build() {
    Column({ space: 16 }) {
      Blank()
      Text('结局')
        .fontSize(11 * this.fs)
        .letterSpacing(3)
        .fontColor($r('app.color.brand_text'))
        .opacity(this.nameOpacity)
      Text(this.endingName)
        .fontSize(30 * this.fs)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .opacity(this.nameOpacity)
        .scale({ x: 0.92 + 0.08 * this.nameOpacity, y: 0.92 + 0.08 * this.nameOpacity })

      ForEach(this.segments, (seg: string, index: number) => {
        Text(seg)
          .fontSize(14 * this.fs)
          .lineHeight(24)
          .fontColor($r('app.color.text_body'))
          .opacity(index < this.shown ? 1 : 0)
          .animation({ duration: 500, delay: index * 260 })
      })

      Blank()

      Row({ space: 10 }) {
        Text('再来一次')
          .layoutWeight(1)
          .height(46)
          .fontSize(14.5 * this.fs)
          .textAlign(TextAlign.Center)
          .fontColor($r('app.color.brand_text'))
          .backgroundColor($r('app.color.chip_bg'))
          .borderRadius(14)
          .onClick(() => this.onRestart())
        Text('回主页')
          .layoutWeight(1)
          .height(46)
          .fontSize(14.5 * this.fs)
          .fontWeight(FontWeight.Medium)
          .textAlign(TextAlign.Center)
          .fontColor($r('app.color.on_brand'))
          .backgroundColor($r('app.color.brand_solid'))
          .borderRadius(14)
          .onClick(() => this.onHome())
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding({ left: 24, right: 24, top: 30, bottom: 20 })
    .alignItems(HorizontalAlign.Start)
  }
}