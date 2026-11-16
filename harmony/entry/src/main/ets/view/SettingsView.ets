/** 设置页（01 §FR-15）：动画减弱、清空进度、关于。 */
@Component
export struct SettingsView {
  @Prop reduceMotion: boolean = false;
  @Prop contentVersion: number = 1;
  @Prop validationText: string = '通过';
  @Prop restoredFrom: string = '';

  onToggleReduceMotion: (value: boolean) => void = () => {
  };
  onClearProgress: () => void = () => {
  };

  private restoredLabel(): string {
    if (this.restoredFrom === 'autoSlot') {
      return '自动存档槽';
    }
    if (this.restoredFrom === 'snapshot') {
      return 'Preferences 快照';
    }
    if (this.restoredFrom === 'eventLog') {
      return '事件流水回放';
    }
    return '新局';
  }

  build() {
    Column({ space: 14 }) {
      Text('设置')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#111827')

      Row() {
        Column({ space: 2 }) {
          Text('动画减弱')
            .fontSize(14)
            .fontColor('#111827')
          Text('关掉位移与抖动，只保留淡入（无障碍）')
            .fontSize(11)
            .fontColor('#9CA3AF')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Toggle({ type: ToggleType.Switch, isOn: this.reduceMotion })
          .onChange((isOn: boolean) => this.onToggleReduceMotion(isOn))
      }
      .width('100%')
      .padding(14)
      .backgroundColor('#FFFFFF')
      .borderRadius(12)
      .border({ width: 1, color: '#E5E7EB' })

      Column({ space: 8 }) {
        Text('关于')
          .fontSize(14)
          .fontColor('#111827')
        Text(`内容版本 v${this.contentVersion} · 内容校验：${this.validationText}`)
          .fontSize(12)
          .fontColor(this.validationText === '通过' ? '#2E7D32' : '#B3261E')
        Text(`本次进度来源：${this.restoredLabel()}`)
          .fontSize(12)
          .fontColor('#6B7280')
        Text('《钟楼七点》· 鸿蒙课程作业 · 纯离线，不联网')
          .fontSize(12)
          .fontColor('#6B7280')
      }
      .width('100%')
      .padding(14)
      .backgroundColor('#FFFFFF')
      .borderRadius(12)
      .border({ width: 1, color: '#E5E7EB' })
      .alignItems(HorizontalAlign.Start)

      Button('清空本局进度（保留存档槽）')
        .width('100%')
        .height(44)
        .fontSize(14)
        .backgroundColor('#FFFFFF')
        .fontColor('#B3261E')
        .border({ width: 1, color: '#F3C1BE' })
        .onClick(() => this.onClearProgress())

      Blank()
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .alignItems(HorizontalAlign.Start)
  }
}
