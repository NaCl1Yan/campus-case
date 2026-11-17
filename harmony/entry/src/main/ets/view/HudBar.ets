/**
 * 常驻 HUD（01 §FR-11）：阶段、目标、线索计数、双链进度、进度环、存档提示。
 * 只做展示与回调，不含业务判定。
 */
@Component
export struct HudBar {
  @Prop fs: number = 1;
  @Prop stageText: string = '';
  @Prop objective: string = '';
  @Prop clueText: string = '';
  @Prop progress: number = 0;
  @Prop chainBText: string = '';
  @Prop chainAText: string = '';
  @Prop ready: boolean = false;
  @Prop savedText: string = '';
  @Prop showBack: boolean = false;

  onBack: () => void = () => {
  };
  onBoard: () => void = () => {
  };
  onSlots: () => void = () => {
  };
  onGallery: () => void = () => {
  };
  onBrief: () => void = () => {
  };
  onSettings: () => void = () => {
  };
  onRestart: () => void = () => {
  };

  build() {
    Column({ space: 6 }) {
      Row() {
        if (this.showBack) {
          Button('‹ 返回')
            .fontSize(14 * this.fs)
            .height(30)
            .backgroundColor('#00000000')
            .fontColor('#26324A')
            .onClick(() => this.onBack())
        }
        Text(this.stageText)
          .fontSize(14 * this.fs)
          .fontWeight(FontWeight.Bold)
          .fontColor('#26324A')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Button('存档')
          .fontSize(13 * this.fs)
          .height(30)
          .backgroundColor('#00000000')
          .fontColor('#26324A')
          .onClick(() => this.onSlots())
      }
      .width('100%')

      Row() {
        Text(`🎯 ${this.objective}`)
          .fontSize(13 * this.fs)
          .fontColor('#4B5563')
          .maxLines(2)
          .layoutWeight(1)
        Stack() {
          Progress({ value: this.progress, total: 100, type: ProgressType.Ring })
            .width(38)
            .height(38)
            .color('#26324A')
            .style({ strokeWidth: 5 })
          Text(`${Math.round(this.progress)}`)
            .fontSize(11 * this.fs)
            .fontColor('#26324A')
        }
      }
      .width('100%')

      Row({ space: 10 }) {
        Text(`线索 ${this.clueText}`)
          .fontSize(12 * this.fs)
          .fontColor('#6B7280')
        Text(`行动线 ${this.chainBText}`)
          .fontSize(12 * this.fs)
          .fontColor('#6B7280')
        Text(`动机线 ${this.chainAText}`)
          .fontSize(12 * this.fs)
          .fontColor('#6B7280')
        Blank()
        Text(this.savedText)
          .fontSize(11 * this.fs)
          .fontColor('#9CA3AF')
      }
      .width('100%')

      Row({ space: 8 }) {
        if (this.ready) {
          Text('可推理')
            .fontSize(12 * this.fs)
            .fontColor('#FFFFFF')
            .backgroundColor('#B3261E')
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .borderRadius(10)
        }
        Blank()
        Button('简报')
          .fontSize(13 * this.fs)
          .height(30)
          .backgroundColor('#00000000')
          .fontColor('#26324A')
          .onClick(() => this.onBrief())
        Button('收集册')
          .fontSize(13 * this.fs)
          .height(30)
          .backgroundColor('#00000000')
          .fontColor('#26324A')
          .onClick(() => this.onGallery())
        Button('设置')
          .fontSize(13 * this.fs)
          .height(30)
          .backgroundColor('#00000000')
          .fontColor('#26324A')
          .onClick(() => this.onSettings())
        Button('重来')
          .fontSize(13 * this.fs)
          .height(30)
          .backgroundColor('#00000000')
          .fontColor('#B3261E')
          .onClick(() => this.onRestart())
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .backgroundColor('#F7F9FC')
    .border({ width: { bottom: 1 }, color: '#E5E7EB' })
  }
}