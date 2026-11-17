/** 推理关卡卡数据。 */
export class ProveCard {
  id: string;
  question: string;
  answerHint: string;
  passed: boolean;
  hints: string[];
  pool: string[];

  constructor(id: string, question: string, answerHint: string, passed: boolean, hints: string[],
    pool: string[]) {
    this.id = id;
    this.question = question;
    this.answerHint = answerHint;
    this.passed = passed;
    this.hints = hints;
    this.pool = pool;
  }
}

/** 推理工坊（01 §FR-08）：每题选两条线索提交，错不惩罚、提示逐级解锁。 */
@Component
export struct DeduceView {
  @Prop fs: number = 1;
  @Prop cards: ProveCard[] = [];
  @Prop clueNames: string[] = [];
  @Prop clueIds: string[] = [];
  @State active: string = '';
  @State picked: string[] = [];
  @State feedback: string = '';
  @State hintLevel: number = 0;

  onSubmit: (stageId: string, picked: string[]) => void = () => {
  };

  private toggle(id: string): void {
    if (this.picked.includes(id)) {
      this.picked = this.picked.filter((v: string) => v !== id);
      return;
    }
    if (this.picked.length >= 2) {
      this.picked = [id];
      return;
    }
    this.picked = this.picked.concat([id]);
  }

  private clueName(id: string): string {
    const index = this.clueIds.indexOf(id);
    return index >= 0 ? this.clueNames[index] : id;
  }

  build() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        Column({ space: 3 }) {
          Text('推理工坊')
            .fontSize(22 * this.fs)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text('证据不会自己说话：选两条线索放进这一问')
            .fontSize(11.5 * this.fs)
            .fontColor($r('app.color.text_tertiary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Text(`${this.cards.filter((c: ProveCard) => c.passed).length} / ${this.cards.length} 已通过`)
          .fontSize(11.5 * this.fs)
          .fontColor($r('app.color.brand_text'))
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .backgroundColor($r('app.color.chip_bg'))
          .borderRadius(10)
      }
      .width('100%')

      List({ space: 12 }) {
        ForEach(this.cards, (card: ProveCard) => {
          ListItem() {
            Column({ space: 8 }) {
              Row() {
                Text(card.question)
                  .fontSize(14 * this.fs)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)
                Text(card.passed ? '已通过' : '待验证')
                  .fontSize(10.5 * this.fs)
                  .fontColor(card.passed ? $r('app.color.on_brand') : $r('app.color.brand_text'))
                  .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                  .backgroundColor(card.passed ? $r('app.color.success_solid') : $r('app.color.chip_bg'))
                  .borderRadius(8)
              }
              .width('100%')

              if (this.active === card.id && !card.passed) {
                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(card.pool, (clueId: string) => {
                    Text(this.clueName(clueId))
                      .fontSize(12 * this.fs)
                      .fontColor(this.picked.includes(clueId) ? $r('app.color.on_brand') : $r('app.color.brand_text'))
                      .backgroundColor(this.picked.includes(clueId) ? $r('app.color.brand_solid') : $r('app.color.chip_bg'))
                      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                      .borderRadius(14)
                      .margin(4)
                      .onClick(() => this.toggle(clueId))
                  }, (clueId: string) => clueId)
                }
                .width('100%')

                Row({ space: 8 }) {
                  Button(this.picked.length === 2 ? '提交这一问' : `已选 ${this.picked.length} / 2`)
                    .height(36)
                    .fontSize(12.5 * this.fs)
                    .fontColor(this.picked.length === 2 ? $r('app.color.on_brand') : $r('app.color.text_tertiary'))
                    .backgroundColor(this.picked.length === 2 ? $r('app.color.brand_solid') : $r('app.color.surface_muted'))
                    .borderRadius(10)
                    .enabled(this.picked.length === 2)
                    .onClick(() => {
                      this.onSubmit(card.id, this.picked);
                      this.feedback = '已提交，看看结论对不对。';
                    })
                  Button('提示')
                    .height(36)
                    .fontSize(12.5 * this.fs)
                    .backgroundColor($r('app.color.chip_bg'))
                    .fontColor($r('app.color.brand_text'))
                    .borderRadius(10)
                    .onClick(() => {
                      const level = Math.min(this.hintLevel + 1, card.hints.length);
                      this.hintLevel = level;
                      this.feedback = level > 0 ? `提示 ${level}：${card.hints[level - 1]}` : '';
                    })
                }
                .width('100%')
              } else if (card.passed) {
                Text(`结论：${card.answerHint}`)
                  .fontSize(12 * this.fs)
                  .fontColor($r('app.color.success_text'))
                  .lineHeight(19)
              } else {
                Button('开始这一问')
                  .height(36)
                  .fontSize(12.5 * this.fs)
                  .backgroundColor($r('app.color.chip_bg'))
                  .fontColor($r('app.color.brand_text'))
                  .borderRadius(10)
                  .onClick(() => {
                    this.active = card.id;
                    this.picked = [];
                    this.feedback = '';
                    this.hintLevel = 0;
                  })
              }

              if (this.feedback.length > 0 && this.active === card.id) {
                Text(this.feedback)
                  .fontSize(11 * this.fs)
                  .fontColor($r('app.color.text_secondary'))
              }
            }
            .width('100%')
            .padding(15)
            .backgroundColor($r('app.color.surface'))
            .borderRadius(16)
            .border({ width: 1, color: $r('app.color.border') })
          }
        }, (card: ProveCard) => `${card.id}:${card.passed}`)
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 8 })
    .alignItems(HorizontalAlign.Start)
  }
}