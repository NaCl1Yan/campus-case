/**
 * 常驻 HUD（01 §FR-11）：阶段、目标、线索计数、双链进度、进度环、存档提示、页面工具条。
 * 只做展示与回调，不含业务判定。
 *
 * 布局（自上而下四行，信息密度从高到低）：
 *   1. 返回 + 阶段胶囊 + 进度环 + 存档
 *   2. 当前目标（最多两行）
 *   3. 状态胶囊组：线索 / 行动线 / 动机线 / 可推理 + 已保存时间
 *   4. 工具条：简报 · 收集册 · 设置 · 重来
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
  @State showMore: boolean = false;

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

  @Builder
  sheetItem(label: string, hint: string, danger: boolean, action: () => void) {
    Row({ space: 10 }) {
      Column({ space: 2 }) {
        Text(label)
          .fontSize(15 * this.fs)
          .fontColor(danger ? $r('app.color.danger_text') : $r('app.color.text_primary'))
        if (hint.length > 0) {
          Text(hint)
            .fontSize(11 * this.fs)
            .fontColor($r('app.color.text_tertiary'))
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text('›')
        .fontSize(16 * this.fs)
        .fontColor($r('app.color.text_tertiary'))
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .borderRadius(12)
    .backgroundColor($r('app.color.surface_alt'))
    .onClick(() => {
      this.showMore = false;
      action();
    })
  }

  @Builder
  moreSheet() {
    Column({ space: 8 }) {
      Text('更多')
        .fontSize(12 * this.fs)
        .letterSpacing(1)
        .fontColor($r('app.color.text_tertiary'))
        .width('100%')
      this.sheetItem('案件简报', '回看委托与调查目标', false, () => this.onBrief())
      this.sheetItem('结局收集册', '已解锁的结局与条件', false, () => this.onGallery())
      this.sheetItem('设置', '外观 / 字号 / 动画 / 清空进度', false, () => this.onSettings())
      this.sheetItem('重来本局', '清空当前进度（存档保留）', true, () => this.onRestart())
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 4, bottom: 20 })
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        if (this.showBack) {
          Text('‹ 返回')
            .fontSize(12 * this.fs)
            .fontColor($r('app.color.brand_text'))
            .padding({ left: 9, right: 10, top: 5, bottom: 5 })
            .backgroundColor($r('app.color.chip_bg'))
            .borderRadius(9)
            .onClick(() => this.onBack())
        }
        Text(this.stageText)
          .fontSize(12 * this.fs)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.brand_text'))
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .backgroundColor($r('app.color.chip_bg'))
          .borderRadius(10)
        Blank()
        Stack() {
          Progress({ value: this.progress, total: 100, type: ProgressType.Ring })
            .width(34)
            .height(34)
            .color($r('app.color.brand_solid'))
            .backgroundColor($r('app.color.track'))
            .style({ strokeWidth: 4 })
          Text(`${Math.round(this.progress)}`)
            .fontSize(10 * this.fs)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.brand_text'))
        }
        Text('存档')
          .fontSize(12.5 * this.fs)
          .fontColor($r('app.color.brand_text'))
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .borderRadius(9)
          .backgroundColor($r('app.color.chip_bg'))
          .onClick(() => this.onSlots())
        Text('⋯ 更多')
          .fontSize(12.5 * this.fs)
          .fontColor($r('app.color.text_secondary'))
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .borderRadius(9)
          .backgroundColor($r('app.color.chip_bg'))
          .onClick(() => {
            this.showMore = true;
          })
          .bindSheet($$this.showMore, this.moreSheet(), {
            height: SheetSize.FIT_CONTENT,
            dragBar: true,
            showClose: false,
            backgroundColor: $r('app.color.surface'),
          })
      }
      .width('100%')

      Row({ space: 6 }) {
        Text('◎')
          .fontSize(12 * this.fs)
          .fontColor($r('app.color.text_tertiary'))
        Text(this.objective)
          .fontSize(12.5 * this.fs)
          .fontColor($r('app.color.text_body'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Row({ space: 6 }) {
        Text(`线索 ${this.clueText}`)
          .fontSize(11 * this.fs)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_body'))
          .padding({ left: 9, right: 9, top: 4, bottom: 4 })
          .backgroundColor($r('app.color.chip_bg'))
          .borderRadius(9)
        Text(`行动线 ${this.chainBText}`)
          .fontSize(11 * this.fs)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_body'))
          .padding({ left: 9, right: 9, top: 4, bottom: 4 })
          .backgroundColor($r('app.color.chip_bg'))
          .borderRadius(9)
        Text(`动机线 ${this.chainAText}`)
          .fontSize(11 * this.fs)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_body'))
          .padding({ left: 9, right: 9, top: 4, bottom: 4 })
          .backgroundColor($r('app.color.chip_bg'))
          .borderRadius(9)
        if (this.ready) {
          Text('可推理')
            .fontSize(11 * this.fs)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.on_brand'))
            .padding({ left: 9, right: 9, top: 4, bottom: 4 })
            .backgroundColor($r('app.color.danger_solid'))
            .borderRadius(9)
        }
        Blank()
        Text(this.savedText)
          .fontSize(10 * this.fs)
          .fontColor($r('app.color.text_tertiary'))
      }
      .width('100%')

    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .backgroundColor($r('app.color.surface'))
    .border({ width: { bottom: 1 }, color: $r('app.color.border') })
  }
}
