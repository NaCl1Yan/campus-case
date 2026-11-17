import { ChainGraph, RuleEdge } from './ChainGraph';

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
  @Prop fs: number = 1;
  @Prop cards: ClueCardData[] = [];
  @Prop chainBText: string = '';
  @Prop chainAText: string = '';
  @Prop canDeduce: boolean = false;
  @Prop links: string[] = [];
  @Prop conclusions: string[] = [];
  @Prop edges: RuleEdge[] = [];
  @Prop themeKey: number = 0;
  @Prop chainBIds: string[] = [];
  @Prop chainAIds: string[] = [];
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

  /** 卡片区高度：3 列 × (86 + 8) 行距，交给外层 Scroll 滚动 */
  private gridHeight(): number {
    return Math.ceil(this.cards.length / 3) * (86 + 8);
  }

  /** 失败抖动（动画 5/6）：连错不惩罚，但要给反馈。 */
  private shake(): void {
    this.getUIContext().animateTo({ duration: 80, iterations: 3, curve: Curve.Sharp }, () => {
      this.shakeOffset = this.shakeOffset === 0 ? 8 : 0;
    });
  }

  build() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Column({ space: 2 }) {
          Text('线索板')
            .fontSize(22 * this.fs)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text('选两张线索验证关系，连对即得结论')
            .fontSize(11.5 * this.fs)
            .fontColor($r('app.color.text_tertiary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Text(`${this.cards.filter((c: ClueCardData) => c.owned).length} / ${this.cards.length}`)
          .fontSize(13 * this.fs)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.brand_text'))
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .backgroundColor($r('app.color.chip_bg'))
          .borderRadius(10)
      }
      .width('100%')

      Row({ space: 8 }) {
        Row({ space: 4 }) {
          Text('行动线')
            .fontSize(11 * this.fs)
            .fontColor($r('app.color.text_tertiary'))
          Text(this.chainBText)
            .fontSize(11.5 * this.fs)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_body'))
        }
        .padding({ left: 9, right: 9, top: 4, bottom: 4 })
        .backgroundColor($r('app.color.chip_bg'))
        .borderRadius(9)

        Row({ space: 4 }) {
          Text('动机线')
            .fontSize(11 * this.fs)
            .fontColor($r('app.color.text_tertiary'))
          Text(this.chainAText)
            .fontSize(11.5 * this.fs)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_body'))
        }
        .padding({ left: 9, right: 9, top: 4, bottom: 4 })
        .backgroundColor($r('app.color.chip_bg'))
        .borderRadius(9)
        Blank()
      }
      .width('100%')

      Text(this.message.length > 0 ? this.message : '选两张线索，点「连线」验证它们之间有没有关系。')
        .fontSize(12 * this.fs)
        .fontColor(this.message.length > 0 ? $r('app.color.danger_text') : $r('app.color.text_tertiary'))

      ChainGraph({
        edges: this.edges,
        chainBIds: this.chainBIds,
        chainAIds: this.chainAIds,
        themeKey: this.themeKey,
      })

      if (this.conclusions.length > 0) {
        Column({ space: 4 }) {
          Text('已成立的结论')
            .fontSize(12 * this.fs)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.success_text'))
          ForEach(this.conclusions, (text: string, index: number) => {
            Text(`${index + 1}. ${text}`)
              .fontSize(11 * this.fs)
              .lineHeight(18)
              .fontColor($r('app.color.text_body'))
          }, (text: string, index: number) => `${index}:${text}`)
        }
        .width('100%')
        .padding(10)
        .backgroundColor($r('app.color.success_soft'))
        .borderRadius(10)
        .alignItems(HorizontalAlign.Start)
      }

      Grid() {
        ForEach(this.cards, (card: ClueCardData) => {
          GridItem() {
            Column({ space: 4 }) {
              Text(card.owned ? card.name : '? ? ?')
                .fontSize(12.5 * this.fs)
                .fontWeight(FontWeight.Medium)
                .fontColor(card.owned ? $r('app.color.text_primary') : $r('app.color.text_tertiary'))
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(card.owned ? card.typeLabel : card.hint)
                .fontSize(10 * this.fs)
                .fontColor($r('app.color.text_secondary'))
                .maxLines(2)
              if (card.linked) {
                Text('已连')
                  .fontSize(9 * this.fs)
                  .fontColor($r('app.color.on_brand'))
                  .backgroundColor($r('app.color.success_solid'))
                  .padding({ left: 5, right: 5, top: 1, bottom: 1 })
                  .borderRadius(6)
              }
            }
            .width('100%')
            .height(90)
            .padding(8)
            .justifyContent(FlexAlign.Center)
            .backgroundColor(card.owned ? $r('app.color.surface') : $r('app.color.surface_muted'))
            .borderRadius(14)
            .border({
              width: this.isSelected(card.id) ? 2 : 1,
              color: this.isSelected(card.id) ? $r('app.color.brand_text') : $r('app.color.border'),
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
        Text(this.selected.length === 2 ? '连线' : `已选 ${this.selected.length} / 2`)
          .fontSize(14 * this.fs)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.selected.length === 2 ? $r('app.color.on_brand') : $r('app.color.text_tertiary'))
          .layoutWeight(1)
          .height(46)
          .textAlign(TextAlign.Center)
          .backgroundColor(this.selected.length === 2 ? $r('app.color.brand_solid') : $r('app.color.surface_muted'))
          .borderRadius(14)
          .onClick(() => {
            if (this.selected.length !== 2) {
              return;
            }
            this.onLink(this.selected[0], this.selected[1]);
            this.selected = [];
          })
        Text('去验证')
          .fontSize(14 * this.fs)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.canDeduce ? $r('app.color.on_brand') : $r('app.color.text_tertiary'))
          .layoutWeight(1)
          .height(46)
          .textAlign(TextAlign.Center)
          .backgroundColor(this.canDeduce ? $r('app.color.success_solid') : $r('app.color.surface_muted'))
          .borderRadius(14)
          .onClick(() => {
            if (this.canDeduce) {
              this.onDeduce();
            }
          })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 8 })
    .alignItems(HorizontalAlign.Start)
  }
}