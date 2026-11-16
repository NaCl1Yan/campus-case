package com.nacl1yan.campuscase.domain

/**
 * 判定引擎：纯函数，无 Android / 无 IO / 无状态。
 * 对应 docs/01 §3.2「单一判定出口」与 §5.3 伪代码；两端实现必须逐位一致（AC-18）。
 */
object Engine {

    private val ALLOWED: Map<Stage, Set<Stage>> = mapOf(
        Stage.PROLOGUE to setOf(Stage.ACCEPT),
        Stage.ACCEPT to setOf(Stage.EXPLORE),
        Stage.EXPLORE to setOf(Stage.EXPLORE, Stage.DEDUCE),
        Stage.DEDUCE to setOf(Stage.EXPLORE, Stage.JUDGE),
        Stage.JUDGE to setOf(Stage.DEDUCE, Stage.ENDING),
        Stage.ENDING to setOf(Stage.FINISHED),
        Stage.FINISHED to emptySet(),
    )

    fun canTransit(from: Stage, to: Stage): Boolean = from == to || ALLOWED[from]?.contains(to) == true

    /** 开局可用场景：unlockCond 为空的场景在冷启动 / 回放时自动可用，不依赖流水。 */
    fun seedDefaultScenes(case: CaseFile, state: PlayerState): PlayerState {
        val seeds = case.scenes.filter { it.unlockCond.isEmpty() }.map { it.id }
        return state.copy(unlockedScenes = (state.unlockedScenes + seeds).distinct().sorted())
    }

    fun evalCondition(state: PlayerState, cond: Condition?): Boolean {
        if (cond == null) return true
        val owned = state.ownedClues.toSet()
        if (!cond.allClues.all { owned.contains(it) }) return false
        if (cond.anyClues.isNotEmpty() && cond.anyClues.none { owned.contains(it) }) return false
        if (!cond.allFlags.all { state.flags[it] == true }) return false
        if (cond.anyFlags.isNotEmpty() && cond.anyFlags.none { state.flags[it] == true }) return false
        if (cond.noneFlags.any { state.flags[it] == true }) return false
        val min = cond.minStage
        if (min != null && state.stage.ordinal < min.ordinal) return false
        if (cond.closedNodes.any { state.closedNodes.contains(it) }) return false
        return true
    }

    fun isSceneAvailable(state: PlayerState, scene: Scene): Boolean =
        state.unlockedScenes.contains(scene.id) || evalCondition(state, scene.unlockCond)

    fun isNodeAvailable(state: PlayerState, case: CaseFile, nodeId: String): Boolean {
        val node = case.node(nodeId) ?: return false
        if (state.closedNodes.contains(nodeId)) return false
        if (!state.unlockedScenes.contains(node.sceneId)) return false
        return evalCondition(state, node.unlockCond)
    }

    fun nodeState(state: PlayerState, case: CaseFile, nodeId: String): NodeState {
        if (case.node(nodeId) == null) return NodeState.LOCKED
        if (state.closedNodes.contains(nodeId)) return NodeState.CLOSED
        if (state.appliedNodes.contains(nodeId)) return NodeState.DONE
        return if (isNodeAvailable(state, case, nodeId)) NodeState.AVAILABLE else NodeState.LOCKED
    }

    /** 应用节点：全成或全不成；非 repeatable 重复应用返回 noop（不涨 seq）。 */
    fun applyNode(state: PlayerState, case: CaseFile, nodeId: String): ApplyOutcome {
        val node = case.node(nodeId) ?: return ApplyOutcome(false, state, Errs.UNKNOWN_NODE)
        if (state.closedNodes.contains(nodeId)) return ApplyOutcome(false, state, Errs.NODE_CLOSED)
        if (!state.unlockedScenes.contains(node.sceneId)) return ApplyOutcome(false, state, Errs.NODE_LOCKED)
        if (!evalCondition(state, node.unlockCond)) return ApplyOutcome(false, state, Errs.NODE_LOCKED)
        if (!node.repeatable && state.appliedNodes.contains(nodeId)) {
            return ApplyOutcome(true, state, noop = true)
        }

        val effect = node.effect
        val target = effect.stage
        if (target != null && !canTransit(state.stage, target)) {
            return ApplyOutcome(false, state, Errs.INVALID_TRANSITION)
        }

        val flags = state.flags.toMutableMap()
        effect.setFlags.forEach { (k, v) -> flags[k] = v }

        val closed = (state.closedNodes + effect.closeNodes + node.exclusiveWith)
            .filter { it != nodeId }
            .distinct()
            .sorted()

        val next = state.copy(
            stage = target ?: state.stage,
            ownedClues = (state.ownedClues + effect.grantClues).distinct().sorted(),
            unlockedScenes = (state.unlockedScenes + effect.unlockScenes).distinct().sorted(),
            flags = flags,
            closedNodes = closed,
            appliedNodes = (state.appliedNodes + nodeId).distinct().sorted(),
            seq = state.seq + 1,
        )
        return ApplyOutcome(true, next)
    }

    /** 连线校验：顺序无关；未持有 / 无规则均不改变状态、不惩罚。 */
    fun checkCombine(state: PlayerState, case: CaseFile, a: String, b: String): CombineOutcome {
        if (a == b) return CombineOutcome(false, reason = "SAME_CLUE")
        if (!state.ownedClues.contains(a) || !state.ownedClues.contains(b)) {
            return CombineOutcome(false, reason = "NOT_OWNED")
        }
        val want = setOf(a, b)
        val rule = case.rules.firstOrNull { it.inputs.toSet() == want }
            ?: return CombineOutcome(false, reason = "NO_RULE")
        return CombineOutcome(true, ruleId = rule.id, grantsFlag = rule.grantsFlag)
    }

    /** 连线成功后写入 flag（线索板调用，仍走同一状态替换路径）。 */
    fun applyCombine(state: PlayerState, case: CaseFile, a: String, b: String): PlayerState {
        val res = checkCombine(state, case, a, b)
        if (!res.ok || res.grantsFlag == null) return state
        val flags = state.flags.toMutableMap()
        flags[res.grantsFlag] = true
        return state.copy(flags = flags, seq = state.seq + 1)
    }

    fun canPublic(state: PlayerState): Boolean = state.flags["proofB"] == true

    fun canPrivate(state: PlayerState): Boolean =
        state.flags["proofA"] == true && state.flags["tapeFound"] == true

    /**
     * 判断选项就绪：按证据链整体判定，而非只看单个 flag。
     * proofB → 行动线（canPublic）；proofA → 动机线（canPrivate，含 tapeFound 这类链内事实）。
     * 与 tools/validate.py 的 choice_chain_ready 完全同构，请同步修改。
     */
    private fun chainReady(state: PlayerState, flag: String): Boolean = when (flag) {
        "proofB" -> canPublic(state)
        "proofA" -> canPrivate(state)
        else -> state.flags[flag] == true
    }

    /** 最终判断选项的可见性（灰显但仍展示原因，见 01 §FR-09）。 */
    fun choiceAvailability(state: PlayerState, case: CaseFile): List<Pair<FinalChoice, Boolean>> =
        case.finalChoices.map { it to chainReady(state, it.requiresFlag) }

    fun enterJudge(state: PlayerState): ApplyOutcome {
        if (!canPublic(state) && !canPrivate(state)) {
            return ApplyOutcome(false, state, Errs.CHAIN_NOT_READY)
        }
        if (!canTransit(state.stage, Stage.JUDGE)) {
            return ApplyOutcome(false, state, Errs.INVALID_TRANSITION)
        }
        return ApplyOutcome(true, state.copy(stage = Stage.JUDGE))
    }

    /** 提交最终判断：不可撤销；选择与证据链不符一律拦截（TC-18）。 */
    fun submitFinalChoice(state: PlayerState, case: CaseFile, choiceId: String): ApplyOutcome {
        if (!canPublic(state) && !canPrivate(state)) {
            return ApplyOutcome(false, state, Errs.CHAIN_NOT_READY)
        }
        val allowed = case.finalChoices.firstOrNull { it.id == choiceId }
            ?: return ApplyOutcome(false, state, Errs.FINAL_MISMATCH)
        if (!chainReady(state, allowed.requiresFlag)) {
            return ApplyOutcome(false, state, Errs.FINAL_MISMATCH)
        }
        if (state.stage != Stage.JUDGE || !canTransit(Stage.JUDGE, Stage.ENDING)) {
            return ApplyOutcome(false, state, Errs.INVALID_TRANSITION)
        }
        return ApplyOutcome(true, state.copy(stage = Stage.ENDING, finalChoice = choiceId, seq = state.seq + 1))
    }

    /** 结局判定：唯一出口。选择与链不符 / requires 不成立 → 不出结局。 */
    fun resolveEnding(state: PlayerState, case: CaseFile): EndingOutcome {
        val pub = canPublic(state)
        val pri = canPrivate(state)
        val picked = state.finalChoice
        var endingId: String? = null
        if (picked != null) {
            val choice = case.finalChoices.firstOrNull { it.id == picked }
            if (choice != null && chainReady(state, choice.requiresFlag)) {
                endingId = case.endings
                    .firstOrNull { it.choiceId == picked && evalCondition(state, it.requires) }
                    ?.id
            }
        }
        return EndingOutcome(pub, pri, pub || pri, endingId)
    }

    /** 结局登记（EV-12）：写 endingId 并进入 FINISHED，重复调用幂等。 */
    fun finishCase(state: PlayerState, case: CaseFile): ApplyOutcome {
        if (state.stage == Stage.FINISHED && state.endingId != null) return ApplyOutcome(true, state, noop = true)
        val resolved = resolveEnding(state, case)
        val id = resolved.endingId ?: return ApplyOutcome(false, state, Errs.FINAL_MISMATCH)
        if (!canTransit(state.stage, Stage.FINISHED)) {
            return ApplyOutcome(false, state, Errs.INVALID_TRANSITION)
        }
        return ApplyOutcome(true, state.copy(stage = Stage.FINISHED, endingId = id, seq = state.seq + 1))
    }

    /** 进度：阶段基值 + 线索持有率 / 关卡通过数，越界钳制。 */
    fun computeProgress(state: PlayerState, case: CaseFile): Double {
        val total = case.clues.size.coerceAtLeast(1)
        val ratio = (state.ownedClues.distinct().size.toDouble() / total).coerceIn(0.0, 1.0)
        val proofs = (if (state.flags["proofA"] == true) 1 else 0) +
            (if (state.flags["proofB"] == true) 1 else 0)
        return when (state.stage) {
            Stage.PROLOGUE -> 0.0
            Stage.ACCEPT -> 5.0
            Stage.EXPLORE -> round1((10.0 + 45.0 * ratio).coerceIn(10.0, 55.0))
            Stage.DEDUCE -> round1((55.0 + 15.0 * proofs).coerceIn(55.0, 85.0))
            Stage.JUDGE -> 85.0
            Stage.ENDING -> 95.0
            Stage.FINISHED -> 100.0
        }
    }

    private fun round1(v: Double): Double = kotlin.math.round(v * 10.0) / 10.0

    /** HUD 当前目标（从 state 推导，不允许写死文案常量表以外的分支）。 */
    fun nextObjective(state: PlayerState, case: CaseFile): String {
        return when (state.stage) {
            Stage.PROLOGUE, Stage.ACCEPT -> "打开案件简报，接受调查"
            Stage.EXPLORE -> {
                val needB = case.chains.firstOrNull { it.passFlagId == "proofB" }
                val missing = needB?.clueIds?.count { !state.ownedClues.contains(it) } ?: 0
                if (missing > 0) "补全行动线：还差 $missing 条线索" else "去推理工坊验证证据链"
            }
            Stage.DEDUCE -> "在推理工坊验证证据链"
            Stage.JUDGE -> "作出最终判断（不可撤销）"
            Stage.ENDING -> "查看结局"
            Stage.FINISHED -> "本局已完结"
        }
    }

    /** 事件流水回放：不走门控，按 seq 折叠效果；重复 seq 幂等（TC-24 / TC-25）。 */
    fun replay(case: CaseFile, log: List<LogEntry>, base: PlayerState = PlayerState()): PlayerState {
        var state = seedDefaultScenes(case, base)
        val seen = mutableSetOf<Int>()
        for (entry in log) {
            if (!seen.add(entry.seq)) continue
            val node = case.node(entry.nodeId) ?: continue
            val effect = node.effect
            val flags = state.flags.toMutableMap()
            effect.setFlags.forEach { (k, v) -> flags[k] = v }
            val closed = (state.closedNodes + effect.closeNodes + node.exclusiveWith)
                .filter { it != node.id }
                .distinct()
                .sorted()
            state = state.copy(
                stage = effect.stage ?: state.stage,
                ownedClues = (state.ownedClues + effect.grantClues).distinct().sorted(),
                unlockedScenes = (state.unlockedScenes + effect.unlockScenes).distinct().sorted(),
                flags = flags,
                closedNodes = closed,
                appliedNodes = (state.appliedNodes + node.id).distinct().sorted(),
                seq = entry.seq,
            )
        }
        return state
    }
}

/** 一条事件流水（与 t_event_log 对应）。 */
data class LogEntry(val seq: Int, val nodeId: String, val choiceId: String? = null)
