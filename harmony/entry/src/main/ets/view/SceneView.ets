/** 热点数据（id / 标题 / 状态 / 提示）。 */
export class HotspotItem {
  nodeId: string;
  title: string;
  state: string;
  hint: string;
  done: boolean;

  constructor(nodeId: string, title: string, state: string, hint: string, done: boolean) {
    this.nodeId = nodeId;
    this.title = title;
    this.state = state;
    this.hint = hint;
    this.done = done;
  }
}

/** 场景内（01 §FR-03/05）：氛围色带 + 热点卡片 + 打字机正文 + 已调查/已封锁可见。 */
@Component
export struct SceneView {
  @Prop fs: number = 1;
  @Prop sceneName: string = '';
  @Prop sceneFx: string = 'warm';
  @Prop sceneDesc: string = '';
  @Prop hotspots: HotspotItem[] = [];
  @Prop bodyText: string = '';
  @Prop bodyTitle: string = '';

  @State shown: string = '';
  @State shaking: boolean = false;
  private timer: number = -1;

  onTap: (nodeId: string) => void = () => {
  };

  aboutToAppear(): void {
    this.startTypewriter();
  }

  aboutToDisappear(): void {
    if (this.timer !== -1) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  /** 打字机（动画 6/6）：逐字显示节点正文，离开页面必须清定时器。 */
  private startTypewriter(): void {
    if (this.timer !== -1) {
      clearInterval(this.timer);
      this.timer = -1;
    }
    const full = this.bodyText;
    this.shown = '';
    if (full.length === 0) {
      return;
    }
    let index = 0;
    this.timer = setInterval(() => {
      index += 2;
      if (index >= full.length) {
        this.shown = full;
        if (this.timer !== -1) {
          clearInterval(this.timer);
          this.timer = -1;
        }
      } else {
        this.shown = full.substring(0, index);
      }
    }, 24);
  }

  /** 场景氛围色（warm/cold/neon/dim），替代美术背景；深浅色由资源自动切换。 */
  private fxColor(): ResourceColor {
    if (this.sceneFx === 'cold') {
      return $r('app.color.cool_soft');
    }
    if (this.sceneFx === 'neon') {
      return $r('app.color.calm_soft');
    }
    if (this.sceneFx === 'dim') {
      return $r('app.color.neutral_soft');
    }
    return $r('app.color.warm_soft');
  }

  private stateColor(state: string): ResourceColor {
    if (state === 'AVAILABLE') {
      return $r('app.color.brand_text');
    }
    if (state === 'DONE') {
      return $r('app.color.text_secondary');
    }
    if (state === 'CLOSED') {
      return $r('app.color.danger_text');
    }
    return $r('app.color.text_tertiary');
  }

  private stateLabel(state: string): string {
    if (state === 'AVAILABLE') {
      return '可调查';
    }
    if (state === 'DONE') {
      return '已调查';
    }
    if (state === 'CLOSED') {
      return '已封锁';
    }
    return '未解锁';
  }

  build() {
    Column({ space: 12 }) {
      // 场景头部：标题 + 氛围色带
      Column({ space: 6 }) {
        Row({ space: 8 }) {
          Text('场景')
            .fontSize(11 * this.fs)
            .fontColor($r('app.color.text_tertiary'))
            .letterSpacing(1)
          Blank()
          Row({ space: 4 }) {
            Text(`${this.hotspots.filter((h: HotspotItem) => h.done).length}`)
              .fontSize(12 * this.fs)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.brand_text'))
            Text(`/ ${this.hotspots.length} 已调查`)
              .fontSize(11 * this.fs)
              .fontColor($r('app.color.text_tertiary'))
          }
        }
        .width('100%')

        Text(this.sceneName)
          .fontSize(22 * this.fs)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text(this.sceneDesc)
          .fontSize(12.5 * this.fs)
          .lineHeight(19)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 12, bottom: 14 })
      .backgroundColor(this.fxColor())
      .borderRadius(16)
      .alignItems(HorizontalAlign.Start)

      if (this.bodyTitle.length > 0) {
        Column({ space: 6 }) {
          Text(this.bodyTitle)
            .fontSize(14 * this.fs)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.brand_text'))
          Text(this.shown)
            .fontSize(13 * this.fs)
            .lineHeight(22)
            .fontColor($r('app.color.text_body'))
        }
        .width('100%')
        .padding(14)
        .backgroundColor($r('app.color.surface'))
        .borderRadius(16)
        .border({ width: 1, color: $r('app.color.border') })
        .alignItems(HorizontalAlign.Start)
        .transition(TransitionEffect.OPACITY.animation({ duration: 220 }))
      }

      Row() {
        Text('可调查的地方')
          .fontSize(13 * this.fs)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Text('点一下开始调查')
          .fontSize(11 * this.fs)
          .fontColor($r('app.color.text_tertiary'))
      }
      .width('100%')

      List({ space: 10 }) {
        ForEach(this.hotspots, (item: HotspotItem) => {
          ListItem() {
            Row({ space: 10 }) {
              Column({ space: 3 }) {
                Text(item.title)
                  .fontSize(14.5 * this.fs)
                  .fontWeight(item.done ? FontWeight.Normal : FontWeight.Medium)
                  .fontColor(this.stateColor(item.state))
                Text(item.hint)
                  .fontSize(11 * this.fs)
                  .fontColor($r('app.color.text_tertiary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Text(this.stateLabel(item.state))
                .fontSize(11 * this.fs)
                .fontColor(this.stateColor(item.state))
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                .backgroundColor($r('app.color.chip_bg'))
                .borderRadius(8)
            }
            .width('100%')
            .padding({ left: 14, right: 12, top: 12, bottom: 12 })
            .backgroundColor(item.done ? $r('app.color.surface_muted') : $r('app.color.surface'))
            .borderRadius(14)
            .border({ width: 1, color: $r('app.color.border') })
            .onClick(() => {
              this.onTap(item.nodeId);
            })
          }
        }, (item: HotspotItem) => `${item.nodeId}:${item.state}`)
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 8 })
    .alignItems(HorizontalAlign.Start)
    .translate({ x: this.shaking ? 6 : 0 })
  }
}
