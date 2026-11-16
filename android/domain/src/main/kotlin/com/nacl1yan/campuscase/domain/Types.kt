@file:OptIn(kotlinx.serialization.InternalSerializationApi::class)

package com.nacl1yan.campuscase.domain

import kotlinx.serialization.KSerializer
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.builtins.serializer
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.descriptors.StructureKind
import kotlinx.serialization.descriptors.buildSerialDescriptor
import kotlinx.serialization.encoding.CompositeDecoder
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder

/**
 * 内容 JSON 里 setFlags 用紧凑写法 `[["accepted", true]]`。
 * kotlinx 默认把 Pair 序列化成对象（first/second 两个字段），与内容格式不符，
 * 因此这里按"两元素数组"自定义序列化；ArkTS 侧 tuple 本身就是数组，无需处理。
 */
object FlagPairSerializer : KSerializer<Pair<String, Boolean>> {
    override val descriptor: SerialDescriptor =
        buildSerialDescriptor("FlagPair", StructureKind.LIST) {
            element("flag", String.serializer().descriptor)
            element("value", Boolean.serializer().descriptor)
        }

    override fun serialize(encoder: Encoder, value: Pair<String, Boolean>) {
        val out = encoder.beginStructure(descriptor)
        out.encodeStringElement(descriptor, 0, value.first)
        out.encodeBooleanElement(descriptor, 1, value.second)
        out.endStructure(descriptor)
    }

    override fun deserialize(decoder: Decoder): Pair<String, Boolean> {
        val input = decoder.beginStructure(descriptor)
        var flag = ""
        var value = false
        while (true) {
            when (val index = input.decodeElementIndex(descriptor)) {
                0 -> flag = input.decodeStringElement(descriptor, 0)
                1 -> value = input.decodeBooleanElement(descriptor, 1)
                CompositeDecoder.DECODE_DONE -> break
                else -> error("FlagPair 期望 2 个元素，遇到索引 $index")
            }
        }
        input.endStructure(descriptor)
        return flag to value
    }
}

object FlagListSerializer : KSerializer<List<Pair<String, Boolean>>> by
    ListSerializer(FlagPairSerializer)

// ---------------------------------------------------------------- 枚举

@Serializable
enum class Stage {
    @SerialName("PROLOGUE") PROLOGUE,
    @SerialName("ACCEPT") ACCEPT,
    @SerialName("EXPLORE") EXPLORE,
    @SerialName("DEDUCE") DEDUCE,
    @SerialName("JUDGE") JUDGE,
    @SerialName("ENDING") ENDING,
    @SerialName("FINISHED") FINISHED,
}

@Serializable
enum class ClueType { PHYSICAL, TESTIMONY, TIMELINE }

enum class NodeState { LOCKED, AVAILABLE, DONE, CLOSED }

// ---------------------------------------------------------------- 内容模型（与 case.schema.json 对应）

@Serializable
data class Condition(
    val allClues: List<String> = emptyList(),
    val anyClues: List<String> = emptyList(),
    val allFlags: List<String> = emptyList(),
    val anyFlags: List<String> = emptyList(),
    val noneFlags: List<String> = emptyList(),
    val minStage: Stage? = null,
    val closedNodes: List<String> = emptyList(),
)

@Serializable
data class Effect(
    val grantClues: List<String> = emptyList(),
    @Serializable(with = FlagListSerializer::class)
    val setFlags: List<Pair<String, Boolean>> = emptyList(),
    val unlockScenes: List<String> = emptyList(),
    val closeNodes: List<String> = emptyList(),
    val stage: Stage? = null,
)

@Serializable
data class TimelineItem(val time: String, val text: String)

@Serializable
data class Brief(
    val client: String,
    val summary: String,
    val objectives: List<String> = emptyList(),
    val timeline: List<TimelineItem> = emptyList(),
)

@Serializable
data class Hotspot(
    val id: String,
    val nodeId: String,
    val x: Double,
    val y: Double,
    val r: Double? = null,
    val lockedHint: String? = null,
)

@Serializable
data class Scene(
    val id: String,
    val name: String,
    val desc: String,
    val bgAsset: String? = null,
    val enterFx: String? = null,
    val unlockCond: Condition = Condition(),
    val hotspots: List<Hotspot> = emptyList(),
)

@Serializable
data class EventNode(
    val id: String,
    val sceneId: String,
    val title: String,
    val body: String = "",
    val unlockCond: Condition = Condition(),
    val effect: Effect = Effect(),
    val exclusiveWith: List<String> = emptyList(),
    val repeatable: Boolean = false,
)

@Serializable
data class Clue(
    val id: String,
    val name: String,
    val type: ClueType,
    val chainId: String? = null,
    val desc: String = "",
    val hintWhenMissing: String? = null,
)

@Serializable
data class CombineRule(
    val id: String,
    val inputs: List<String>,
    val chainId: String,
    val grantsFlag: String,
    val conclusion: String = "",
)

@Serializable
data class Chain(
    val id: String,
    val name: String,
    val clueIds: List<String> = emptyList(),
    val ruleFlagIds: List<String> = emptyList(),
    val passFlagId: String,
)

@Serializable
data class ProveStage(
    val id: String,
    val question: String,
    val slots: Int,
    val poolCond: Condition = Condition(),
    val answer: List<String> = emptyList(),
    val onPass: Effect = Effect(),
    val hints: List<String> = emptyList(),
)

@Serializable
data class Ending(
    val id: String,
    val name: String,
    val choiceId: String,
    val requires: Condition = Condition(),
    val segments: List<String> = emptyList(),
)

@Serializable
data class FinalChoice(
    val id: String,
    val label: String,
    val requiresFlag: String,
)

@Serializable
data class CaseFile(
    val id: String,
    val title: String,
    val subtitle: String = "",
    val contentVersion: Int,
    val brief: Brief,
    val scenes: List<Scene> = emptyList(),
    val nodes: List<EventNode> = emptyList(),
    val clues: List<Clue> = emptyList(),
    val rules: List<CombineRule> = emptyList(),
    val chains: List<Chain> = emptyList(),
    val proveStages: List<ProveStage> = emptyList(),
    val endings: List<Ending> = emptyList(),
    val finalChoices: List<FinalChoice> = emptyList(),
) {
    fun node(id: String): EventNode? = nodes.firstOrNull { it.id == id }
    fun scene(id: String): Scene? = scenes.firstOrNull { it.id == id }
}

// ---------------------------------------------------------------- 运行态（唯一可变真源，跨端字段名一致）

@Serializable
data class PlayerState(
    val caseId: String = "campus_001",
    val contentVersion: Int = 1,
    val seq: Int = 0,
    val stage: Stage = Stage.PROLOGUE,
    val unlockedScenes: List<String> = emptyList(),
    val ownedClues: List<String> = emptyList(),
    val flags: Map<String, Boolean> = emptyMap(),
    val closedNodes: List<String> = emptyList(),
    val appliedNodes: List<String> = emptyList(),
    val passedStages: List<String> = emptyList(),
    val finalChoice: String? = null,
    val endingId: String? = null,
    val playMs: Long = 0L,
    val savedAt: Long = 0L,
)

// ---------------------------------------------------------------- 结果与错误码（两端一致）

object Errs {
    const val NODE_LOCKED = "E_NODE_LOCKED"
    const val NODE_CLOSED = "E_NODE_CLOSED"
    const val UNKNOWN_NODE = "E_UNKNOWN_NODE"
    const val INVALID_TRANSITION = "E_STATE_INVALID_TRANSITION"
    const val CHAIN_NOT_READY = "E_CHAIN_NOT_READY"
    const val FINAL_MISMATCH = "E_FINAL_MISMATCH"
}

data class ApplyOutcome(
    val ok: Boolean,
    val state: PlayerState,
    val error: String? = null,
    val noop: Boolean = false,
)

data class CombineOutcome(
    val ok: Boolean,
    val ruleId: String? = null,
    val grantsFlag: String? = null,
    val reason: String? = null,
)

data class EndingOutcome(
    val canPublic: Boolean,
    val canPrivate: Boolean,
    val ready: Boolean,
    val endingId: String? = null,
)

/** 空条件 = 恒真（用于判定"开局场景"）。 */
fun Condition.isEmpty(): Boolean =
    allClues.isEmpty() && anyClues.isEmpty() && allFlags.isEmpty() &&
        anyFlags.isEmpty() && noneFlags.isEmpty() && minStage == null && closedNodes.isEmpty()
