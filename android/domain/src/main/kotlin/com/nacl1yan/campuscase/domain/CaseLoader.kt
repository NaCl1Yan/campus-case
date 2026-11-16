package com.nacl1yan.campuscase.domain

import kotlinx.serialization.json.Json

/**
 * 内容加载与校验（01 文档 FR-16）。
 * 解析失败与校验失败都必须"收集全部错误后一次性返回"，不允许 fail-fast、不允许崩溃。
 */
object CaseLoader {

    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
        explicitNulls = false
    }

    fun parse(text: String): Result<CaseFile> =
        runCatching { json.decodeFromString(CaseFile.serializer(), text) }

    fun parseOrNull(text: String): CaseFile? = parse(text).getOrNull()

    /** 校验清单与 docs/01 FR-16 的 8 条一一对应。返回空列表表示通过。 */
    fun validate(case: CaseFile): List<String> {
        val errors = mutableListOf<String>()

        if (case.scenes.size < 3) errors += "规模下限不满足: scenes 需 ≥3，实际 ${case.scenes.size}"
        if (case.nodes.size < 12) errors += "规模下限不满足: nodes 需 ≥12，实际 ${case.nodes.size}"
        if (case.clues.size < 6) errors += "规模下限不满足: clues 需 ≥6，实际 ${case.clues.size}"
        if (case.rules.size < 3) errors += "规模下限不满足: rules 需 ≥3，实际 ${case.rules.size}"
        if (case.chains.size < 2) errors += "规模下限不满足: chains 需 ≥2，实际 ${case.chains.size}"
        if (case.endings.size < 2) errors += "规模下限不满足: endings 需 ≥2，实际 ${case.endings.size}"

        val sceneIds = case.scenes.map { it.id }.toSet()
        val nodeIds = case.nodes.map { it.id }.toSet()
        val clueIds = case.clues.map { it.id }.toSet()
        val chainIds = case.chains.map { it.id }.toSet()
        val choiceIds = case.finalChoices.map { it.id }.toSet()

        // 1) 引用完整性：hotspot → node → scene
        case.scenes.forEach { scene ->
            if (scene.hotspots.isEmpty()) errors += "场景 ${scene.id} 没有热点"
            scene.hotspots.forEach { h ->
                val node = case.node(h.nodeId)
                if (node == null) errors += "热点 ${h.id} 指向不存在的节点 ${h.nodeId}"
                else if (node.sceneId != scene.id) {
                    errors += "热点 ${h.id} 所在场景 ${scene.id} 与节点场景 ${node.sceneId} 不一致"
                }
            }
        }

        // 2) 节点：场景存在、有非空效果、引用的线索/场景/节点存在
        case.nodes.forEach { node ->
            if (!sceneIds.contains(node.sceneId)) errors += "节点 ${node.id} 指向不存在的场景 ${node.sceneId}"
            val e = node.effect
            val hasEffect = e.grantClues.isNotEmpty() || e.setFlags.isNotEmpty() ||
                e.unlockScenes.isNotEmpty() || e.closeNodes.isNotEmpty() || e.stage != null
            if (!hasEffect) errors += "节点 ${node.id} 没有任何状态效果"
            e.grantClues.filter { !clueIds.contains(it) }
                .forEach { errors += "节点 ${node.id} 产出不存在的线索 $it" }
            e.unlockScenes.filter { !sceneIds.contains(it) }
                .forEach { errors += "节点 ${node.id} 解锁不存在的场景 $it" }
            (e.closeNodes + node.exclusiveWith).filter { !nodeIds.contains(it) }
                .forEach { errors += "节点 ${node.id} 关闭不存在的节点 $it" }
            (e.closeNodes + node.exclusiveWith).filter { it == node.id }
                .forEach { errors += "节点 ${node.id} 关闭了自己" }
        }

        // 3) 规则与证据链
        case.rules.forEach { rule ->
            rule.inputs.filter { !clueIds.contains(it) }
                .forEach { errors += "规则 ${rule.id} 引用不存在的线索 $it" }
            if (!chainIds.contains(rule.chainId)) errors += "规则 ${rule.id} 指向不存在的链 ${rule.chainId}"
            if (rule.inputs.toSet().size != 2) errors += "规则 ${rule.id} 的两个输入相同"
        }
        case.chains.forEach { chain ->
            chain.clueIds.filter { !clueIds.contains(it) }
                .forEach { errors += "链 ${chain.id} 引用不存在的线索 $it" }
            if (chain.ruleFlagIds.isEmpty()) errors += "链 ${chain.id} 没有规则 flag"
        }

        // 4) 推理关卡与结局
        case.proveStages.forEach { p ->
            p.answer.filter { !clueIds.contains(it) }
                .forEach { errors += "关卡 ${p.id} 答案引用不存在的线索 $it" }
            if (p.answer.size != p.slots) errors += "关卡 ${p.id} 槽位与答案数量不一致"
        }
        case.endings.forEach { ending ->
            if (!choiceIds.contains(ending.choiceId)) {
                errors += "结局 ${ending.id} 指向不存在的判断选项 ${ending.choiceId}"
            }
            ending.requires.allClues.filter { !clueIds.contains(it) }
                .forEach { errors += "结局 ${ending.id} 条件引用不存在的线索 $it" }
        }

        // 5) 线索必须可被获得（无死线索）
        val produced = case.nodes.flatMap { it.effect.grantClues }.toSet()
        (clueIds - produced).forEach { errors += "线索 $it 没有任何节点产出" }

        // 6) 至少一个开局场景
        if (case.scenes.none { it.unlockCond.isEmpty() }) {
            errors += "没有任何场景在开局可用（缺少空 unlockCond 的起始场景）"
        }

        // 7) 结局条件互斥
        if (case.endings.size >= 2) {
            val sets = case.endings.map { it.requires.allFlags.toSet() }
            if (sets[0] == sets[1]) errors += "两个结局的 requires 完全相同，无法互斥"
        }

        return errors
    }
}
