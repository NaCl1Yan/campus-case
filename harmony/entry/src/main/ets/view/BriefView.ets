import { CaseFile } from '../domain/Types';

/** 案件简报（01 §FR-02）：交代委托人、目标、已知时间线，接案进入探索。 */
@Component
export struct BriefView {
  @Prop title: string = '';
  @Prop subtitle: string = '';
  @Prop client: string = '';
  @Prop summary: string = '';
  @Prop objectives: string[] = [];
  @Prop timeline: string[] = [];
  @Prop accepted: boolean = false;

  onAccept: () => void = () => {
  };
  onEnter: () => void = () => {
  };

  build() {
    Column({ space: 12 }) {
      Text(this.title)
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor('#111827')
      Text(this.subtitle)
        .fontSize(14)
        .fontColor('#6B7280')

      Row() {
        Text('委托人')
          .fontSize(12)
          .fontColor('#9CA3AF')
          .width(58)
        Text(this.client)
          .fontSize(13)
          .fontColor('#374151')
          .layoutWeight(1)
      }

      Text(this.summary)
        .fontSize(14)
        .lineHeight(22)
        .fontColor('#374151')

      Divider().color('#E5E7EB')

      Text('调查目标')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('#26324A')
      ForEach(this.objectives, (item: string, index: number) => {
        Text(`${index + 1}. ${item}`)
          .fontSize(13)
          .fontColor('#4B5563')
      })

      Text('已知时间线')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('#26324A')
      ForEach(this.timeline, (item: string) => {
        Text(item)
          .fontSize(12)
          .fontColor('#6B7280')
      })

      Blank()

      if (!this.accepted) {
        Button('接下这桩案子')
          .width('100%')
          .height(46)
          .fontSize(16)
          .backgroundColor('#26324A')
          .onClick(() => this.onAccept())
      } else {
        Button('回到校园地图')
          .width('100%')
          .height(46)
          .fontSize(16)
          .backgroundColor('#26324A')
          .onClick(() => this.onEnter())
      }
    }
    .width('100%')
    .height('100%')
    .padding(20)
    .alignItems(HorizontalAlign.Start)
  }
}
