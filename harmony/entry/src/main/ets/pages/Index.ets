import util from '@ohos.util';
import { common } from '@kit.AbilityKit';
import { CaseLoader } from '../domain/CaseLoader';
import { Engine } from '../domain/Engine';
import { CaseFile, PlayerState, Stage } from '../domain/Types';

/**
 * M1 骨架页：只验证"内容能被读到 + 引擎能算"，不做 UI。
 * M3 会把它替换为 Launch → Brief → Hub → SceneRoom 的路由结构（01 §8.1）。
 */
@Entry
@Component
struct Index {
  @State caseTitle: string = '（未加载内容）';
  @State stageText: string = '-';
  @State objective: string = '先运行 tools/sync-case.ps1 同步内容';
  @State progress: number = 0;
  @State clueText: string = '0 / 0';
  @State errors: string = '';

  aboutToAppear(): void {
    this.load();
  }

  private load(): void {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const bytes: Uint8Array = context.resourceManager.getRawFileContentSync('case/campus_001.json');
      const decoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
      const caseFile: CaseFile = CaseLoader.parse(decoder.decodeToString(bytes));

      const problems: string[] = CaseLoader.validate(caseFile);
      const state: PlayerState = Engine.initialState(caseFile);

      this.caseTitle = caseFile.title;
      this.stageText = state.stage;
      this.objective = Engine.nextObjective(state, caseFile);
      this.progress = Engine.computeProgress(state, caseFile);
      this.clueText = `${state.ownedClues.length} / ${caseFile.clues.length}`;
      this.errors = problems.length === 0 ? '内容校验通过' : problems.join('; ');
    } catch (e) {
      this.objective = '内容未同步：请在仓库根执行 tools/sync-case.ps1';
      this.errors = `${e}`;
    }
  }

  build() {
    Column({ space: 12 }) {
      Text(this.caseTitle)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
      Text(`阶段：${this.stageText}`)
        .fontSize(16)
      Text(`目标：${this.objective}`)
        .fontSize(16)
      Text(`进度：${this.progress}%`)
        .fontSize(16)
      Text(`线索：${this.clueText}`)
        .fontSize(16)
      Text(this.errors)
        .fontSize(13)
        .fontColor('#B3261E')
        .maxLines(6)
    }
    .width('100%')
    .height('100%')
    .padding(24)
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Center)
  }
}
