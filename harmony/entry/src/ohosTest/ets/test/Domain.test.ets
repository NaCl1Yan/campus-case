import { describe, it, expect } from '@ohos/hypium';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import util from '@ohos.util';
import {
  CaseFile, LogEntry, NodeState, PlayerState, Stage, Errs, ApplyOutcome,
} from '../../../main/ets/domain/Types';
import { Engine } from '../../../main/ets/domain/Engine';
import { CaseLoader } from '../../../main/ets/domain/CaseLoader';

/**
 * 鸿蒙侧引擎用例（TC 编号对应 docs/01 §10.2），与 android/domain 的 EngineTest.kt 一一对应。
 * 用例数据来自 shared/case（构建期复制到 rawfile/case）。
 */
function loadCase(): CaseFile {
  const context = abilityDelegatorRegistry.getAbilityDelegator().getAppContext();
  const bytes: Uint8Array = context.resourceManager.getRawFileContentSync('case/campus_001.json');
  const decoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
  return CaseLoader.parse(decoder.decodeToString(bytes));
}

function flagsTrue(...keys: string[]): Map<string, boolean> {
  const m = new Map<string, boolean>();
  keys.forEach((k: string) => m.set(k, true));
  return m;
}

function makeState(stage: Stage = Stage.EXPLORE,
  scenes: string[] = ['S1', 'S2', 'S3', 'S4'],
  clues: string[] = [],
  flags: Map<string, boolean> = new Map<string, boolean>(),
  closed: string[] = [],
  applied: string[] = [],
  seq: number = 0): PlayerState {
  const s = new PlayerState();
  s.stage = stage;
  s.unlockedScenes = scenes;
  s.ownedClues = clues;
  s.flags = flags;
  s.closedNodes = closed;
  s.appliedNodes = applied;
  s.seq = seq;
  return s;
}

export default function domainTest() {
  const caseFile: CaseFile = loadCase();

  describe('Engine', () => {
    it('TC-26 内容可解析且通过校验', 0, () => {
      expect(caseFile.scenes.length >= 3).assertTrue();
      expect(caseFile.nodes.length >= 12).assertTrue();
      expect(caseFile.clues.length >= 6).assertTrue();
      const errors = CaseLoader.validate(caseFile);
      expect(JSON.stringify(errors)).assertEqual('[]');
    });

    it('TC-01/02 门控顺序：closed → 场景 → 条件', 0, () => {
      const locked = makeState(Stage.EXPLORE, ['S1']);
      expect(Engine.isNodeAvailable(locked, caseFile, 'N02')).assertFalse();

      const accepted = makeState(Stage.EXPLORE, ['S1'], [], flagsTrue('accepted'));
      expect(Engine.isNodeAvailable(accepted, caseFile, 'N02')).assertTrue();
      expect(Engine.isNodeAvailable(accepted, caseFile, 'N03')).assertFalse();
    });

    it('TC-03/05 撬锁关闭 N05 且不可复活', 0, () => {
      const base = makeState(Stage.EXPLORE, ['S1', 'S2'], ['C2'], new Map<string, boolean>(), [], [], 1);
      const after: ApplyOutcome = Engine.applyNode(base, caseFile, 'N04');
      expect(after.ok).assertTrue();
      expect(after.state.closedNodes.includes('N03')).assertTrue();
      expect(after.state.closedNodes.includes('N05')).assertTrue();
      expect(after.state.flags.get('breached')).assertTrue();
      expect(Engine.isNodeAvailable(after.state, caseFile, 'N05')).assertFalse();
      expect(Engine.nodeState(after.state, caseFile, 'N05')).assertEqual(NodeState.CLOSED);
    });

    it('TC-06 重复应用幂等', 0, () => {
      const base = makeState(Stage.EXPLORE, ['S1', 'S2'], ['C2'], flagsTrue('accepted', 'ledgerChecked'),
        [], ['N02'], 3);
      const again = Engine.applyNode(base, caseFile, 'N02');
      expect(again.ok).assertTrue();
      expect(again.noop).assertTrue();
      expect(again.state.seq).assertEqual(3);
      expect(again.state.ownedClues.length).assertEqual(1);
    });

    it('TC-07 非法阶段跳转被拒且状态不变', 0, () => {
      const s = makeState(Stage.EXPLORE, ['S1', 'S2', 'S3', 'S4'], ['C1', 'C2', 'C3'],
        flagsTrue('proofA', 'proofB'), [], [], 5);
      const r = Engine.applyNode(s, caseFile, 'N12');
      expect(r.ok).assertFalse();
      expect(r.error).assertEqual(Errs.INVALID_TRANSITION);
      expect(r.state.stage).assertEqual(Stage.EXPLORE);
      expect(r.state.seq).assertEqual(5);
    });

    it('TC-08 允许的回退边', 0, () => {
      expect(Engine.canTransit(Stage.DEDUCE, Stage.EXPLORE)).assertTrue();
      expect(Engine.canTransit(Stage.JUDGE, Stage.DEDUCE)).assertTrue();
      expect(Engine.canTransit(Stage.EXPLORE, Stage.ENDING)).assertFalse();
    });

    it('TC-09/10/11 连线规则与顺序无关', 0, () => {
      const s = makeState(Stage.EXPLORE, ['S1'], ['C1', 'C2', 'C5']);
      const hit = Engine.checkCombine(s, caseFile, 'C2', 'C1');
      expect(hit.ok).assertTrue();
      expect(hit.ruleId).assertEqual('R1');
      expect(hit.grantsFlag).assertEqual('link.b1');

      const none = Engine.checkCombine(s, caseFile, 'C1', 'C5');
      expect(none.ok).assertFalse();
      expect(none.reason).assertEqual('NO_RULE');

      const notOwned = Engine.checkCombine(makeState(Stage.EXPLORE, ['S1'], ['C1']), caseFile, 'C1', 'C2');
      expect(notOwned.reason).assertEqual('NOT_OWNED');

      const afterMiss = Engine.applyCombine(s, caseFile, 'C1', 'C5');
      expect(afterMiss.seq).assertEqual(s.seq);
    });

    it('TC-13/14 单链成立时另一选项不可用', 0, () => {
      const onlyB = makeState(Stage.JUDGE, ['S1'], [], flagsTrue('proofB'));
      const availB = Engine.choiceAvailability(onlyB, caseFile);
      expect(availB.get('PUBLIC')).assertTrue();
      expect(availB.get('PRIVATE')).assertFalse();

      const onlyA = makeState(Stage.JUDGE, ['S1'], [], flagsTrue('proofA', 'tapeFound'));
      const outA = Engine.resolveEnding(onlyA, caseFile);
      expect(outA.canPublic).assertFalse();
      expect(outA.canPrivate).assertTrue();
      expect(outA.endingId).assertNull();
    });

    it('TC-15/16 两链成立由选择决定；都不成立不可进判断', 0, () => {
      const both = makeState(Stage.JUDGE, ['S1'], [], flagsTrue('proofA', 'tapeFound', 'proofB'));
      const pub = Engine.submitFinalChoice(both, caseFile, 'PUBLIC');
      expect(pub.ok).assertTrue();
      expect(Engine.resolveEnding(pub.state, caseFile).endingId).assertEqual('E-B');

      const pri = Engine.submitFinalChoice(both, caseFile, 'PRIVATE');
      expect(pri.ok).assertTrue();
      expect(Engine.resolveEnding(pri.state, caseFile).endingId).assertEqual('E-A');

      const none = makeState(Stage.DEDUCE, ['S1']);
      const enter = Engine.enterJudge(none);
      expect(enter.ok).assertFalse();
      expect(enter.error).assertEqual(Errs.CHAIN_NOT_READY);
    });

    it('TC-17/18 缺 tapeFound 与伪造选择均被拦截', 0, () => {
      const noTape = makeState(Stage.JUDGE, ['S1'], [], flagsTrue('proofA'));
      expect(Engine.canPrivate(noTape)).assertFalse();
      expect(Engine.submitFinalChoice(noTape, caseFile, 'PRIVATE').error).assertEqual(Errs.FINAL_MISMATCH);

      const forged = makeState(Stage.ENDING, ['S1'], [], new Map<string, boolean>());
      forged.finalChoice = 'PUBLIC';
      expect(Engine.resolveEnding(forged, caseFile).endingId).assertNull();
      expect(Engine.finishCase(forged, caseFile).ok).assertFalse();
    });

    it('TC-19/20 进度单调与钳制', 0, () => {
      expect(Engine.computeProgress(makeState(Stage.PROLOGUE, []), caseFile)).assertEqual(0);
      expect(Engine.computeProgress(makeState(Stage.EXPLORE, ['S1']), caseFile)).assertEqual(10);
      expect(Engine.computeProgress(makeState(Stage.EXPLORE, ['S1'], ['C1', 'C2', 'C3']), caseFile))
        .assertEqual(32.5);
      expect(Engine.computeProgress(
        makeState(Stage.EXPLORE, ['S1'], ['C1', 'C2', 'C3', 'C4', 'C5', 'C6']), caseFile)).assertEqual(55);
      expect(Engine.computeProgress(makeState(Stage.DEDUCE, ['S1'], [], flagsTrue('proofB')), caseFile))
        .assertEqual(70);
      expect(Engine.computeProgress(makeState(Stage.FINISHED, ['S1']), caseFile)).assertEqual(100);
    });

    it('TC-24/25 回放幂等、重复 seq 只生效一次', 0, () => {
      const log: LogEntry[] = [new LogEntry(1, 'N01'), new LogEntry(1, 'N01'), new LogEntry(2, 'N02')];
      const rebuilt = Engine.replay(caseFile, log);
      expect(rebuilt.seq).assertEqual(2);
      expect(JSON.stringify(rebuilt.ownedClues)).assertEqual('["C2"]');
      expect(JSON.stringify(rebuilt.appliedNodes)).assertEqual('["N01","N02"]');
      expect(rebuilt.stage).assertEqual(Stage.EXPLORE);
      expect(rebuilt.unlockedScenes.includes('S1')).assertTrue();
      expect(rebuilt.unlockedScenes.includes('S2')).assertTrue();
    });

    it('不变量：撬锁路径必然拿不到 C4', 0, () => {
      let s = Engine.initialState(caseFile);
      expect(JSON.stringify(s.unlockedScenes)).assertEqual('["S1"]');
      s = Engine.applyNode(s, caseFile, 'N01').state;
      s = Engine.applyNode(s, caseFile, 'N02').state;
      s = Engine.applyNode(s, caseFile, 'N04').state;
      expect(Engine.isNodeAvailable(s, caseFile, 'N05')).assertFalse();
      expect(s.ownedClues.includes('C4')).assertFalse();
      expect(Engine.canPrivate(s)).assertFalse();
    });

    it('AC-11 完整链路：接案 → 探索 → 判断 → 结局 A', 0, () => {
      let s = Engine.initialState(caseFile);
      s = Engine.applyNode(s, caseFile, 'N01').state;
      s = Engine.applyNode(s, caseFile, 'N02').state;
      s = Engine.applyNode(s, caseFile, 'N03').state;
      s = Engine.applyNode(s, caseFile, 'N05').state;
      s = Engine.applyNode(s, caseFile, 'N07').state;
      s = Engine.applyNode(s, caseFile, 'N09').state;
      s = Engine.applyNode(s, caseFile, 'N05').state;

      expect(JSON.stringify(s.ownedClues)).assertEqual('["C1","C2","C4","C5"]');
      expect(s.flags.get('tapeFound')).assertTrue();
      expect(s.unlockedScenes.includes('S4')).assertTrue();

      s.flags.set('proofA', true);
      s.passedStages = ['P2'];
      const judge = Engine.enterJudge(s);
      expect(judge.ok).assertTrue();
      expect(judge.state.stage).assertEqual(Stage.JUDGE);

      const submitted = Engine.submitFinalChoice(judge.state, caseFile, 'PRIVATE');
      expect(submitted.ok).assertTrue();
      expect(submitted.state.stage).assertEqual(Stage.ENDING);

      const finished = Engine.finishCase(submitted.state, caseFile);
      expect(finished.ok).assertTrue();
      expect(finished.state.stage).assertEqual(Stage.FINISHED);
      expect(finished.state.endingId).assertEqual('E-A');
      expect(Engine.computeProgress(finished.state, caseFile)).assertEqual(100);
    });
  });
}
