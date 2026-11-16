import { abilityDelegatorRegistry } from '@kit.TestKit';
import util from '@ohos.util';
import { CaseFile, PlayerState, Stage } from '../../../main/ets/domain/Types';
import { CaseLoader } from '../../../main/ets/domain/CaseLoader';
import { FlagPair, StateExpect, StatePatch } from './Fixtures.generated';

/**
 * 测试公共支撑：读 rawfile 内容、把生成的用例态转成 PlayerState、部分匹配断言。
 * 只被 ohosTest 使用，不进主包。
 */

let cachedCase: CaseFile | null = null;

export function loadCase(): CaseFile {
  if (cachedCase !== null) {
    return cachedCase;
  }
  const context = abilityDelegatorRegistry.getAbilityDelegator().getAppContext();
  const bytes: Uint8Array = context.resourceManager.getRawFileContentSync('case/campus_001.json');
  const decoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
  const caseFile = CaseLoader.parse(decoder.decodeToString(bytes));
  cachedCase = caseFile;
  return caseFile;
}

export function toStage(name: string): Stage {
  switch (name) {
    case 'PROLOGUE':
      return Stage.PROLOGUE;
    case 'ACCEPT':
      return Stage.ACCEPT;
    case 'EXPLORE':
      return Stage.EXPLORE;
    case 'DEDUCE':
      return Stage.DEDUCE;
    case 'JUDGE':
      return Stage.JUDGE;
    case 'ENDING':
      return Stage.ENDING;
    case 'FINISHED':
      return Stage.FINISHED;
    default:
      return Stage.PROLOGUE;
  }
}

export function stateFromPatch(patch: StatePatch): PlayerState {
  const s = new PlayerState();
  s.stage = toStage(patch.stage);
  s.unlockedScenes = patch.unlockedScenes.slice();
  s.ownedClues = patch.ownedClues.slice();
  const flags = new Map<string, boolean>();
  patch.flags.forEach((pair: FlagPair) => {
    flags.set(pair.key, pair.value);
  });
  s.flags = flags;
  s.closedNodes = patch.closedNodes.slice();
  s.appliedNodes = patch.appliedNodes.slice();
  s.seq = patch.seq;
  s.finalChoice = patch.finalChoice;
  s.endingId = patch.endingId;
  return s;
}

function sameSet(a: string[], b: string[]): boolean {
  return a.slice().sort().join('|') === b.slice().sort().join('|');
}

/** 部分匹配：只比较 expect 里出现过的字段（与 Kotlin FixtureTest 语义一致）。 */
export function diffState(actual: PlayerState, expect: StateExpect): string[] {
  const out: string[] = [];

  if (expect.stage !== undefined && actual.stage !== toStage(expect.stage)) {
    out.push(`stage 期望 ${expect.stage} 实际 ${actual.stage}`);
  }
  if (expect.seq !== undefined && actual.seq !== expect.seq) {
    out.push(`seq 期望 ${expect.seq} 实际 ${actual.seq}`);
  }
  if (expect.unlockedScenes !== undefined && !sameSet(actual.unlockedScenes, expect.unlockedScenes)) {
    out.push(`unlockedScenes 期望 ${JSON.stringify(expect.unlockedScenes)} 实际 ${JSON.stringify(actual.unlockedScenes)}`);
  }
  if (expect.ownedClues !== undefined && !sameSet(actual.ownedClues, expect.ownedClues)) {
    out.push(`ownedClues 期望 ${JSON.stringify(expect.ownedClues)} 实际 ${JSON.stringify(actual.ownedClues)}`);
  }
  if (expect.closedNodes !== undefined && !sameSet(actual.closedNodes, expect.closedNodes)) {
    out.push(`closedNodes 期望 ${JSON.stringify(expect.closedNodes)} 实际 ${JSON.stringify(actual.closedNodes)}`);
  }
  if (expect.appliedNodes !== undefined && !sameSet(actual.appliedNodes, expect.appliedNodes)) {
    out.push(`appliedNodes 期望 ${JSON.stringify(expect.appliedNodes)} 实际 ${JSON.stringify(actual.appliedNodes)}`);
  }
  if (expect.flags !== undefined) {
    expect.flags.forEach((pair: FlagPair) => {
      if (actual.flags.get(pair.key) !== pair.value) {
        out.push(`flags.${pair.key} 期望 ${pair.value} 实际 ${actual.flags.get(pair.key)}`);
      }
    });
  }
  if (expect.finalChoice !== undefined && actual.finalChoice !== expect.finalChoice) {
    out.push(`finalChoice 期望 ${expect.finalChoice} 实际 ${actual.finalChoice}`);
  }
  if (expect.endingId !== undefined && actual.endingId !== expect.endingId) {
    out.push(`endingId 期望 ${expect.endingId} 实际 ${actual.endingId}`);
  }
  return out;
}
