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

/** 场景内（01 §FR-03/05）：热点列表 + 打字机正文 + 已调查/已封锁可见。 */
@Component
export struct SceneView {
  @Prop sceneName: string = '';
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

  private stateColor(state: string): string {
    if (state === 'AVAILABLE') {
      return '#26324A';
    }
    if (state === 'DONE') {
      return '#6B7280';
    }
    if (state === 'CLOSED') {
      return '#B3261E';
    }
    return '#9CA3AF';
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
    Column({ space: 10 }) {
      Text(this.sceneName)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#111827')
      Text(this.sceneDesc)
        .fontSize(12)
        .fontColor('#6B7280')

      if (this.bodyTitle.length > 0) {
        Column({ space: 6 }) {
          Text(this.bodyTitle)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#26324A')
          Text(this.shown)
            .fontSize(13)
            .lineHeight(21)
            .fontColor('#374151')
        }
        .width('100%')
        .padding(12)
        .backgroundColor('#FFFFFF')
        .borderRadius(10)
        .border({ width: 1, color: '#E5E7EB' })
        .transition(TransitionEffect.OPACITY.animation({ duration: 220 }))
      }

      Text('可调查的地方')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('#26324A')

      List({ space: 10 }) {
        ForEach(this.hotspots, (item: HotspotItem) => {
          ListItem() {
            Row() {
              Text(item.title)
                .fontSize(14)
                .fontColor(this.stateColor(item.state))
                .layoutWeight(1)
              Text(this.stateLabel(item.state))
                .fontSize(11)
                .fontColor(this.stateColor(item.state))
            }
            .width('100%')
            .padding(14)
            .backgroundColor(item.done ? '#F3F4F6' : '#FFFFFF')
            .borderRadius(10)
            .border({ width: 1, color: '#E5E7EB' })
            .onClick(() => {
              this.onTap(item.nodeId);
            })
          }
        }, (item: HotspotItem) => `${item.nodeId}:${item.state}`)
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .alignItems(HorizontalAlign.Start)
    .translate({ x: this.shaking ? 6 : 0 })
  }
}
