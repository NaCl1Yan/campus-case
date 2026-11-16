package com.nacl1yan.campuscase.domain

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * 引擎语义用例（TC 编号对应 docs/01 §10.2）。
 * 与鸿蒙侧 Hypium 用例一一对应：同一断言、同一预期。
 */
class EngineTest {

    private val case: CaseFile = TestResources.case()

    private fun state(
        stage: Stage = Stage.EXPLORE,
        scenes: List<String> = listOf("S1", "S2", "S3", "S4"),
        clues: List<String> = emptyList(),
        flags: Map<String, Boolean> = emptyMap(),
        closed: List<String> = emptyList(),
        applied: List<String> = emptyList(),
        seq: Int = 0,
        choice: String? = null,
    ) = PlayerState(
        stage = stage,
        unlockedScenes = scenes,
        ownedClues = clues,
        flags = flags,
        closedNodes = closed,
        appliedNodes = applied,
        seq = seq,
        finalChoice = choice,
    )

    /** TC-26：内容可解析且通过全部校验 */
    @Test
    fun caseLoadsAndValidates() {
        assertTrue(case.scenes.size >= 3)
        assertTrue(case.nodes.size >= 12)
        assertTrue(case.clues.size >= 6)
        val errors = CaseLoader.validate(case)
        assertTrue(errors.isEmpty(), "内容校验失败: $errors")
    }

    /** TC-01 / TC-02：门控顺序 closed → 场景 → 条件 */
    @Test
    fun gateOrderAndSceneLock() {
        val s = state(scenes = listOf("S1"))
        assertFalse(Engine.isNodeAvailable(s, case, "N02"), "未接案时 N02 不可用")
        val accepted = s.copy(flags = mapOf("accepted" to true))
        assertTrue(Engine.isNodeAvailable(accepted, case, "N02"))
        assertFalse(Engine.isNodeAvailable(accepted, case, "N03"), "S2 未解锁")
    }

    /** TC-03 / TC-05：撬锁关闭 N05，且关闭不可被条件复活 */
    @Test
    fun breachClosesNodePermanently() {
        val base = state(clues = listOf("C2"), seq = 1)
        val after = Engine.applyNode(base, case, "N04")
        assertTrue(after.ok, "撬锁应成功")
        assertTrue(after.state.closedNodes.containsAll(listOf("N03", "N05")))
        assertTrue(after.state.flags["breached"] == true)
        // 条件仍然满足（有 C2、S3 已解锁），但节点已关闭
        assertTrue(after.state.unlockedScenes.contains("S3"))
        assertFalse(Engine.isNodeAvailable(after.state, case, "N05"))
        assertEquals(NodeState.CLOSED, Engine.nodeState(after.state, case, "N05"))
    }

    /** TC-06：非 repeatable 节点重复应用幂等（seq 不涨、线索不重复） */
    @Test
    fun repeatedApplyIsIdempotent() {
        val base = state(clues = listOf("C2"), flags = mapOf("accepted" to true), applied = listOf("N02"), seq = 3)
        val again = Engine.applyNode(base, case, "N02")
        assertTrue(again.ok)
        assertTrue(again.noop)
        assertEquals(3, again.state.seq)
        assertEquals(listOf("C2"), again.state.ownedClues)
    }

    /** TC-07：非法阶段跳转被拒且状态不变 */
    @Test
    fun invalidTransitionRejected() {
        val s = state(clues = listOf("C1", "C2", "C3"), flags = mapOf("proofA" to true, "proofB" to true), seq = 5)
        val r = Engine.applyNode(s, case, "N12")
        assertFalse(r.ok)
        assertEquals(Errs.INVALID_TRANSITION, r.error)
        assertEquals(Stage.EXPLORE, r.state.stage)
        assertEquals(5, r.state.seq)
    }

    /** TC-08：允许的回退（DEDUCE → EXPLORE）通过 */
    @Test
    fun allowedFallbackTransits() {
        assertTrue(Engine.canTransit(Stage.DEDUCE, Stage.EXPLORE))
        assertTrue(Engine.canTransit(Stage.JUDGE, Stage.DEDUCE))
        assertFalse(Engine.canTransit(Stage.EXPLORE, Stage.ENDING))
    }

    /** TC-09 / TC-10 / TC-11：连线命中与顺序无关，无规则不惩罚 */
    @Test
    fun combineRules() {
        val s = state(clues = listOf("C1", "C2", "C5"))
        val hit = Engine.checkCombine(s, case, "C2", "C1")
        assertTrue(hit.ok)
        assertEquals("R1", hit.ruleId)
        assertEquals("link.b1", hit.grantsFlag)

        val none = Engine.checkCombine(s, case, "C1", "C5")
        assertFalse(none.ok)
        assertEquals("NO_RULE", none.reason)

        val notOwned = Engine.checkCombine(state(clues = listOf("C1")), case, "C1", "C2")
        assertEquals("NOT_OWNED", notOwned.reason)

        // 连错不改变状态
        val afterMiss = Engine.applyCombine(s, case, "C1", "C5")
        assertEquals(s, afterMiss)
    }

    /** TC-13 / TC-14：单链成立时另一选项不可用 */
    @Test
    fun singleChainLimitsChoices() {
        val onlyB = state(stage = Stage.JUDGE, flags = mapOf("proofB" to true))
        val choices = Engine.choiceAvailability(onlyB, case)
        assertEquals(true, choices.first { it.first.id == "PUBLIC" }.second)
        assertEquals(false, choices.first { it.first.id == "PRIVATE" }.second)

        val onlyA = state(stage = Stage.JUDGE, flags = mapOf("proofA" to true, "tapeFound" to true))
        val outA = Engine.resolveEnding(onlyA, case)
        assertFalse(outA.canPublic, "行动线不成立")
        assertTrue(outA.canPrivate, "动机线成立")
        assertEquals(null, outA.endingId, "尚未提交判断")
        assertEquals(false, Engine.choiceAvailability(onlyA, case).first { it.first.id == "PUBLIC" }.second)
    }

    /** TC-15 / TC-16：两链都成立由选择决定；都不成立不可进判断 */
    @Test
    fun endingResolvedByChoice() {
        val both = state(
            stage = Stage.JUDGE,
            flags = mapOf("proofA" to true, "tapeFound" to true, "proofB" to true),
        )
        val pub = Engine.submitFinalChoice(both, case, "PUBLIC")
        assertTrue(pub.ok)
        assertEquals("E-B", Engine.resolveEnding(pub.state, case).endingId)

        val pri = Engine.submitFinalChoice(both, case, "PRIVATE")
        assertTrue(pri.ok)
        assertEquals("E-A", Engine.resolveEnding(pri.state, case).endingId)

        val none = state(stage = Stage.DEDUCE, flags = emptyMap())
        assertFalse(Engine.enterJudge(none).ok)
        assertEquals(Errs.CHAIN_NOT_READY, Engine.enterJudge(none).error)
    }

    /** TC-17 / TC-18：缺 tapeFound 的 A 链无效；伪造选择被拦截 */
    @Test
    fun forgedChoiceBlocked() {
        val noTape = state(stage = Stage.JUDGE, flags = mapOf("proofA" to true))
        assertFalse(Engine.canPrivate(noTape))
        assertEquals(Errs.FINAL_MISMATCH, Engine.submitFinalChoice(noTape, case, "PRIVATE").error)

        val forged = state(stage = Stage.ENDING, flags = emptyMap(), choice = "PUBLIC")
        assertFalse(Engine.canPublic(forged))
        assertEquals(null, Engine.resolveEnding(forged, case).endingId)
        assertFalse(Engine.finishCase(forged, case).ok)
    }

    /** TC-19 / TC-20：进度单调与边界钳制 */
    @Test
    fun progressBounds() {
        assertEquals(0.0, Engine.computeProgress(state(stage = Stage.PROLOGUE), case))
        assertEquals(10.0, Engine.computeProgress(state(stage = Stage.EXPLORE), case))
        assertEquals(32.5, Engine.computeProgress(state(stage = Stage.EXPLORE, clues = listOf("C1", "C2", "C3")), case))
        assertEquals(
            55.0,
            Engine.computeProgress(state(stage = Stage.EXPLORE, clues = listOf("C1", "C2", "C3", "C4", "C5", "C6")), case),
        )
        assertEquals(70.0, Engine.computeProgress(state(stage = Stage.DEDUCE, flags = mapOf("proofB" to true)), case))
        assertEquals(100.0, Engine.computeProgress(state(stage = Stage.FINISHED), case))
    }

    /** TC-24 / TC-25：流水回放幂等、重复 seq 只生效一次 */
    @Test
    fun replayIsIdempotent() {
        val log = listOf(LogEntry(1, "N01"), LogEntry(1, "N01"), LogEntry(2, "N02"))
        val rebuilt = Engine.replay(case, log)
        assertEquals(2, rebuilt.seq)
        assertEquals(listOf("C2"), rebuilt.ownedClues)
        assertEquals(listOf("N01", "N02"), rebuilt.appliedNodes)
        assertEquals(Stage.EXPLORE, rebuilt.stage)
        assertTrue(rebuilt.unlockedScenes.containsAll(listOf("S1", "S2")))
    }

    /** 不变量：breached ⇒ 拿不到 C4（动机线必然断裂） */
    @Test
    fun breachPathBreaksMotivationChain() {
        var s = Engine.seedDefaultScenes(case, PlayerState(stage = Stage.ACCEPT))
        s = Engine.applyNode(s, case, "N01").state
        s = Engine.applyNode(s, case, "N02").state
        s = Engine.applyNode(s, case, "N04").state // 撬锁
        assertFalse(Engine.isNodeAvailable(s, case, "N05"), "N05 已关闭")
        assertFalse(s.ownedClues.contains("C4"))
        assertFalse(Engine.canPrivate(s), "动机线不成立")
    }

    /** 完整链路：接案 → 探索 → 验证 → 判断 → 结局（AC-11） */
    @Test
    fun fullHappyPath() {
        var s = Engine.seedDefaultScenes(case, PlayerState(stage = Stage.ACCEPT))
        assertEquals(listOf("S1"), s.unlockedScenes)

        s = Engine.applyNode(s, case, "N01").state
        s = Engine.applyNode(s, case, "N02").state
        s = Engine.applyNode(s, case, "N03").state // 登记借用（非撬锁）
        s = Engine.applyNode(s, case, "N05").state // 群消息 → C4
        s = Engine.applyNode(s, case, "N07").state // 道歉信 → C5
        s = Engine.applyNode(s, case, "N09").state // 母带 → tapeFound
        s = Engine.applyNode(s, case, "N05").state // 重复应用应幂等

        assertEquals(listOf("C1", "C2", "C4", "C5"), s.ownedClues)
        assertTrue(s.flags["tapeFound"] == true)
        assertTrue(s.unlockedScenes.contains("S4"))

        // 关卡通过（模拟 onPass 写入 proofA）
        s = s.copy(flags = s.flags + ("proofA" to true), passedStages = listOf("P2"))
        assertTrue(Engine.enterJudge(s).ok)
        val judge = Engine.enterJudge(s).state
        assertEquals(Stage.JUDGE, judge.stage)

        val submitted = Engine.submitFinalChoice(judge, case, "PRIVATE")
        assertTrue(submitted.ok)
        assertEquals(Stage.ENDING, submitted.state.stage)

        val finished = Engine.finishCase(submitted.state, case)
        assertTrue(finished.ok)
        assertEquals(Stage.FINISHED, finished.state.stage)
        assertEquals("E-A", finished.state.endingId)
        assertEquals(100.0, Engine.computeProgress(finished.state, case))
    }
}
