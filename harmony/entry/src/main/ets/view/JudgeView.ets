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
        fontColor: '#B3261E',
        action: () => this.onChoose(id),
      },
    });
  }

  build() {
    Column({ space: 14 }) {
      Text('最终判断')
        .fontSize(22 * this.fs)
        .fontWeight(FontWeight.Bold)
        .fontColor('#111827')
      Text(this.ready ? '你手里的证据已经能说完整一句话了。' : '证据还不足以支撑一个判断。')
        .fontSize(12 * this.fs)
        .fontColor(this.ready ? '#6B7280' : '#B3261E')

      ForEach(this.options, (option: JudgeOption) => {
        Column({ space: 6 }) {
          Text(option.label)
            .fontSize(15 * this.fs)
            .fontColor(option.available ? '#111827' : '#9CA3AF')
          if (!option.available) {
            Text(option.reason)
              .fontSize(11 * this.fs)
              .fontColor('#B3261E')
          }
        }
        .width('100%')
        .padding(16)
        .backgroundColor(option.available ? '#FFFFFF' : '#F3F4F6')
        .borderRadius(12)
        .border({ width: 1, color: option.available ? '#26324A' : '#E5E7EB' })
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
    .padding(20)
    .alignItems(HorizontalAlign.Start)
  }
}