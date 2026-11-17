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
      Text('推理工坊')
        .fontSize(20 * this.fs)
        .fontWeight(FontWeight.Bold)
        .fontColor('#111827')
      Text('证据不会自己说话。选两条线索，把它们放进这一问里。')
        .fontSize(12 * this.fs)
        .fontColor('#9CA3AF')

      List({ space: 12 }) {
        ForEach(this.cards, (card: ProveCard) => {
          ListItem() {
            Column({ space: 8 }) {
              Row() {
                Text(card.question)
                  .fontSize(14 * this.fs)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#111827')
                  .layoutWeight(1)
                Text(card.passed ? '已通过' : '待验证')
                  .fontSize(11 * this.fs)
                  .fontColor(card.passed ? '#2E7D32' : '#B3261E')
              }
              .width('100%')

              if (this.active === card.id && !card.passed) {
                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(card.pool, (clueId: string) => {
                    Text(this.clueName(clueId))
                      .fontSize(12 * this.fs)
                      .fontColor(this.picked.includes(clueId) ? '#FFFFFF' : '#26324A')
                      .backgroundColor(this.picked.includes(clueId) ? '#26324A' : '#EEF2F7')
                      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                      .borderRadius(14)
                      .margin(4)
                      .onClick(() => this.toggle(clueId))
                  }, (clueId: string) => clueId)
                }
                .width('100%')

                Row({ space: 8 }) {
                  Button('提交')
                    .height(34)
                    .fontSize(13 * this.fs)
                    .backgroundColor('#26324A')
                    .enabled(this.picked.length === 2)
                    .onClick(() => {
                      this.onSubmit(card.id, this.picked);
                      this.feedback = '已提交，看看结论对不对。';
                    })
                  Button('提示')
                    .height(34)
                    .fontSize(13 * this.fs)
                    .backgroundColor('#EEF2F7')
                    .fontColor('#26324A')
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
                  .fontColor('#2E7D32')
                  .lineHeight(19)
              } else {
                Button('开始这一问')
                  .height(34)
                  .fontSize(13 * this.fs)
                  .backgroundColor('#EEF2F7')
                  .fontColor('#26324A')
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
                  .fontColor('#6B7280')
              }
            }
            .width('100%')
            .padding(14)
            .backgroundColor('#FFFFFF')
            .borderRadius(12)
            .border({ width: 1, color: '#E5E7EB' })
          }
        }, (card: ProveCard) => `${card.id}:${card.passed}`)
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .alignItems(HorizontalAlign.Start)
  }
}