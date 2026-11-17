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

/**
 * 推理工坊（01 §FR-08）：每题选两条线索提交，错不惩罚、提示逐级解锁。
 *
 * 交互约定：
 * - 两道题可以**同时展开**，各自两列线索网格；
 * - 每题的选择独立；
 * - 提示**累积展示**：点了 2 次就把「提示 1」和「提示 2」同时列出来，不是只显示最后一条；
 * - 提交反馈与提示分开显示，互不覆盖。
 */
@Component
export struct DeduceView {
  @Prop fs: number = 1;
  @Prop cards: ProveCard[] = [];
  @Prop clueNames: string[] = [];
  @Prop clueIds: string[] = [];

  @State activeIds: string[] = [];
  @State pickedCardIds: string[] = [];
  @State pickedLists: string[][] = [];
  // 每题已解锁到第几条提示
  @State hintCardIds: string[] = [];
  @State hintLevels: number[] = [];
  // 每题最近一次提交的反馈
  @State feedbackCardIds: string[] = [];
  @State feedbackTexts: string[] = [];

  onSubmit: (stageId: string, picked: string[]) => void = () => {
  };

  // ---------------------------------------------------------------- 展开 / 选择

  private isActive(cardId: string): boolean {
    return this.activeIds.includes(cardId);
  }

  private toggleOpen(cardId: string): void {
    if (this.isActive(cardId)) {
      this.activeIds = this.activeIds.filter((v: string) => v !== cardId);
    } else {
      this.activeIds = this.activeIds.concat([cardId]);
    }
  }

  private pickedOf(cardId: string): string[] {
    const i = this.pickedCardIds.indexOf(cardId);
    return i >= 0 ? this.pickedLists[i] : [];
  }

  private setPicked(cardId: string, list: string[]): void {
    const i = this.pickedCardIds.indexOf(cardId);
    if (i >= 0) {
      const all: string[][] = this.pickedLists.slice();
      all[i] = list;
      this.pickedLists = all;
      return;
    }
    this.pickedCardIds = this.pickedCardIds.concat([cardId]);
    this.pickedLists = this.pickedLists.concat([list]);
  }

  private toggleClue(cardId: string, clueId: string): void {
    const current: string[] = this.pickedOf(cardId);
    if (current.includes(clueId)) {
      this.setPicked(cardId, current.filter((v: string) => v !== clueId));
      return;
    }
    if (current.length >= 2) {
      this.setPicked(cardId, [clueId]);
      return;
    }
    this.setPicked(cardId, current.concat([clueId]));
  }

  // ---------------------------------------------------------------- 提示 / 反馈

  private levelOf(cardId: string): number {
    const i = this.hintCardIds.indexOf(cardId);
    return i >= 0 ? this.hintLevels[i] : 0;
  }

  private setLevel(cardId: string, level: number): void {
    const i = this.hintCardIds.indexOf(cardId);
    if (i >= 0) {
      const levels: number[] = this.hintLevels.slice();
      levels[i] = level;
      this.hintLevels = levels;
      return;
    }
    this.hintCardIds = this.hintCardIds.concat([cardId]);
    this.hintLevels = this.hintLevels.concat([level]);
  }

  private feedbackOf(cardId: string): string {
    const i = this.feedbackCardIds.indexOf(cardId);
    return i >= 0 ? this.feedbackTexts[i] : '';
  }

  private setFeedback(cardId: string, text: string): void {
    const i = this.feedbackCardIds.indexOf(cardId);
    if (i >= 0) {
      const texts: string[] = this.feedbackTexts.slice();
      texts[i] = text;
      this.feedbackTexts = texts;
      return;
    }
    this.feedbackCardIds = this.feedbackCardIds.concat([cardId]);
    this.feedbackTexts = this.feedbackTexts.concat([text]);
  }

  private revealedHints(card: ProveCard): string[] {
    const level = this.levelOf(card.id);
    return card.hints.slice(0, level);
  }

  private clueName(id: string): string {
    const index = this.clueIds.indexOf(id);
    return index >= 0 ? this.clueNames[index] : id;
  }

  private gridHeight(card: ProveCard): number {
    const rows = Math.ceil(card.pool.length / 2);
    return rows * 40 + Math.max(0, rows - 1) * 8;
  }

  build() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        Column({ space: 3 }) {
          Text('推理工坊')
            .fontSize(22 * this.fs)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text('两题可同时展开；提示会累计显示，点几次留几条')
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
            Column({ space: 10 }) {
              Row() {
                Text(card.question)
                  .fontSize(14.5 * this.fs)
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

              if (this.isActive(card.id) && !card.passed) {
                Grid() {
                  ForEach(card.pool, (clueId: string) => {
                    GridItem() {
                      Text(this.clueName(clueId))
                        .fontSize(12 * this.fs)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .fontColor(this.pickedOf(card.id).includes(clueId)
                          ? $r('app.color.on_brand') : $r('app.color.brand_text'))
                        .backgroundColor(this.pickedOf(card.id).includes(clueId)
                          ? $r('app.color.brand_solid') : $r('app.color.chip_bg'))
                        .width('100%')
                        .height(38)
                        .textAlign(TextAlign.Center)
                        .borderRadius(12)
                        .onClick(() => this.toggleClue(card.id, clueId))
                    }
                  }, (clueId: string) => `${card.id}:${clueId}`)
                }
                .columnsTemplate('1fr 1fr')
                .rowsGap(8)
                .columnsGap(8)
                .height(this.gridHeight(card))
                .width('100%')

                Row({ space: 8 }) {
                  Button(this.pickedOf(card.id).length === 2 ? '提交' : `已选 ${this.pickedOf(card.id).length} / 2`)
                    .height(36)
                    .fontSize(12.5 * this.fs)
                    .fontColor(this.pickedOf(card.id).length === 2
                      ? $r('app.color.on_brand') : $r('app.color.text_tertiary'))
                    .backgroundColor(this.pickedOf(card.id).length === 2
                      ? $r('app.color.brand_solid') : $r('app.color.surface_muted'))
                    .borderRadius(10)
                    .enabled(this.pickedOf(card.id).length === 2)
                    .onClick(() => {
                      this.onSubmit(card.id, this.pickedOf(card.id));
                      this.setFeedback(card.id, '已记录，看看结论对不对。');
                    })
                  Button('提示')
                    .height(36)
                    .fontSize(12.5 * this.fs)
                    .backgroundColor($r('app.color.chip_bg'))
                    .fontColor(this.levelOf(card.id) >= card.hints.length
                      ? $r('app.color.text_tertiary') : $r('app.color.brand_text'))
                    .borderRadius(10)
                    .enabled(this.levelOf(card.id) < card.hints.length)
                    .onClick(() => {
                      const next = Math.min(this.levelOf(card.id) + 1, card.hints.length);
                      this.setLevel(card.id, next);
                    })
                  Button('收起')
                    .height(36)
                    .fontSize(12.5 * this.fs)
                    .backgroundColor($r('app.color.chip_bg'))
                    .fontColor($r('app.color.text_secondary'))
                    .borderRadius(10)
                    .onClick(() => this.toggleOpen(card.id))
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
                    this.toggleOpen(card.id);
                    this.setLevel(card.id, 0);
                    this.setFeedback(card.id, '');
                  })
              }

              // 已解锁的提示逐条列出（累积，不覆盖）
              if (this.revealedHints(card).length > 0) {
                Column({ space: 4 }) {
                  ForEach(this.revealedHints(card), (hint: string, index: number) => {
                    Text(`提示 ${index + 1}/${card.hints.length}：${hint}`)
                      .fontSize(11.5 * this.fs)
                      .lineHeight(18)
                      .width('100%')
                      .fontColor($r('app.color.text_body'))
                  }, (hint: string, index: number) => `${card.id}:${index}`)
                }
                .width('100%')
                .padding({ left: 10, right: 10, top: 8, bottom: 8 })
                .backgroundColor($r('app.color.surface_alt'))
                .borderRadius(10)
                .alignItems(HorizontalAlign.Start)
              }

              if (this.feedbackOf(card.id).length > 0) {
                Text(this.feedbackOf(card.id))
                  .fontSize(11.5 * this.fs)
                  .fontColor($r('app.color.text_secondary'))
                  .width('100%')
                  .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                  .backgroundColor($r('app.color.surface_alt'))
                  .borderRadius(10)
              }
            }
            .width('100%')
            .padding(15)
            .backgroundColor($r('app.color.surface'))
            .borderRadius(16)
            .border({ width: 1, color: $r('app.color.border') })
          }
        }, (card: ProveCard) => `${card.id}:${card.passed}:${this.levelOf(card.id)}`)
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 8 })
    .alignItems(HorizontalAlign.Start)
  }
}
