/** 线索卡数据（owned=false 时只显示占位与方向提示，不剧透）。 */
export class ClueCardData {
  id: string;
  name: string;
  typeLabel: string;
  desc: string;
  hint: string;
  owned: boolean;
  linked: boolean;

  constructor(id: string, name: string, typeLabel: string, desc: string, hint: string,
    owned: boolean, linked: boolean) {
    this.id = id;
    this.name = name;
    this.typeLabel = typeLabel;
    this.desc = desc;
    this.hint = hint;
    this.owned = owned;
    this.linked = linked;
  }
}

/** 线索板（01 §FR-07）：卡槽 + 两两连线 + 链进度 + 去验证。 */
@Component
export struct ClueBoardView {
  @Prop cards: ClueCardData[] = [];
  @Prop chainBText: string = '';
  @Prop chainAText: string = '';
  @Prop canDeduce: boolean = false;
  @Prop links: string[] = [];
  @State selected: string[] = [];
  @State shakeOffset: number = 0;
  @State message: string = '';

  onLink: (a: string, b: string) => void = () => {
  };
  onDeduce: () => void = () => {
  };

  private isSelected(id: string): boolean {
    return this.selected.includes(id);
  }

  private toggle(id: string): void {
    if (this.isSelected(id)) {
      this.selected = this.selected.filter((v: string) => v !== id);
      return;
    }
    if (this.selected.length >= 2) {
      this.selected = [id];
      return;
    }
    this.selected = this.selected.concat([id]);
  }

  /** 失败抖动（动画 5/6）：连错不惩罚，但要给反馈。 */
  private shake(): void {
    this.getUIContext().animateTo({ duration: 80, iterations: 3, curve: Curve.Sharp }, () => {
      this.shakeOffset = this.shakeOffset === 0 ? 8 : 0;
    });
  }

  build() {
    Column({ space: 10 }) {
      Row() {
        Text('线索板')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827')
        Blank()
        Text(`${this.cards.filter((c: ClueCardData) => c.owned).length} / ${this.cards.length}`)
          .fontSize(12)
          .fontColor('#6B7280')
      }
      .width('100%')

      Row({ space: 12 }) {
        Text(`行动线 ${this.chainBText}`)
          .fontSize(12)
          .fontColor('#4B5563')
        Text(`动机线 ${this.chainAText}`)
          .fontSize(12)
          .fontColor('#4B5563')
      }
      .width('100%')

      Text(this.message.length > 0 ? this.message : '选两张线索，点「连线」验证它们之间有没有关系。')
        .fontSize(12)
        .fontColor(this.message.length > 0 ? '#B3261E' : '#9CA3AF')

      Grid() {
        ForEach(this.cards, (card: ClueCardData) => {
          GridItem() {
            Column({ space: 4 }) {
              Text(card.owned ? card.name : '? ? ?')
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor(card.owned ? '#111827' : '#9CA3AF')
                .maxLines(1)
              Text(card.owned ? card.typeLabel : card.hint)
                .fontSize(10)
                .fontColor('#6B7280')
                .maxLines(2)
              if (card.linked) {
                Text('已连')
                  .fontSize(9)
                  .fontColor('#FFFFFF')
                  .backgroundColor('#2E7D32')
                  .padding({ left: 5, right: 5, top: 1, bottom: 1 })
                  .borderRadius(6)
              }
            }
            .width('100%')
            .height(86)
            .padding(8)
            .justifyContent(FlexAlign.Center)
            .backgroundColor(card.owned ? '#FFFFFF' : '#F3F4F6')
            .borderRadius(10)
            .border({
              width: this.isSelected(card.id) ? 2 : 1,
              color: this.isSelected(card.id) ? '#26324A' : '#E5E7EB',
            })
            .onClick(() => {
              if (!card.owned) {
                this.message = '还没拿到这条线索，先把方向提示记住。';
                this.shake();
                return;
              }
              this.toggle(card.id);
            })
          }
        }, (card: ClueCardData) => `${card.id}:${card.owned}:${card.linked}`)
      }
      .columnsTemplate('1fr 1fr 1fr')
      .rowsGap(8)
      .columnsGap(8)
      .layoutWeight(1)
      .width('100%')
      .translate({ x: this.shakeOffset })

      Row({ space: 10 }) {
        Button('连线')
          .layoutWeight(1)
          .height(42)
          .fontSize(15)
          .backgroundColor('#26324A')
          .enabled(this.selected.length === 2)
          .onClick(() => {
            if (this.selected.length !== 2) {
              return;
            }
            this.onLink(this.selected[0], this.selected[1]);
            this.selected = [];
          })
        Button('去验证')
          .layoutWeight(1)
          .height(42)
          .fontSize(15)
          .backgroundColor(this.canDeduce ? '#2E7D32' : '#E5E7EB')
          .fontColor(this.canDeduce ? '#FFFFFF' : '#9CA3AF')
          .enabled(this.canDeduce)
          .onClick(() => this.onDeduce())
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .alignItems(HorizontalAlign.Start)
  }
}
