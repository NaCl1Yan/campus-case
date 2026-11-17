/** 场景卡数据（由 Index 组装，避免子组件直接依赖 controller）。 */
export class SceneCard {
  id: string;
  name: string;
  desc: string;
  locked: boolean;
  detail: string;

  constructor(id: string, name: string, desc: string, locked: boolean, detail: string) {
    this.id = id;
    this.name = name;
    this.desc = desc;
    this.locked = locked;
    this.detail = detail;
  }
}

/** 校园地图（01 §FR-03）：场景卡 + 锁定态 + 已调查进度。 */
@Component
export struct HubView {
  @Prop fs: number = 1;
  @Prop cards: SceneCard[] = [];
  onEnter: (sceneId: string) => void = () => {
  };
  onBoard: () => void = () => {
  };

  private availableCount(): number {
    return this.cards.filter((c: SceneCard) => !c.locked).length;
  }

  build() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        Column({ space: 3 }) {
          Text('校园地图')
            .fontSize(22 * this.fs)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text('点一处地点开始调查；锁住的场景需要更多现场信息')
            .fontSize(11.5 * this.fs)
            .fontColor($r('app.color.text_tertiary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text(`${this.availableCount()} / ${this.cards.length} 可去`)
          .fontSize(11.5 * this.fs)
          .fontColor($r('app.color.brand_text'))
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .backgroundColor($r('app.color.chip_bg'))
          .borderRadius(10)
      }
      .width('100%')

      List({ space: 10 }) {
        ForEach(this.cards, (card: SceneCard, index: number) => {
          ListItem() {
            Row({ space: 12 }) {
              // 序号/锁定标记
              Text(card.locked ? '—' : `${index + 1}`)
                .fontSize(12 * this.fs)
                .fontWeight(FontWeight.Bold)
                .fontColor(card.locked ? $r('app.color.text_tertiary') : $r('app.color.brand_text'))
                .width(28)
                .height(28)
                .textAlign(TextAlign.Center)
                .backgroundColor($r('app.color.chip_bg'))
                .borderRadius(14)

              Column({ space: 4 }) {
                Row() {
                  Text(card.name)
                    .fontSize(15.5 * this.fs)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(card.locked ? $r('app.color.text_tertiary') : $r('app.color.text_primary'))
                    .layoutWeight(1)
                  Text(card.locked ? '未解锁' : card.detail)
                    .fontSize(11 * this.fs)
                    .fontColor(card.locked ? $r('app.color.danger_text') : $r('app.color.text_secondary'))
                }
                .width('100%')

                Text(card.desc)
                  .fontSize(12 * this.fs)
                  .lineHeight(18)
                  .fontColor(card.locked ? $r('app.color.text_disabled') : $r('app.color.text_secondary'))
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }
            .width('100%')
            .padding({ left: 12, right: 14, top: 13, bottom: 13 })
            .backgroundColor(card.locked ? $r('app.color.surface_muted') : $r('app.color.surface'))
            .borderRadius(16)
            .border({ width: 1, color: $r('app.color.border') })
            .opacity(card.locked ? 0.85 : 1)
            .onClick(() => {
              if (!card.locked) {
                this.onEnter(card.id);
              }
            })
          }
        }, (card: SceneCard) => `${card.id}:${card.locked}:${card.detail}`)
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)

      Text('打开线索板')
        .width('100%')
        .height(46)
        .fontSize(14 * this.fs)
        .textAlign(TextAlign.Center)
        .fontColor($r('app.color.brand_text'))
        .backgroundColor($r('app.color.chip_bg'))
        .borderRadius(14)
        .onClick(() => this.onBoard())
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 8 })
    .alignItems(HorizontalAlign.Start)
  }
}
