/** 设置页（01 §FR-15）：动画减弱、清空进度、关于。 */
@Component
export struct SettingsView {
  @Prop fs: number = 1;
  @Prop reduceMotion: boolean = false;
  @Prop contentVersion: number = 1;
  @Prop validationText: string = '通过';
  @Prop fontScale: number = 1;
  @Prop restoredFrom: string = '';

  onToggleReduceMotion: (value: boolean) => void = () => {
  };
  onFontScale: (value: number) => void = () => {
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
        .fontSize(20 * this.fs)
        .fontWeight(FontWeight.Bold)
        .fontColor('#111827')

      Row() {
        Column({ space: 2 }) {
          Text('动画减弱')
            .fontSize(14 * this.fs)
            .fontColor('#111827')
          Text('关掉位移与抖动，只保留淡入（无障碍）')
            .fontSize(11 * this.fs)
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

      Column({ space: 10 }) {
        Text('字号缩放')
          .fontSize(14 * this.fs)
          .fontColor('#111827')
        Text('影响界面文字大小')
          .fontSize(11 * this.fs)
          .fontColor('#9CA3AF')
        Row({ space: 8 }) {
          ForEach([1, 1.2, 1.5], (value: number) => {
            Button(value === 1 ? '标准' : (value === 1.2 ? '大' : '特大'))
              .layoutWeight(1)
              .height(34)
              .fontSize(13 * this.fs)
              .backgroundColor(this.fontScale === value ? '#26324A' : '#EEF2F7')
              .fontColor(this.fontScale === value ? '#FFFFFF' : '#26324A')
              .onClick(() => this.onFontScale(value))
          }, (value: number) => `${value}`)
        }
        .width('100%')
      }
      .width('100%')
      .padding(14)
      .backgroundColor('#FFFFFF')
      .borderRadius(12)
      .border({ width: 1, color: '#E5E7EB' })
      .alignItems(HorizontalAlign.Start)

      Column({ space: 8 }) {
        Text('关于')
          .fontSize(14 * this.fs)
          .fontColor('#111827')
        Text(`内容版本 v${this.contentVersion} · 内容校验：${this.validationText}`)
          .fontSize(12 * this.fs)
          .fontColor(this.validationText === '通过' ? '#2E7D32' : '#B3261E')
        Text(`本次进度来源：${this.restoredLabel()}`)
          .fontSize(12 * this.fs)
          .fontColor('#6B7280')
        Text('《钟楼七点》· 鸿蒙课程作业 · 纯离线，不联网')
          .fontSize(12 * this.fs)
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
        .fontSize(14 * this.fs)
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