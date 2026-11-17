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
        .fontSize(12 * this.fs)
        .fontColor('#9CA3AF')
        .opacity(this.nameOpacity)
      Text(this.endingName)
        .fontSize(28 * this.fs)
        .fontWeight(FontWeight.Bold)
        .fontColor('#111827')
        .opacity(this.nameOpacity)
        .scale({ x: 0.92 + 0.08 * this.nameOpacity, y: 0.92 + 0.08 * this.nameOpacity })

      ForEach(this.segments, (seg: string, index: number) => {
        Text(seg)
          .fontSize(14 * this.fs)
          .lineHeight(24)
          .fontColor('#374151')
          .opacity(index < this.shown ? 1 : 0)
          .animation({ duration: 500, delay: index * 260 })
      })

      Blank()

      Row({ space: 12 }) {
        Button('再来一次')
          .layoutWeight(1)
          .height(44)
          .fontSize(15 * this.fs)
          .backgroundColor('#EEF2F7')
          .fontColor('#26324A')
          .onClick(() => this.onRestart())
        Button('回主页')
          .layoutWeight(1)
          .height(44)
          .fontSize(15 * this.fs)
          .backgroundColor('#26324A')
          .onClick(() => this.onHome())
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding(24)
    .alignItems(HorizontalAlign.Start)
  }
}