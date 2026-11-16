import {
  ApplyOutcome, CaseFile, ChainDef, ClueDef, CombineOutcome, CombineRuleDef, Condition, Effect,
  EndingDef, EndingOutcome, EventNodeDef, FinalChoiceDef, LogEntry, NodeState, PlayerState,
  ProveStageDef, SceneDef, Stage, STAGE_RANK, Errs,
} from './Types';

/**
 * 判定引擎（鸿蒙侧）：纯函数，不引用 UI、不引用 Preferences/RDB。
 * 与 android/domain 的 Engine.kt 逐函数对应；两端结果必须一致（AC-18）。
 */
export class Engine {

  private static readonly ALLOWED: Map<string, string[]> = new Map<string, string[]>([
    [Stage.PROLOGUE, [Stage.ACCEPT]],
    [Stage.ACCEPT, [Stage.EXPLORE]],
    [Stage.EXPLORE, [Stage.EXPLORE, Stage.DEDUCE]],
    [Stage.DEDUCE, [Stage.EXPLORE, Stage.JUDGE]],
    [Stage.JUDGE, [Stage.DEDUCE, Stage.ENDING]],
    [Stage.ENDING, [Stage.FINISHED]],
    [Stage.FINISHED, []],
  ]);

  static canTransit(from: Stage, to: Stage): boolean {
    if (from === to) {
      return true;
    }
    const list = Engine.ALLOWED.get(from);
    return list !== undefined && list.includes(to);
  }

  /** 空条件 = 恒真（用于判定"开局场景"）。 */
  static isEmptyCondition(cond: Condition | undefined): boolean {
    if (cond === undefined) {
      return true;
    }
    const noClues = (cond.allClues === undefined || cond.allClues.length === 0) &&
      (cond.anyClues === undefined || cond.anyClues.length === 0);
    const noFlags = (cond.allFlags === undefined || cond.allFlags.length === 0) &&
      (cond.anyFlags === undefined || cond.anyFlags.length === 0) &&
      (cond.noneFlags === undefined || cond.noneFlags.length === 0);
    return noClues && noFlags && cond.minStage === undefined &&
      (cond.closedNodes === undefined || cond.closedNodes.length === 0);
  }

  /** 开局可用场景在冷启动/回放时自动可用，不依赖流水。 */
  static seedDefaultScenes(caseFile: CaseFile, state: PlayerState): PlayerState {
    const next = state.clone();
    const seeds: string[] = [];
    caseFile.scenes.forEach((s: SceneDef) => {
      if (Engine.isEmptyCondition(s.unlockCond)) {
        seeds.push(s.id);
      }
    });
    const merged = next.unlockedScenes.concat(seeds);
    next.unlockedScenes = Engine.uniqSorted(merged);
    return next;
  }

  static evalCondition(state: PlayerState, cond: Condition | undefined): boolean {
    if (cond === undefined) {
      return true;
    }
    const allClues = cond.allClues ?? [];
    const anyClues = cond.anyClues ?? [];
    const allFlags = cond.allFlags ?? [];
    const anyFlags = cond.anyFlags ?? [];
    const noneFlags = cond.noneFlags ?? [];
    const closedNodes = cond.closedNodes ?? [];

    for (const c of allClues) {
      if (!state.ownedClues.includes(c)) {
        return false;
      }
    }
    if (anyClues.length > 0) {
      let hit = false;
      for (const c of anyClues) {
        if (state.ownedClues.includes(c)) {
          hit = true;
          break;
        }
      }
      if (!hit) {
        return false;
      }
    }
    for (const f of allFlags) {
      if (state.flags.get(f) !== true) {
        return false;
      }
    }
    if (anyFlags.length > 0) {
      let hit = false;
      for (const f of anyFlags) {
        if (state.flags.get(f) === true) {
          hit = true;
          break;
        }
      }
      if (!hit) {
        return false;
      }
    }
    for (const f of noneFlags) {
      if (state.flags.get(f) === true) {
        return false;
      }
    }
    if (cond.minStage !== undefined) {
      const need = STAGE_RANK.get(cond.minStage) ?? 0;
      const cur = STAGE_RANK.get(state.stage) ?? 0;
      if (cur < need) {
        return false;
      }
    }
    for (const n of closedNodes) {
      if (state.closedNodes.includes(n)) {
        return false;
      }
    }
    return true;
  }

  static findNode(caseFile: CaseFile, nodeId: string): EventNodeDef | undefined {
    return caseFile.nodes.find((n: EventNodeDef) => n.id === nodeId);
  }

  static findScene(caseFile: CaseFile, sceneId: string): SceneDef | undefined {
    return caseFile.scenes.find((s: SceneDef) => s.id === sceneId);
  }

  static isSceneAvailable(state: PlayerState, scene: SceneDef): boolean {
    if (state.unlockedScenes.includes(scene.id)) {
      return true;
    }
    return Engine.evalCondition(state, scene.unlockCond);
  }

  static isNodeAvailable(state: PlayerState, caseFile: CaseFile, nodeId: string): boolean {
    const node = Engine.findNode(caseFile, nodeId);
    if (node === undefined) {
      return false;
    }
    if (state.closedNodes.includes(nodeId)) {
      return false;
    }
    if (!state.unlockedScenes.includes(node.sceneId)) {
      return false;
    }
    return Engine.evalCondition(state, node.unlockCond);
  }

  static nodeState(state: PlayerState, caseFile: CaseFile, nodeId: string): NodeState {
    if (Engine.findNode(caseFile, nodeId) === undefined) {
      return NodeState.LOCKED;
    }
    if (state.closedNodes.includes(nodeId)) {
      return NodeState.CLOSED;
    }
    if (state.appliedNodes.includes(nodeId)) {
      return NodeState.DONE;
    }
    return Engine.isNodeAvailable(state, caseFile, nodeId) ? NodeState.AVAILABLE : NodeState.LOCKED;
  }

  /** 应用节点：全成或全不成；非 repeatable 重复应用返回 noop（不涨 seq）。 */
  static applyNode(state: PlayerState, caseFile: CaseFile, nodeId: string): ApplyOutcome {
    const node = Engine.findNode(caseFile, nodeId);
    if (node === undefined) {
      return new ApplyOutcome(false, state, Errs.UNKNOWN_NODE);
    }
    if (state.closedNodes.includes(nodeId)) {
      return new ApplyOutcome(false, state, Errs.NODE_CLOSED);
    }
    if (!state.unlockedScenes.includes(node.sceneId)) {
      return new ApplyOutcome(false, state, Errs.NODE_LOCKED);
    }
    if (!Engine.evalCondition(state, node.unlockCond)) {
      return new ApplyOutcome(false, state, Errs.NODE_LOCKED);
    }
    const repeatable = node.repeatable === true;
    if (!repeatable && state.appliedNodes.includes(nodeId)) {
      return new ApplyOutcome(true, state, null, true);
    }

    const effect: Effect = node.effect;
    const target: Stage | undefined = effect.stage;
    if (target !== undefined && !Engine.canTransit(state.stage, target)) {
      return new ApplyOutcome(false, state, Errs.INVALID_TRANSITION);
    }

    const next = state.clone();
    const flags = new Map<string, boolean>(state.flags);
    const setFlags = effect.setFlags ?? [];
    setFlags.forEach((pair: [string, boolean]) => {
      flags.set(pair[0], pair[1]);
    });
    next.flags = flags;
    next.ownedClues = Engine.uniqSorted(state.ownedClues.concat(effect.grantClues ?? []));
    next.unlockedScenes = Engine.uniqSorted(state.unlockedScenes.concat(effect.unlockScenes ?? []));
    const exclusive = node.exclusiveWith ?? [];
    const closed = state.closedNodes.concat(effect.closeNodes ?? []).concat(exclusive);
    next.closedNodes = Engine.uniqSorted(closed.filter((id: string) => id !== nodeId));
    next.appliedNodes = Engine.uniqSorted(state.appliedNodes.concat([nodeId]));
    if (target !== undefined) {
      next.stage = target;
    }
    next.seq = state.seq + 1;
    return new ApplyOutcome(true, next);
  }

  /** 连线校验：顺序无关；未持有 / 无规则均不改变状态、不惩罚。 */
  static checkCombine(state: PlayerState, caseFile: CaseFile, a: string, b: string): CombineOutcome {
    if (a === b) {
      return new CombineOutcome(false, null, null, 'SAME_CLUE');
    }
    if (!state.ownedClues.includes(a) || !state.ownedClues.includes(b)) {
      return new CombineOutcome(false, null, null, 'NOT_OWNED');
    }
    const rule = caseFile.rules.find((r: CombineRuleDef) => {
      const inputs = r.inputs;
      return inputs.length === 2 && inputs.includes(a) && inputs.includes(b) && a !== b;
    });
    if (rule === undefined) {
      return new CombineOutcome(false, null, null, 'NO_RULE');
    }
    return new CombineOutcome(true, rule.id, rule.grantsFlag, null);
  }

  /** 连线成功后写入 flag。 */
  static applyCombine(state: PlayerState, caseFile: CaseFile, a: string, b: string): PlayerState {
    const res = Engine.checkCombine(state, caseFile, a, b);
    if (!res.ok || res.grantsFlag === null) {
      return state;
    }
    const next = state.clone();
    const flags = new Map<string, boolean>(state.flags);
    flags.set(res.grantsFlag, true);
    next.flags = flags;
    next.seq = state.seq + 1;
    return next;
  }

  static canPublic(state: PlayerState): boolean {
    return state.flags.get('proofB') === true;
  }

  static canPrivate(state: PlayerState): boolean {
    return state.flags.get('proofA') === true && state.flags.get('tapeFound') === true;
  }

  /**
   * 判断选项就绪：按证据链整体判定，而非只看单个 flag。
   * proofB → 行动线（canPublic）；proofA → 动机线（canPrivate，含 tapeFound 这类链内事实）。
   * 与 tools/validate.py、Engine.kt 的同名逻辑保持同构，请同步修改。
   */
  private static chainReady(state: PlayerState, flag: string): boolean {
    if (flag === 'proofB') {
      return Engine.canPublic(state);
    }
    if (flag === 'proofA') {
      return Engine.canPrivate(state);
    }
    return state.flags.get(flag) === true;
  }

  /** 判断选项可见性（灰显但仍展示原因，见 01 §FR-09）。 */
  static choiceAvailability(state: PlayerState, caseFile: CaseFile): Map<string, boolean> {
    const result = new Map<string, boolean>();
    caseFile.finalChoices.forEach((fc: FinalChoiceDef) => {
      result.set(fc.id, Engine.chainReady(state, fc.requiresFlag));
    });
    return result;
  }

  static enterJudge(state: PlayerState): ApplyOutcome {
    if (!Engine.canPublic(state) && !Engine.canPrivate(state)) {
      return new ApplyOutcome(false, state, Errs.CHAIN_NOT_READY);
    }
    if (!Engine.canTransit(state.stage, Stage.JUDGE)) {
      return new ApplyOutcome(false, state, Errs.INVALID_TRANSITION);
    }
    const next = state.clone();
    next.stage = Stage.JUDGE;
    return new ApplyOutcome(true, next);
  }

  /** 提交最终判断：不可撤销；选择与证据链不符一律拦截（TC-18）。 */
  static submitFinalChoice(state: PlayerState, caseFile: CaseFile, choiceId: string): ApplyOutcome {
    if (!Engine.canPublic(state) && !Engine.canPrivate(state)) {
      return new ApplyOutcome(false, state, Errs.CHAIN_NOT_READY);
    }
    const choice = caseFile.finalChoices.find((c: FinalChoiceDef) => c.id === choiceId);
    if (choice === undefined || !Engine.chainReady(state, choice.requiresFlag)) {
      return new ApplyOutcome(false, state, Errs.FINAL_MISMATCH);
    }
    if (state.stage !== Stage.JUDGE || !Engine.canTransit(Stage.JUDGE, Stage.ENDING)) {
      return new ApplyOutcome(false, state, Errs.INVALID_TRANSITION);
    }
    const next = state.clone();
    next.stage = Stage.ENDING;
    next.finalChoice = choiceId;
    next.seq = state.seq + 1;
    return new ApplyOutcome(true, next);
  }

  /** 结局判定：唯一出口。 */
  static resolveEnding(state: PlayerState, caseFile: CaseFile): EndingOutcome {
    const pub = Engine.canPublic(state);
    const pri = Engine.canPrivate(state);
    let endingId: string | null = null;
    const picked = state.finalChoice;
    if (picked !== null) {
      const choice = caseFile.finalChoices.find((c: FinalChoiceDef) => c.id === picked);
      if (choice !== undefined && Engine.chainReady(state, choice.requiresFlag)) {
        const ending = caseFile.endings.find((e: EndingDef) =>
          e.choiceId === picked && Engine.evalCondition(state, e.requires));
        if (ending !== undefined) {
          endingId = ending.id;
        }
      }
    }
    return new EndingOutcome(pub, pri, pub || pri, endingId);
  }

  /** 结局登记：写 endingId 并进入 FINISHED，重复调用幂等。 */
  static finishCase(state: PlayerState, caseFile: CaseFile): ApplyOutcome {
    if (state.stage === Stage.FINISHED && state.endingId !== null) {
      return new ApplyOutcome(true, state, null, true);
    }
    const resolved = Engine.resolveEnding(state, caseFile);
    if (resolved.endingId === null) {
      return new ApplyOutcome(false, state, Errs.FINAL_MISMATCH);
    }
    if (!Engine.canTransit(state.stage, Stage.FINISHED)) {
      return new ApplyOutcome(false, state, Errs.INVALID_TRANSITION);
    }
    const next = state.clone();
    next.stage = Stage.FINISHED;
    next.endingId = resolved.endingId;
    next.seq = state.seq + 1;
    return new ApplyOutcome(true, next);
  }

  /** 进度：阶段基值 + 线索持有率 / 关卡通过数，越界钳制。 */
  static computeProgress(state: PlayerState, caseFile: CaseFile): number {
    const total = Math.max(1, caseFile.clues.length);
    let ratio = Engine.uniqSorted(state.ownedClues).length / total;
    ratio = Math.min(1, Math.max(0, ratio));
    const proofs = (state.flags.get('proofA') === true ? 1 : 0) + (state.flags.get('proofB') === true ? 1 : 0);
    switch (state.stage) {
      case Stage.PROLOGUE:
        return 0;
      case Stage.ACCEPT:
        return 5;
      case Stage.EXPLORE:
        return Engine.round1(Math.min(55, Math.max(10, 10 + 45 * ratio)));
      case Stage.DEDUCE:
        return Engine.round1(Math.min(85, Math.max(55, 55 + 15 * proofs)));
      case Stage.JUDGE:
        return 85;
      case Stage.ENDING:
        return 95;
      case Stage.FINISHED:
        return 100;
      default:
        return 0;
    }
  }

  /** HUD 当前目标。 */
  static nextObjective(state: PlayerState, caseFile: CaseFile): string {
    switch (state.stage) {
      case Stage.PROLOGUE:
      case Stage.ACCEPT:
        return '打开案件简报，接受调查';
      case Stage.EXPLORE: {
        const chain = caseFile.chains.find((c: ChainDef) => c.passFlagId === 'proofB');
        let missing = 0;
        if (chain !== undefined) {
          chain.clueIds.forEach((id: string) => {
            if (!state.ownedClues.includes(id)) {
              missing += 1;
            }
          });
        }
        return missing > 0 ? `补全行动线：还差 ${missing} 条线索` : '去推理工坊验证证据链';
      }
      case Stage.DEDUCE:
        return '在推理工坊验证证据链';
      case Stage.JUDGE:
        return '作出最终判断（不可撤销）';
      case Stage.ENDING:
        return '查看结局';
      default:
        return '本局已完结';
    }
  }

  /** 事件流水回放：不走门控，按 seq 折叠；重复 seq 幂等（TC-24 / TC-25）。 */
  static replay(caseFile: CaseFile, log: LogEntry[], base?: PlayerState): PlayerState {
    let state = Engine.seedDefaultScenes(caseFile, base ?? new PlayerState());
    const seen: Set<number> = new Set<number>();
    for (const entry of log) {
      if (seen.has(entry.seq)) {
        continue;
      }
      seen.add(entry.seq);
      const node = Engine.findNode(caseFile, entry.nodeId);
      if (node === undefined) {
        continue;
      }
      const effect: Effect = node.effect;
      const next = state.clone();
      const flags = new Map<string, boolean>(state.flags);
      const setFlags = effect.setFlags ?? [];
      setFlags.forEach((pair: [string, boolean]) => {
        flags.set(pair[0], pair[1]);
      });
      next.flags = flags;
      next.ownedClues = Engine.uniqSorted(state.ownedClues.concat(effect.grantClues ?? []));
      next.unlockedScenes = Engine.uniqSorted(state.unlockedScenes.concat(effect.unlockScenes ?? []));
      const exclusive = node.exclusiveWith ?? [];
      const closed = state.closedNodes.concat(effect.closeNodes ?? []).concat(exclusive);
      next.closedNodes = Engine.uniqSorted(closed.filter((id: string) => id !== node.id));
      next.appliedNodes = Engine.uniqSorted(state.appliedNodes.concat([node.id]));
      if (effect.stage !== undefined) {
        next.stage = effect.stage;
      }
      next.seq = entry.seq;
      state = next;
    }
    return state;
  }

  /** 首次进入的初始状态：简报已打开（ACCEPT），并种入开局场景。 */
  static initialState(caseFile: CaseFile): PlayerState {
    const s = new PlayerState();
    s.caseId = caseFile.id;
    s.contentVersion = caseFile.contentVersion;
    s.stage = Stage.ACCEPT;
    return Engine.seedDefaultScenes(caseFile, s);
  }

  private static uniqSorted(items: string[]): string[] {
    const set = new Set<string>();
    items.forEach((i: string) => set.add(i));
    const out: string[] = [];
    set.forEach((i: string) => out.push(i));
    return out.sort();
  }

  private static round1(v: number): number {
    return Math.round(v * 10) / 10;
  }
}
