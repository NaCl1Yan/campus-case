import util from '@ohos.util';
import { common } from '@kit.AbilityKit';
import { CaseFile, CombineOutcome, Effect, LogEntry, PlayerState, Stage, ApplyOutcome, EndingOutcome } from '../domain/Types';
import { CaseLoader } from '../domain/CaseLoader';
import { Engine } from '../domain/Engine';
import { CaseDb, EndingRow, LogRow, SlotInfo } from './CaseDb';
import { Prefs } from './Prefs';
import { Snapshot } from './Snapshot';

/**
 * 全局控制器：串起「引擎（纯函数）→ 落盘（RDB + Preferences）→ 界面刷新」。
 * 界面只调这里的命令，不直接改 PlayerState（01 §3.2 单一判定出口）。
 */
export class GameController {
  static readonly I: GameController = new GameController();

  caseFile: CaseFile | null = null;
  state: PlayerState = new PlayerState();
  restoredFrom: string = 'new';

  private contentVersion: number = 1;

  /** 设置（01 §FR-15）：当前只做「动画减弱」，其余项留给后续。 */
  reduceMotion: boolean = false;

  // ---------------------------------------------------------------- 初始化与恢复

  async init(context: common.UIAbilityContext): Promise<void> {
    await Prefs.init(context);
    await CaseDb.init(context);

    const bytes: Uint8Array = context.resourceManager.getRawFileContentSync('case/campus_001.json');
    const decoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
    this.caseFile = CaseLoader.parse(decoder.decodeToString(bytes));
    this.contentVersion = this.caseFile.contentVersion;
    await Prefs.putNumber(Prefs.KEY_CONTENT_VERSION, this.contentVersion);

    this.reduceMotion = await Prefs.getBoolean(Prefs.KEY_REDUCE_MOTION, false);
    await this.restore();
  }

  async setReduceMotion(value: boolean): Promise<void> {
    this.reduceMotion = value;
    await Prefs.putBoolean(Prefs.KEY_REDUCE_MOTION, value);
  }

  /** 收集册：全部结局 + 是否已解锁。 */
  async collectibleEndings(): Promise<EndingRow[]> {
    return await CaseDb.listEndings();
  }

  /** 冷启动恢复（01 §FR-14）：快照与流水对账，不一致以流水回放为准。 */
  private async restore(): Promise<void> {
    const caseFile = this.requireCase();
    const dbSeq = await CaseDb.maxSeq(caseFile.id);
    const snapSeq = await Prefs.getNumber(Prefs.KEY_SEQ, -1);
    const snapText = await Prefs.getString(Prefs.KEY_SNAPSHOT, '');

    let restored: PlayerState | null = null;
    // 1) 自动存档槽：每次动作后写的完整快照，能还原 JUDGE/ENDING 这类非节点事件
    const autoPayload = await CaseDb.getSlotPayload(GameController.SLOT_AUTO);
    if (autoPayload !== null) {
      restored = Snapshot.decode(autoPayload);
      if (restored !== null) {
        this.restoredFrom = 'autoSlot';
      }
    }
    // 2) Preferences 快照（回退）
    if (restored === null && snapText.length > 0 && snapSeq === dbSeq) {
      restored = Snapshot.decode(snapText);
      if (restored !== null) {
        this.restoredFrom = 'snapshot';
      }
    }
    if (restored === null && dbSeq > 0) {
      const rows: LogRow[] = await CaseDb.loadLog(caseFile.id);
      const entries: LogEntry[] = rows.map((row: LogRow) => new LogEntry(row.seq, row.nodeId, row.choiceId));
      restored = Engine.replay(caseFile, entries);
      this.restoredFrom = 'eventLog';
    }
    if (restored === null) {
      restored = Engine.initialState(caseFile);
      this.restoredFrom = 'new';
    }

    this.state = Snapshot.sanitize(restored);
    await this.persistQuick(this.state);
  }

  private async persistQuick(state: PlayerState): Promise<void> {
    await Prefs.putString(Prefs.KEY_SNAPSHOT, Snapshot.encode(state));
    await Prefs.putNumber(Prefs.KEY_SEQ, state.seq);
  }

  requireCase(): CaseFile {
    if (this.caseFile === null) {
      throw new Error('案件内容未加载');
    }
    return this.caseFile as CaseFile;
  }

  // ---------------------------------------------------------------- 查询（HUD 用）

  progress(): number {
    return Engine.computeProgress(this.state, this.requireCase());
  }

  objective(): string {
    return Engine.nextObjective(this.state, this.requireCase());
  }

  stageLabel(): string {
    switch (this.state.stage) {
      case Stage.PROLOGUE:
        return '序章';
      case Stage.ACCEPT:
        return '第1阶段 · 简报';
      case Stage.EXPLORE:
        return '第2阶段 · 勘探';
      case Stage.DEDUCE:
        return '第3阶段 · 验证';
      case Stage.JUDGE:
        return '第4阶段 · 判断';
      case Stage.ENDING:
        return '结局';
      default:
        return '已完结';
    }
  }

  clueCount(): number {
    return this.state.ownedClues.length;
  }

  clueTotal(): number {
    return this.requireCase().clues.length;
  }

  /** 证据链进度：已获线索 / 链所需线索。 */
  chainProgress(chainId: string): number {
    const chain = this.requireCase().chains.find((c) => c.id === chainId);
    if (chain === undefined) {
      return 0;
    }
    let owned = 0;
    chain.clueIds.forEach((id: string) => {
      if (this.state.ownedClues.includes(id)) {
        owned += 1;
      }
    });
    return owned;
  }

  chainSize(chainId: string): number {
    const chain = this.requireCase().chains.find((c) => c.id === chainId);
    return chain === undefined ? 0 : chain.clueIds.length;
  }

  anyChainReady(): boolean {
    return Engine.canPublic(this.state) || Engine.canPrivate(this.state);
  }

  // ---------------------------------------------------------------- 命令

  async applyNode(nodeId: string): Promise<ApplyOutcome> {
    const caseFile = this.requireCase();
    const result = Engine.applyNode(this.state, caseFile, nodeId);
    if (!result.ok || result.noop) {
      return result;
    }
    return await this.persistThenSwap(result.state, nodeId, null, result);
  }

  async linkClues(a: string, b: string): Promise<CombineOutcome> {
    const caseFile = this.requireCase();
    const outcome = Engine.checkCombine(this.state, caseFile, a, b);
    if (!outcome.ok) {
      return outcome;
    }
    const next = Engine.applyCombine(this.state, caseFile, a, b);
    const applied = new ApplyOutcome(true, next);
    await this.persistThenSwap(next, `link:${outcome.ruleId}`, null, applied);
    await this.autoSave();
    return outcome;
  }

  /** 推理关卡提交：答案正确才置 flag（01 §FR-08）。 */
  async submitProof(stageId: string, picked: string[]): Promise<boolean> {
    const caseFile = this.requireCase();
    const stage = caseFile.proveStages.find((p) => p.id === stageId);
    if (stage === undefined) {
      return false;
    }
    if (picked.length !== stage.answer.length) {
      return false;
    }
    for (const clue of stage.answer) {
      if (!picked.includes(clue)) {
        return false;
      }
    }
    const next = this.applyEffect(this.state, stage.onPass);
    const withStage = next.clone();
    withStage.passedStages = (withStage.passedStages.concat([stageId])).sort();
    const outcome = new ApplyOutcome(true, withStage);
    await this.persistThenSwap(withStage, `prove:${stageId}`, null, outcome);
    await this.autoSave();
    return true;
  }

  async enterJudge(): Promise<ApplyOutcome> {
    const result = Engine.enterJudge(this.state);
    if (!result.ok) {
      return result;
    }
    const swapped = await this.persistThenSwap(result.state, 'enterJudge', null, result);
    await this.autoSave();
    return swapped;
  }

  async chooseFinal(choiceId: string): Promise<ApplyOutcome> {
    const caseFile = this.requireCase();
    const result = Engine.submitFinalChoice(this.state, caseFile, choiceId);
    if (!result.ok) {
      return result;
    }
    const swapped = await this.persistThenSwap(result.state, 'finalChoice', choiceId, result);
    await this.autoSave();
    return swapped;
  }

  async finish(): Promise<ApplyOutcome> {
    const caseFile = this.requireCase();
    const result = Engine.finishCase(this.state, caseFile);
    if (!result.ok) {
      return result;
    }
    const swapped = await this.persistThenSwap(result.state, 'finish', null, result);
    if (swapped.ok && swapped.state.endingId !== null) {
      const found = this.requireCase().endings.find((e) => e.id === swapped.state.endingId);
      await CaseDb.markEnding(swapped.state.endingId, found === undefined ? '未知结局' : found.name,
        swapped.state.playMs);
    }
    await this.autoSave();
    return swapped;
  }

  endingOutcome(): EndingOutcome {
    return Engine.resolveEnding(this.state, this.requireCase());
  }

  // ---------------------------------------------------------------- 存档

  static readonly SLOT_AUTO: number = 0;
  static readonly SLOT_MANUAL_1: number = 1;
  static readonly SLOT_MANUAL_2: number = 2;
  static readonly SLOT_MANUAL_3: number = 3;

  async saveSlot(slotId: number, name: string): Promise<void> {
    const caseFile = this.requireCase();
    await CaseDb.putSlot(slotId, name, caseFile.id, Snapshot.encode(this.state), this.state.seq);
  }

  async autoSave(): Promise<void> {
    await this.saveSlot(GameController.SLOT_AUTO, '自动存档');
  }

  async listSlots(): Promise<SlotInfo[]> {
    return await CaseDb.listSlots();
  }

  async loadSlot(slotId: number): Promise<boolean> {
    const payload = await CaseDb.getSlotPayload(slotId);
    if (payload === null) {
      return false;
    }
    const decoded = Snapshot.decode(payload);
    if (decoded === null) {
      return false;
    }
    const sanitized = Snapshot.sanitize(decoded);
    await CaseDb.replaceProgress(sanitized);
    await this.persistQuick(sanitized);
    this.state = sanitized;
    return true;
  }

  async deleteSlot(slotId: number): Promise<void> {
    await CaseDb.deleteSlot(slotId);
  }

  /** 重开：清进度回到简报前，收集册（结局记录）保留在 t_case? 这里按 01 简化为全清。 */
  async restart(): Promise<void> {
    const caseFile = this.requireCase();
    await CaseDb.clearAll(caseFile.id);
    await Prefs.clearProgress();
    this.state = Engine.initialState(caseFile);
    await this.persistQuick(this.state);
  }

  // ---------------------------------------------------------------- 内部

  private applyEffect(state: PlayerState, effect: Effect): PlayerState {
    const next = state.clone();
    next.ownedClues = (state.ownedClues.concat(effect.grantClues ?? [])).filter((v, i, a) => a.indexOf(v) === i).sort();
    next.unlockedScenes = (state.unlockedScenes.concat(effect.unlockScenes ?? []))
      .filter((v, i, a) => a.indexOf(v) === i).sort();
    const flags = new Map<string, boolean>(state.flags);
    (effect.setFlags ?? []).forEach((pair: [string, boolean]) => {
      flags.set(pair[0], pair[1]);
    });
    next.flags = flags;
    next.closedNodes = (state.closedNodes.concat(effect.closeNodes ?? []))
      .filter((v, i, a) => a.indexOf(v) === i).sort();
    if (effect.stage !== undefined) {
      next.stage = effect.stage;
    }
    next.seq = state.seq + 1;
    return next;
  }

  /** 先落盘、后换内存状态：落盘失败则保持原状态（01 §3.3）。 */
  private async persistThenSwap(next: PlayerState, nodeId: string, choiceId: string | null,
    outcome: ApplyOutcome): Promise<ApplyOutcome> {
    try {
      await CaseDb.commit(next, nodeId, choiceId);
      await this.persistQuick(next);
      this.state = next;
      return new ApplyOutcome(true, next);
    } catch (e) {
      console.error(`[campus] persist failed: ${e}`);
      return new ApplyOutcome(false, this.state, 'E_DB_WRITE');
    }
  }
}
