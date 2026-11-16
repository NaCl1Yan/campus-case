import relationalStore from '@ohos.data.relationalStore';
import { common } from '@kit.AbilityKit';
import { PlayerState, Stage } from '../domain/Types';

/** 一条事件流水（对应 t_event_log 一行）。 */
export class LogRow {
  seq: number;
  nodeId: string;
  choiceId: string | null;

  constructor(seq: number, nodeId: string, choiceId: string | null) {
    this.seq = seq;
    this.nodeId = nodeId;
    this.choiceId = choiceId;
  }
}

/** 存档槽元信息（列表用，不含 payload）。 */
export class SlotInfo {
  slotId: number;
  name: string;
  stage: string;
  clueCount: number;
  seq: number;
  createdAt: number;

  constructor(slotId: number, name: string, stage: string, clueCount: number, seq: number, createdAt: number) {
    this.slotId = slotId;
    this.name = name;
    this.stage = stage;
    this.clueCount = clueCount;
    this.seq = seq;
    this.createdAt = createdAt;
  }
}

/**
 * 结构化持久化（01 §8.3 五张表）。
 * 角色：事实层（可查询、可回放、可对账）；Preferences 只做加速。
 */
export class CaseDb {
  private static store: relationalStore.RdbStore | null = null;

  private static readonly DDL: string[] = [
    `CREATE TABLE IF NOT EXISTS t_case (
       case_id TEXT PRIMARY KEY, content_version INTEGER NOT NULL, stage TEXT NOT NULL,
       turn_seq INTEGER NOT NULL DEFAULT 0, final_choice TEXT, ending_id TEXT,
       play_ms INTEGER NOT NULL DEFAULT 0, started_at INTEGER NOT NULL, finished_at INTEGER)`,
    `CREATE TABLE IF NOT EXISTS t_clue_owned (
       case_id TEXT NOT NULL, clue_id TEXT NOT NULL, obtained_at INTEGER NOT NULL,
       PRIMARY KEY (case_id, clue_id))`,
    `CREATE TABLE IF NOT EXISTS t_flag (
       case_id TEXT NOT NULL, fkey TEXT NOT NULL, fvalue TEXT NOT NULL,
       PRIMARY KEY (case_id, fkey))`,
    `CREATE TABLE IF NOT EXISTS t_event_log (
       seq INTEGER PRIMARY KEY AUTOINCREMENT, case_id TEXT NOT NULL, node_id TEXT NOT NULL,
       choice_id TEXT, stage_after TEXT NOT NULL, created_at INTEGER NOT NULL)`,
    `CREATE INDEX IF NOT EXISTS idx_log_case_seq ON t_event_log(case_id, seq)`,
    `CREATE TABLE IF NOT EXISTS t_save_slot (
       slot_id INTEGER PRIMARY KEY, slot_name TEXT NOT NULL, case_id TEXT NOT NULL,
       payload TEXT NOT NULL, seq INTEGER NOT NULL, created_at INTEGER NOT NULL)`,
  ];

  static async init(context: common.UIAbilityContext): Promise<void> {
    if (CaseDb.store !== null) {
      return;
    }
    const config: relationalStore.StoreConfig = {
      name: 'campus_case.db',
      securityLevel: relationalStore.SecurityLevel.S1,
    };
    const store = await relationalStore.getRdbStore(context, config);
    for (const sql of CaseDb.DDL) {
      await store.executeSql(sql);
    }
    CaseDb.store = store;
    console.info('[campus] rdb ready');
  }

  private static need(): relationalStore.RdbStore {
    if (CaseDb.store === null) {
      throw new Error('CaseDb 未初始化');
    }
    return CaseDb.store as relationalStore.RdbStore;
  }

  /**
   * 落盘（01 §3.3）：一次节点生效 = 线索/flag/案件/流水 的原子写入。
   * 失败时整体回滚，调用方负责把内存状态退回。
   */
  static async commit(state: PlayerState, nodeId: string, choiceId: string | null): Promise<void> {
    const store = CaseDb.need();
    const now = Date.now();
    store.beginTransaction();
    try {
      await store.executeSql(
        `INSERT OR REPLACE INTO t_case
         (case_id, content_version, stage, turn_seq, final_choice, ending_id, play_ms, started_at, finished_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ${now}, ?)`,
        [state.caseId, state.contentVersion, state.stage, state.seq,
          state.finalChoice, state.endingId, state.playMs,
          state.stage === Stage.FINISHED ? now : null],
      );

      for (const clue of state.ownedClues) {
        await store.executeSql(
          'INSERT OR IGNORE INTO t_clue_owned (case_id, clue_id, obtained_at) VALUES (?, ?, ?)',
          [state.caseId, clue, now],
        );
      }

      const flagKeys: string[] = [];
      state.flags.forEach((value: boolean, key: string) => {
        if (value === true) {
          flagKeys.push(key);
        }
      });
      for (const key of flagKeys) {
        await store.executeSql(
          'INSERT OR REPLACE INTO t_flag (case_id, fkey, fvalue) VALUES (?, ?, ?)',
          [state.caseId, key, 'true'],
        );
      }

      await store.executeSql(
        'INSERT INTO t_event_log (case_id, node_id, choice_id, stage_after, created_at) VALUES (?, ?, ?, ?, ?)',
        [state.caseId, nodeId, choiceId, state.stage, now],
      );

      store.commit();
    } catch (e) {
      store.rollBack();
      console.error(`[campus] commit failed: ${e}`);
      throw e as Error;
    }
  }

  static async maxSeq(caseId: string): Promise<number> {
    const rs = await CaseDb.need().querySql(
      'SELECT COALESCE(MAX(seq), 0) AS m FROM t_event_log WHERE case_id = ?', [caseId]);
    let value = 0;
    if (rs.goToFirstRow()) {
      value = rs.getLong(rs.getColumnIndex('m'));
    }
    rs.close();
    return value;
  }

  static async loadLog(caseId: string): Promise<LogRow[]> {
    const rs = await CaseDb.need().querySql(
      'SELECT seq, node_id, choice_id FROM t_event_log WHERE case_id = ? ORDER BY seq ASC', [caseId]);
    const rows: LogRow[] = [];
    while (rs.goToNextRow()) {
      const choiceIdx = rs.getColumnIndex('choice_id');
      const choice = rs.isColumnNull(choiceIdx) ? null : rs.getString(choiceIdx);
      rows.push(new LogRow(rs.getLong(rs.getColumnIndex('seq')), rs.getString(rs.getColumnIndex('node_id')), choice));
    }
    rs.close();
    return rows;
  }

  /** 读档 = 整体替换：先清当前案进度，再按快照重写（01 §FR-13 规则 4）。 */
  static async replaceProgress(state: PlayerState): Promise<void> {
    const store = CaseDb.need();
    store.beginTransaction();
    try {
      await store.executeSql('DELETE FROM t_clue_owned WHERE case_id = ?', [state.caseId]);
      await store.executeSql('DELETE FROM t_flag WHERE case_id = ?', [state.caseId]);
      await store.executeSql('DELETE FROM t_event_log WHERE case_id = ?', [state.caseId]);
      await store.executeSql(
        `INSERT OR REPLACE INTO t_case
         (case_id, content_version, stage, turn_seq, final_choice, ending_id, play_ms, started_at, finished_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [state.caseId, state.contentVersion, state.stage, state.seq, state.finalChoice,
          state.endingId, state.playMs, Date.now(), state.stage === Stage.FINISHED ? Date.now() : null],
      );
      for (const clue of state.ownedClues) {
        await store.executeSql(
          'INSERT OR IGNORE INTO t_clue_owned (case_id, clue_id, obtained_at) VALUES (?, ?, ?)',
          [state.caseId, clue, Date.now()],
        );
      }
      const flagKeys: string[] = [];
      state.flags.forEach((value: boolean, key: string) => {
        if (value === true) {
          flagKeys.push(key);
        }
      });
      for (const key of flagKeys) {
        await store.executeSql(
          'INSERT OR REPLACE INTO t_flag (case_id, fkey, fvalue) VALUES (?, ?, ?)',
          [state.caseId, key, 'true'],
        );
      }
      store.commit();
    } catch (e) {
      store.rollBack();
      throw e as Error;
    }
  }

  static async clearAll(caseId: string): Promise<void> {
    const store = CaseDb.need();
    await store.executeSql('DELETE FROM t_clue_owned WHERE case_id = ?', [caseId]);
    await store.executeSql('DELETE FROM t_flag WHERE case_id = ?', [caseId]);
    await store.executeSql('DELETE FROM t_event_log WHERE case_id = ?', [caseId]);
    await store.executeSql('DELETE FROM t_case WHERE case_id = ?', [caseId]);
  }

  // ---------------------------------------------------------------- 存档槽

  static async putSlot(slotId: number, name: string, caseId: string, payload: string, seq: number): Promise<void> {
    await CaseDb.need().executeSql(
      'INSERT OR REPLACE INTO t_save_slot (slot_id, slot_name, case_id, payload, seq, created_at) VALUES (?, ?, ?, ?, ?, ?)',
      [slotId, name, caseId, payload, seq, Date.now()],
    );
  }

  static async listSlots(): Promise<SlotInfo[]> {
    const rs = await CaseDb.need().querySql(
      `SELECT s.slot_id, s.slot_name, s.seq, s.created_at, s.payload
         FROM t_save_slot s ORDER BY s.slot_id ASC`, []);
    const slots: SlotInfo[] = [];
    while (rs.goToNextRow()) {
      const payload = rs.getString(rs.getColumnIndex('payload'));
      let stage = '-';
      let clues = 0;
      try {
        const raw = JSON.parse(payload) as Record<string, Object>;
        stage = `${raw.stage ?? '-'}`;
        const owned = raw.ownedClues;
        clues = Array.isArray(owned) ? (owned as string[]).length : 0;
      } catch (e) {
        stage = '损坏';
      }
      slots.push(new SlotInfo(
        rs.getLong(rs.getColumnIndex('slot_id')),
        rs.getString(rs.getColumnIndex('slot_name')),
        stage, clues,
        rs.getLong(rs.getColumnIndex('seq')),
        rs.getLong(rs.getColumnIndex('created_at')),
      ));
    }
    rs.close();
    return slots;
  }

  static async getSlotPayload(slotId: number): Promise<string | null> {
    const rs = await CaseDb.need().querySql(
      'SELECT payload FROM t_save_slot WHERE slot_id = ?', [slotId]);
    let payload: string | null = null;
    if (rs.goToFirstRow()) {
      payload = rs.getString(rs.getColumnIndex('payload'));
    }
    rs.close();
    return payload;
  }

  static async deleteSlot(slotId: number): Promise<void> {
    await CaseDb.need().executeSql('DELETE FROM t_save_slot WHERE slot_id = ?', [slotId]);
  }
}
