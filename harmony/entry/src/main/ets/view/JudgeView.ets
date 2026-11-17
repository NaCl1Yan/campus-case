/** 判断选项数据。 */
export class JudgeOption {
  id: string;
  label: string;
  available: boolean;
  reason: string;

  constructor(id: string, label: string, available: boolean, reason: string) {
    this.id = id;
    this.label = label;
    this.available = available;
    this.reason = reason;
  }
}

/** 最终判断（01 §FR-09）：不可用选项灰显并说明原因，提交前二次确认。 */
@Component
export struct JudgeView {
  @Prop fs: number = 1;
  @Prop options: JudgeOption[] = [];
  @Prop ready: boolean = false;

  onChoose: (choiceId: string) => void = () => {
  };

  private confirm(id: string, label: string): void {
    this.getUIContext().showAlertDialog({
      title: '确认最终判断',
      message: `${label}\n\n这个判断不可撤销，提交后直接进入结局。`,
      autoCancel: true,
      primaryButton: {
        value: '再想想',
        action: () => {
        },
      },
      secondaryButton: {
        value: '确定',
        fontColor: $r('app.color.danger_text'),
        action: () => this.onChoose(id),
      },
    });
  }

  build() {
    Column({ space: 14 }) {
      Column({ space: 4 }) {
        Text('最终判断')
          .fontSize(22 * this.fs)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text(this.ready ? '你手里的证据已经能说完整一句话了——选一个处理方式。'
          : '证据还不足以支撑一个判断：先回线索板补齐链条。')
          .fontSize(12 * this.fs)
          .lineHeight(19)
          .fontColor(this.ready ? $r('app.color.text_secondary') : $r('app.color.danger_text'))
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      ForEach(this.options, (option: JudgeOption) => {
        Column({ space: 6 }) {
          Row({ space: 8 }) {
            Text(option.label)
              .fontSize(15 * this.fs)
              .lineHeight(22)
              .fontColor(option.available ? $r('app.color.text_primary') : $r('app.color.text_tertiary'))
              .layoutWeight(1)
            Text(option.available ? '可选' : '锁定')
              .fontSize(10.5 * this.fs)
              .fontColor(option.available ? $r('app.color.on_brand') : $r('app.color.text_tertiary'))
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .backgroundColor(option.available ? $r('app.color.brand_solid') : $r('app.color.chip_bg'))
              .borderRadius(8)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
          if (!option.available) {
            Text(option.reason)
              .fontSize(11 * this.fs)
              .fontColor($r('app.color.danger_text'))
          }
        }
        .width('100%')
        .padding(16)
        .backgroundColor(option.available ? $r('app.color.surface') : $r('app.color.surface_muted'))
        .borderRadius(16)
        .border({ width: 1, color: option.available ? $r('app.color.brand_text') : $r('app.color.border') })
        .opacity(option.available ? 1 : 0.9)
        .onClick(() => {
          if (option.available) {
            this.confirm(option.id, option.label);
          }
        })
      }, (option: JudgeOption) => `${option.id}:${option.available}`)

      Blank()
    }
    .width('100%')
    .height('100%')
    .padding({ left: 20, right: 20, top: 16, bottom: 12 })
    .alignItems(HorizontalAlign.Start)
  }
}