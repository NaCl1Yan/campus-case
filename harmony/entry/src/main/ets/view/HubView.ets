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
  @Prop cards: SceneCard[] = [];
  onEnter: (sceneId: string) => void = () => {
  };
  onBoard: () => void = () => {
  };

  build() {
    Column({ space: 12 }) {
      Text('校园地图')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#111827')
      Text('点一个去处。锁住的场景需要更多现场信息。')
        .fontSize(12)
        .fontColor('#9CA3AF')

      List({ space: 12 }) {
        ForEach(this.cards, (card: SceneCard) => {
          ListItem() {
            Column({ space: 6 }) {
              Row() {
                Text(card.name)
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(card.locked ? '#9CA3AF' : '#111827')
                Blank()
                Text(card.locked ? '未解锁' : card.detail)
                  .fontSize(11)
                  .fontColor(card.locked ? '#B3261E' : '#4B5563')
              }
              .width('100%')

              Text(card.desc)
                .fontSize(12)
                .fontColor(card.locked ? '#BDBDBD' : '#6B7280')
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .width('100%')
            .padding(14)
            .backgroundColor(card.locked ? '#F3F4F6' : '#FFFFFF')
            .borderRadius(12)
            .border({ width: 1, color: '#E5E7EB' })
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

      Button('打开线索板')
        .width('100%')
        .height(44)
        .fontSize(15)
        .backgroundColor('#EEF2F7')
        .fontColor('#26324A')
        .onClick(() => this.onBoard())
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .alignItems(HorizontalAlign.Start)
  }
}
