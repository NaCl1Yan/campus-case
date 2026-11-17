import { describe, it, expect } from '@ohos/hypium';
import { Engine } from '../../../main/ets/domain/Engine';
import { LogEntry, SceneDef } from '../../../main/ets/domain/Types';
import {
  APPLY_CASES, ApplyCase, COMBINE_CASES, CombineCase, ENDING_CASES, EndingCase,
  FIXTURE_TOTAL, GATE_CASES, GateCase, LogStep, PROGRESS_CASES, ProgressCase,
  REPLAY_CASES, ReplayCase, SCENE_CASES, SceneCase,
} from './Fixtures.generated';
import { diffState, loadCase, stateFromPatch } from './TestSupport';

/**
 * 双端一致性 runner（AC-18）：遍历 tools/gen_fixtures_ets.py 从 shared/fixtures 生成的
 * 强类型用例，逐条与期望比对。与 Android 侧 FixtureTest.kt 跑的是同一批 42 条。
 */
export default function fixtureTest(): void {
  // Hypium 的 describe 值只允许字母/数字/下划线/点，且必须以字母开头（中文或括号会被判非法）
  describe('Fixtures.AC18', () => {
    it('用例规模与生成物一致', 0, () => {
      const total = GATE_CASES.length + SCENE_CASES.length + APPLY_CASES.length +
        COMBINE_CASES.length + ENDING_CASES.length + PROGRESS_CASES.length + REPLAY_CASES.length;
      expect(total).assertEqual(FIXTURE_TOTAL);
      expect(FIXTURE_TOTAL >= 42).assertTrue();
    });

    it('gate：节点可见性', 0, () => {
      const caseFile = loadCase();
      const bad: string[] = [];
      GATE_CASES.forEach((c: GateCase) => {
        const got = Engine.isNodeAvailable(stateFromPatch(c.state), caseFile, c.nodeId);
        if (got !== c.expectAvailable) {
          bad.push(`${c.id}: 期望 ${c.expectAvailable} 实际 ${got}`);
        }
      });
      expect(bad.join('; ')).assertEqual('');
    });

    it('sceneGate：场景可见性', 0, () => {
      const caseFile = loadCase();
      const bad: string[] = [];
      SCENE_CASES.forEach((c: SceneCase) => {
        const scene = caseFile.scenes.find((s: SceneDef) => s.id === c.sceneId);
        if (scene === undefined) {
          bad.push(`${c.id}: 场景 ${c.sceneId} 不存在`);
          return;
        }
        const got = Engine.isSceneAvailable(stateFromPatch(c.state), scene);
        if (got !== c.expectAvailable) {
          bad.push(`${c.id}: 期望 ${c.expectAvailable} 实际 ${got}`);
        }
      });
      expect(bad.join('; ')).assertEqual('');
    });

    it('apply：事务语义 / 幂等 / 互斥关闭', 0, () => {
      const caseFile = loadCase();
      const bad: string[] = [];
      APPLY_CASES.forEach((c: ApplyCase) => {
        const r = Engine.applyNode(stateFromPatch(c.state), caseFile, c.nodeId);
        if (r.ok !== c.expectOk) {
          bad.push(`${c.id}: ok 期望 ${c.expectOk} 实际 ${r.ok}`);
          return;
        }
        if (c.expectError !== null && r.error !== c.expectError) {
          bad.push(`${c.id}: error 期望 ${c.expectError} 实际 ${r.error}`);
        }
        if (c.expectNoop && r.noop !== true) {
          bad.push(`${c.id}: 期望 noop，实际不是`);
        }
        if (c.expectState !== null) {
          const diffs = diffState(r.state, c.expectState);
          if (diffs.length > 0) {
            bad.push(`${c.id}: ${diffs.join(' | ')}`);
          }
        }
      });
      expect(bad.join('; ')).assertEqual('');
    });

    it('combine：连线规则与顺序无关', 0, () => {
      const caseFile = loadCase();
      const bad: string[] = [];
      COMBINE_CASES.forEach((c: CombineCase) => {
        const r = Engine.checkCombine(stateFromPatch(c.state), caseFile, c.a, c.b);
        if (r.ok !== c.expectOk) {
          bad.push(`${c.id}: ok 期望 ${c.expectOk} 实际 ${r.ok}`);
          return;
        }
        if (c.expectRuleId !== null && r.ruleId !== c.expectRuleId) {
          bad.push(`${c.id}: ruleId 期望 ${c.expectRuleId} 实际 ${r.ruleId}`);
        }
        if (c.expectGrantsFlag !== null && r.grantsFlag !== c.expectGrantsFlag) {
          bad.push(`${c.id}: grantsFlag 期望 ${c.expectGrantsFlag} 实际 ${r.grantsFlag}`);
        }
        if (c.expectReason !== null && r.reason !== c.expectReason) {
          bad.push(`${c.id}: reason 期望 ${c.expectReason} 实际 ${r.reason}`);
        }
      });
      expect(bad.join('; ')).assertEqual('');
    });

    it('ending：结局判定与伪造拦截', 0, () => {
      const caseFile = loadCase();
      const bad: string[] = [];
      ENDING_CASES.forEach((c: EndingCase) => {
        const r = Engine.resolveEnding(stateFromPatch(c.state), caseFile);
        if (r.canPublic !== c.expectCanPublic) {
          bad.push(`${c.id}: canPublic 期望 ${c.expectCanPublic} 实际 ${r.canPublic}`);
        }
        if (r.canPrivate !== c.expectCanPrivate) {
          bad.push(`${c.id}: canPrivate 期望 ${c.expectCanPrivate} 实际 ${r.canPrivate}`);
        }
        if (r.ready !== c.expectReady) {
          bad.push(`${c.id}: ready 期望 ${c.expectReady} 实际 ${r.ready}`);
        }
        if (r.endingId !== c.expectEndingId) {
          bad.push(`${c.id}: endingId 期望 ${c.expectEndingId} 实际 ${r.endingId}`);
        }
      });
      expect(bad.join('; ')).assertEqual('');
    });

    it('progress：阶段基值与钳制', 0, () => {
      const caseFile = loadCase();
      const bad: string[] = [];
      PROGRESS_CASES.forEach((c: ProgressCase) => {
        const got = Engine.computeProgress(stateFromPatch(c.state), caseFile);
        if (Math.abs(got - c.expectProgress) > 1e-6) {
          bad.push(`${c.id}: 期望 ${c.expectProgress} 实际 ${got}`);
        }
      });
      expect(bad.join('; ')).assertEqual('');
    });

    it('replay：流水回放与重复 seq 幂等', 0, () => {
      const caseFile = loadCase();
      const bad: string[] = [];
      REPLAY_CASES.forEach((c: ReplayCase) => {
        const log: LogEntry[] = c.log.map((step: LogStep) => new LogEntry(step.seq, step.nodeId));
        const rebuilt = Engine.replay(caseFile, log);
        const diffs = diffState(rebuilt, c.expectState);
        if (diffs.length > 0) {
          bad.push(`${c.id}: ${diffs.join(' | ')}`);
        }
      });
      expect(bad.join('; ')).assertEqual('');
    });
  });
}
