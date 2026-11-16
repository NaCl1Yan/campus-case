import { PlayerState, Stage } from '../domain/Types';

/**
 * 快照编解码（01 §附录 C）。
 * 约定：flags 只序列化为「为 true 的 key 列表」——引擎判定用 `=== true`，
 * 缺失即 false，因此不需要存 false，快照更小、两端也一致。
 */
export class SnapshotJson {
  v: number = 1;
  caseId: string = 'campus_001';
  contentVersion: number = 1;
  seq: number = 0;
  stage: string = Stage.PROLOGUE;
  unlockedScenes: string[] = [];
  ownedClues: string[] = [];
  flags: string[] = [];
  closedNodes: string[] = [];
  appliedNodes: string[] = [];
  passedStages: string[] = [];
  finalChoice: string | null = null;
  endingId: string | null = null;
  playMs: number = 0;
  savedAt: number = 0;
}

export class Snapshot {
  static encode(state: PlayerState): string {
    const json = new SnapshotJson();
    json.caseId = state.caseId;
    json.contentVersion = state.contentVersion;
    json.seq = state.seq;
    json.stage = state.stage;
    json.unlockedScenes = state.unlockedScenes.slice();
    json.ownedClues = state.ownedClues.slice();
    const trueFlags: string[] = [];
    state.flags.forEach((value: boolean, key: string) => {
      if (value === true) {
        trueFlags.push(key);
      }
    });
    json.flags = trueFlags.sort();
    json.closedNodes = state.closedNodes.slice();
    json.appliedNodes = state.appliedNodes.slice();
    json.passedStages = state.passedStages.slice();
    json.finalChoice = state.finalChoice;
    json.endingId = state.endingId;
    json.playMs = state.playMs;
    json.savedAt = Date.now();
    return JSON.stringify(json);
  }

  static decode(text: string): PlayerState | null {
    try {
      const json = JSON.parse(text) as SnapshotJson;
      if (json === null || json.caseId === undefined) {
        return null;
      }
      return Snapshot.fromJson(json);
    } catch (e) {
      console.error(`[campus] snapshot decode failed: ${e}`);
      return null;
    }
  }

  static fromJson(json: SnapshotJson): PlayerState {
    const state = new PlayerState();
    state.caseId = json.caseId;
    state.contentVersion = json.contentVersion;
    state.seq = json.seq;
    state.stage = Snapshot.toStage(json.stage);
    state.unlockedScenes = (json.unlockedScenes ?? []).slice();
    state.ownedClues = (json.ownedClues ?? []).slice();
    const flags = new Map<string, boolean>();
    (json.flags ?? []).forEach((key: string) => {
      flags.set(key, true);
    });
    state.flags = flags;
    state.closedNodes = (json.closedNodes ?? []).slice();
    state.appliedNodes = (json.appliedNodes ?? []).slice();
    state.passedStages = (json.passedStages ?? []).slice();
    state.finalChoice = json.finalChoice;
    state.endingId = json.endingId;
    state.playMs = json.playMs;
    state.savedAt = json.savedAt;
    return state;
  }

  /** 恢复后的合法性修正（01 §FR-14 sanitize）。 */
  static sanitize(state: PlayerState): PlayerState {
    const next = state.clone();
    if (next.stage === Stage.DEDUCE && next.ownedClues.length === 0) {
      next.stage = Stage.EXPLORE;
    }
    if (next.endingId !== null && next.finalChoice === null) {
      next.endingId = null;
      next.stage = Stage.JUDGE;
    }
    if (next.stage === Stage.FINISHED && next.endingId === null) {
      next.stage = Stage.ENDING;
    }
    return next;
  }

  static toStage(name: string): Stage {
    switch (name) {
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
}
