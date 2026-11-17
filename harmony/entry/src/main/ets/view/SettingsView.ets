/** 设置页（01 §FR-15）：外观（深色模式）、动画减弱、字号缩放、清空进度、关于。 */
@Component
export struct SettingsView {
  @Prop fs: number = 1;
  @Prop reduceMotion: boolean = false;
  @Prop contentVersion: number = 1;
  @Prop validationText: string = '通过';
  @Prop fontScale: number = 1;
  @Prop restoredFrom: string = '';
  @Prop themeMode: string = 'follow';

  onToggleReduceMotion: (value: boolean) => void = () => {
  };
  onFontScale: (value: number) => void = () => {
  };
  onThemeMode: (mode: string) => void = () => {
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

  @Builder
  sectionTitle(text: string, desc: string) {
    Column({ space: 2 }) {
      Text(text)
        .fontSize(14 * this.fs)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
      if (desc.length > 0) {
        Text(desc)
          .fontSize(11 * this.fs)
          .fontColor($r('app.color.text_tertiary'))
      }
    }
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  segment(label: string, value: string, current: string, action: (v: string) => void) {
    Text(label)
      .fontSize(12.5 * this.fs)
      .fontColor(this.themeMode === value ? $r('app.color.on_brand') : $r('app.color.brand_text'))
      .layoutWeight(1)
      .height(34)
      .textAlign(TextAlign.Center)
      .backgroundColor(this.themeMode === value ? $r('app.color.brand_solid') : $r('app.color.chip_bg'))
      .borderRadius(10)
      .onClick(() => action(value))
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        Text('设置')
          .fontSize(22 * this.fs)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .width('100%')

        // 外观：深色模式（跟随系统 / 浅色 / 深色）
        Column({ space: 10 }) {
          Row({ space: 8 }) {
            this.sectionTitle('外观', '深浅色随时切换，界面配色随主题走')
            Blank()
          }
          .width('100%')

          Row({ space: 8 }) {
            this.segment('跟随系统', 'follow', this.themeMode, (v: string) => this.onThemeMode(v))
            this.segment('浅色', 'light', this.themeMode, (v: string) => this.onThemeMode(v))
            this.segment('深色', 'dark', this.themeMode, (v: string) => this.onThemeMode(v))
          }
          .width('100%')
        }
        .width('100%')
        .padding(14)
        .backgroundColor($r('app.color.surface'))
        .borderRadius(16)
        .border({ width: 1, color: $r('app.color.border') })

        // 动画
        Row({ space: 8 }) {
          this.sectionTitle('动画减弱', '关掉位移与抖动，只保留淡入（无障碍）')
          Blank()
          Toggle({ type: ToggleType.Switch, isOn: this.reduceMotion })
            .selectedColor($r('app.color.brand_solid'))
            .onChange((isOn: boolean) => this.onToggleReduceMotion(isOn))
        }
        .width('100%')
        .padding(14)
        .backgroundColor($r('app.color.surface'))
        .borderRadius(16)
        .border({ width: 1, color: $r('app.color.border') })

        // 字号
        Column({ space: 10 }) {
          this.sectionTitle('字号缩放', '影响界面文字大小（1.0 / 1.2 / 1.5）')
          Row({ space: 8 }) {
            ForEach([1, 1.2, 1.5], (value: number) => {
              Text(value === 1 ? '标准' : (value === 1.2 ? '大' : '特大'))
                .fontSize(12.5 * this.fs)
                .fontColor(this.fontScale === value ? $r('app.color.on_brand') : $r('app.color.brand_text'))
                .layoutWeight(1)
                .height(34)
                .textAlign(TextAlign.Center)
                .backgroundColor(this.fontScale === value ? $r('app.color.brand_solid') : $r('app.color.chip_bg'))
                .borderRadius(10)
                .onClick(() => this.onFontScale(value))
            }, (value: number) => `${value}`)
          }
          .width('100%')
        }
        .width('100%')
        .padding(14)
        .backgroundColor($r('app.color.surface'))
        .borderRadius(16)
        .border({ width: 1, color: $r('app.color.border') })
        .alignItems(HorizontalAlign.Start)

        // 关于
        Column({ space: 6 }) {
          Text('关于')
            .fontSize(14 * this.fs)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
          Text(`内容版本 v${this.contentVersion} · 内容校验：${this.validationText}`)
            .fontSize(12 * this.fs)
            .fontColor(this.validationText === '通过' ? $r('app.color.success_text') : $r('app.color.danger_text'))
          Text(`本次进度来源：${this.restoredLabel()}`)
            .fontSize(12 * this.fs)
            .fontColor($r('app.color.text_secondary'))
          Text('《钟楼七点》· 鸿蒙课程作业 · 纯离线，不联网')
            .fontSize(12 * this.fs)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .padding(14)
        .backgroundColor($r('app.color.surface'))
        .borderRadius(16)
        .border({ width: 1, color: $r('app.color.border') })
        .alignItems(HorizontalAlign.Start)

        Button('清空本局进度（保留存档槽）')
          .width('100%')
          .height(46)
          .fontSize(14 * this.fs)
          .backgroundColor($r('app.color.surface'))
          .fontColor($r('app.color.danger_text'))
          .borderRadius(14)
          .border({ width: 1, color: $r('app.color.danger_soft_border') })
          .onClick(() => this.onClearProgress())

        Blank().height(8)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 16 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
  }
}
