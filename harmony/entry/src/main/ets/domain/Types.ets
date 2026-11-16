/**
 * 领域模型（鸿蒙侧）
 * 与 android/domain 的 Types.kt 字段逐一对应；快照 JSON 两端可互换（AC-20）。
 * 约束：ArkTS 不允许 any；JSON 解析结果统一用 as 断言到接口类型。
 */

export enum Stage {
  PROLOGUE = 'PROLOGUE',
  ACCEPT = 'ACCEPT',
  EXPLORE = 'EXPLORE',
  DEDUCE = 'DEDUCE',
  JUDGE = 'JUDGE',
  ENDING = 'ENDING',
  FINISHED = 'FINISHED',
}

export const STAGE_RANK: Map<string, number> = new Map<string, number>([
  [Stage.PROLOGUE, 0],
  [Stage.ACCEPT, 1],
  [Stage.EXPLORE, 2],
  [Stage.DEDUCE, 3],
  [Stage.JUDGE, 4],
  [Stage.ENDING, 5],
  [Stage.FINISHED, 6],
]);

export enum ClueType {
  PHYSICAL = 'PHYSICAL',
  TESTIMONY = 'TESTIMONY',
  TIMELINE = 'TIMELINE',
}

export enum NodeState {
  LOCKED = 'LOCKED',
  AVAILABLE = 'AVAILABLE',
  DONE = 'DONE',
  CLOSED = 'CLOSED',
}

export class Errs {
  static readonly NODE_LOCKED: string = 'E_NODE_LOCKED';
  static readonly NODE_CLOSED: string = 'E_NODE_CLOSED';
  static readonly UNKNOWN_NODE: string = 'E_UNKNOWN_NODE';
  static readonly INVALID_TRANSITION: string = 'E_STATE_INVALID_TRANSITION';
  static readonly CHAIN_NOT_READY: string = 'E_CHAIN_NOT_READY';
  static readonly FINAL_MISMATCH: string = 'E_FINAL_MISMATCH';
}

// ---------------------------------------------------------------- 内容定义

export interface Condition {
  allClues?: string[];
  anyClues?: string[];
  allFlags?: string[];
  anyFlags?: string[];
  noneFlags?: string[];
  minStage?: Stage;
  closedNodes?: string[];
}

export interface Effect {
  grantClues?: string[];
  setFlags?: Array<[string, boolean]>;
  unlockScenes?: string[];
  closeNodes?: string[];
  stage?: Stage;
}

export interface TimelineItem {
  time: string;
  text: string;
}

export interface Brief {
  client: string;
  summary: string;
  objectives: string[];
  timeline?: TimelineItem[];
}

export interface Hotspot {
  id: string;
  nodeId: string;
  x: number;
  y: number;
  r?: number;
  lockedHint?: string;
}

export interface SceneDef {
  id: string;
  name: string;
  desc: string;
  bgAsset?: string;
  enterFx?: string;
  unlockCond: Condition;
  hotspots: Hotspot[];
}

export interface EventNodeDef {
  id: string;
  sceneId: string;
  title: string;
  body: string;
  unlockCond: Condition;
  effect: Effect;
  exclusiveWith?: string[];
  repeatable?: boolean;
}

export interface ClueDef {
  id: string;
  name: string;
  type: ClueType;
  chainId?: string;
  desc: string;
  hintWhenMissing?: string;
}

export interface CombineRuleDef {
  id: string;
  inputs: string[];
  chainId: string;
  grantsFlag: string;
  conclusion: string;
}

export interface ChainDef {
  id: string;
  name: string;
  clueIds: string[];
  ruleFlagIds: string[];
  passFlagId: string;
}

export interface ProveStageDef {
  id: string;
  question: string;
  slots: number;
  poolCond: Condition;
  answer: string[];
  onPass: Effect;
  hints?: string[];
}

export interface EndingDef {
  id: string;
  name: string;
  choiceId: string;
  requires: Condition;
  segments: string[];
}

export interface FinalChoiceDef {
  id: string;
  label: string;
  requiresFlag: string;
}

export interface CaseFile {
  id: string;
  title: string;
  subtitle?: string;
  contentVersion: number;
  brief: Brief;
  scenes: SceneDef[];
  nodes: EventNodeDef[];
  clues: ClueDef[];
  rules: CombineRuleDef[];
  chains: ChainDef[];
  proveStages: ProveStageDef[];
  endings: EndingDef[];
  finalChoices: FinalChoiceDef[];
}

// ---------------------------------------------------------------- 运行态

/**
 * 玩家状态。可变类 + clone()：引擎每次返回新实例（整体替换），
 * 对应 01 文档 §3.3「不原地改」与 §7.2「状态整体替换」。
 */
export class PlayerState {
  caseId: string = 'campus_001';
  contentVersion: number = 1;
  seq: number = 0;
  stage: Stage = Stage.PROLOGUE;
  unlockedScenes: string[] = [];
  ownedClues: string[] = [];
  flags: Map<string, boolean> = new Map<string, boolean>();
  closedNodes: string[] = [];
  appliedNodes: string[] = [];
  passedStages: string[] = [];
  finalChoice: string | null = null;
  endingId: string | null = null;
  playMs: number = 0;
  savedAt: number = 0;

  clone(): PlayerState {
    const next = new PlayerState();
    next.caseId = this.caseId;
    next.contentVersion = this.contentVersion;
    next.seq = this.seq;
    next.stage = this.stage;
    next.unlockedScenes = this.unlockedScenes.slice();
    next.ownedClues = this.ownedClues.slice();
    next.flags = new Map<string, boolean>(this.flags);
    next.closedNodes = this.closedNodes.slice();
    next.appliedNodes = this.appliedNodes.slice();
    next.passedStages = this.passedStages.slice();
    next.finalChoice = this.finalChoice;
    next.endingId = this.endingId;
    next.playMs = this.playMs;
    next.savedAt = this.savedAt;
    return next;
  }
}

export class ApplyOutcome {
  ok: boolean = false;
  state: PlayerState;
  error: string | null = null;
  noop: boolean = false;

  constructor(ok: boolean, state: PlayerState, error: string | null = null, noop: boolean = false) {
    this.ok = ok;
    this.state = state;
    this.error = error;
    this.noop = noop;
  }
}

export class CombineOutcome {
  ok: boolean = false;
  ruleId: string | null = null;
  grantsFlag: string | null = null;
  reason: string | null = null;

  constructor(ok: boolean, ruleId: string | null = null, grantsFlag: string | null = null,
    reason: string | null = null) {
    this.ok = ok;
    this.ruleId = ruleId;
    this.grantsFlag = grantsFlag;
    this.reason = reason;
  }
}

export class EndingOutcome {
  canPublic: boolean = false;
  canPrivate: boolean = false;
  ready: boolean = false;
  endingId: string | null = null;

  constructor(canPublic: boolean, canPrivate: boolean, ready: boolean, endingId: string | null = null) {
    this.canPublic = canPublic;
    this.canPrivate = canPrivate;
    this.ready = ready;
    this.endingId = endingId;
  }
}

export class LogEntry {
  seq: number;
  nodeId: string;
  choiceId: string | null;

  constructor(seq: number, nodeId: string, choiceId: string | null = null) {
    this.seq = seq;
    this.nodeId = nodeId;
    this.choiceId = choiceId;
  }
}
