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
 * - 两道题可以**同时展开**（各自两排线索选项并排显示），不再是一开一合的手风琴；
 * - 每题的选择、提示等级、反馈都按题目 id 分开存，互不覆盖；
 * - 提交失败只提示，不扣分、不清选择。
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
  @State noteIds: string[] = [];
  @State noteTexts: string[] = [];
  @State noteLevels: number[] = [];

  onSubmit: (stageId: string, picked: string[]) => void = () => {
  };

  // ---------------------------------------------------------------- 每题独立状态

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

  private noteIndex(id: string): number {
    return this.noteIds.indexOf(id);
  }

  private noteOf(id: string): string {
    const i = this.noteIndex(id);
    return i >= 0 ? this.noteTexts[i] : '';
  }

  private levelOf(id: string): number {
    const i = this.noteIndex(id);
    return i >= 0 ? this.noteLevels[i] : 0;
  }

  private setNote(id: string, text: string, level: number): void {
    const i = this.noteIndex(id);
    if (i >= 0) {
      const texts: string[] = this.noteTexts.slice();
      texts[i] = text;
      this.noteTexts = texts;
      const levels: number[] = this.noteLevels.slice();
      levels[i] = level;
      this.noteLevels = levels;
      return;
    }
    this.noteIds = this.noteIds.concat([id]);
    this.noteTexts = this.noteTexts.concat([text]);
    this.noteLevels = this.noteLevels.concat([level]);
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
          Text('两道题可同时展开：每题选两条线索提交')
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
                // 线索选项固定两列，四选项正好两排同时显示
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
                      this.setNote(card.id, '已记录，看看结论对不对。', this.levelOf(card.id));
                    })
                  Button('提示')
                    .height(36)
                    .fontSize(12.5 * this.fs)
                    .backgroundColor($r('app.color.chip_bg'))
                    .fontColor($r('app.color.brand_text'))
                    .borderRadius(10)
                    .onClick(() => {
                      const level = Math.min(this.levelOf(card.id) + 1, card.hints.length);
                      const text = level > 0 ? `提示 ${level}/${card.hints.length}：${card.hints[level - 1]}` : '';
                      this.setNote(card.id, text, level);
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
                    this.setNote(card.id, '', 0);
                  })
              }

              if (this.noteOf(card.id).length > 0) {
                Text(this.noteOf(card.id))
                  .fontSize(11.5 * this.fs)
                  .lineHeight(18)
                  .fontColor($r('app.color.text_secondary'))
                  .width('100%')
                  .padding({ left: 10, right: 10, top: 8, bottom: 8 })
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
        }, (card: ProveCard) => `${card.id}:${card.passed}`)
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
