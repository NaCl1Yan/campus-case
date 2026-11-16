package com.nacl1yan.campuscase.domain

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * 双端一致性 runner（AC-18）：读取 shared/fixtures 下的 JSON 用例，
 * 用本端引擎求值并与期望做"部分匹配"。鸿蒙侧有同构的 runner。
 * 注意：Kotlin 块注释可嵌套，注释里不要出现斜杠加星号的组合（会打开嵌套注释）。
 */
class FixtureTest {

    private val case: CaseFile = TestResources.case()
    private val json: Json = TestResources.json()

    private val files = listOf("gate", "scene", "apply", "combine", "ending", "progress", "replay")

    @Test
    fun allFixturesPass() {
        val failures = mutableListOf<String>()
        var total = 0

        for (file in files) {
            val root = json.parseToJsonElement(TestResources.fixture(file)).jsonObject
            val kind = root.getValue("kind").jsonPrimitive.content
            for (element in root.getValue("cases").jsonArray) {
                total++
                val c = element.jsonObject
                val id = c.getValue("id").jsonPrimitive.content
                val actual = evaluate(kind, c.getValue("given").jsonObject)
                val errs = mutableListOf<String>()
                compare(actual, c.getValue("expect"), id, errs)
                failures += errs
            }
        }

        assertTrue(total >= 42, "fixture 数量异常：$total")
        assertTrue(failures.isEmpty(), "fixtures 失败 ${failures.size} 条：\n" + failures.joinToString("\n"))
    }

    private fun stateOf(element: JsonElement?): PlayerState =
        if (element == null) PlayerState()
        else json.decodeFromJsonElement(PlayerState.serializer(), element)

    private fun evaluate(kind: String, given: JsonObject): JsonObject = when (kind) {
        "gate" -> buildJsonObject {
            put("available", Engine.isNodeAvailable(stateOf(given["state"]), case, given.str("nodeId")))
        }

        "sceneGate" -> buildJsonObject {
            val scene = case.scene(given.str("sceneId"))
                ?: error("unknown scene ${given.str("sceneId")}")
            put("available", Engine.isSceneAvailable(stateOf(given["state"]), scene))
        }

        "apply" -> {
            val result = Engine.applyNode(stateOf(given["state"]), case, given.str("nodeId"))
            buildJsonObject {
                put("ok", result.ok)
                result.error?.let { put("error", it) }
                if (result.noop) put("noop", true)
                put("state", json.encodeToJsonElement(PlayerState.serializer(), result.state))
            }
        }

        "combine" -> {
            val result = Engine.checkCombine(stateOf(given["state"]), case, given.str("a"), given.str("b"))
            buildJsonObject {
                put("ok", result.ok)
                result.ruleId?.let { put("ruleId", it) }
                result.grantsFlag?.let { put("grantsFlag", it) }
                result.reason?.let { put("reason", it) }
            }
        }

        "ending" -> {
            val result = Engine.resolveEnding(stateOf(given["state"]), case)
            buildJsonObject {
                put("canPublic", result.canPublic)
                put("canPrivate", result.canPrivate)
                put("ready", result.ready)
                put("endingId", result.endingId)
            }
        }

        "progress" -> buildJsonObject {
            put("progress", Engine.computeProgress(stateOf(given["state"]), case))
        }

        "replay" -> {
            val log = given.getValue("log").jsonArray.map {
                val o = it.jsonObject
                LogEntry(o.getValue("seq").jsonPrimitive.content.toInt(), o.str("nodeId"))
            }
            val rebuilt = Engine.replay(case, log)
            buildJsonObject {
                put("state", json.encodeToJsonElement(PlayerState.serializer(), rebuilt))
            }
        }

        else -> error("未知 fixtures 类型 $kind")
    }

    // ---------------------------------------------------------------- 比较工具

    private fun JsonObject.str(key: String): String = getValue(key).jsonPrimitive.content

    private fun canon(element: JsonElement?): JsonElement = when (element) {
        null, JsonNull -> JsonNull
        is JsonArray -> JsonArray(element.map { canon(it) }.sortedBy { it.toString() })
        is JsonObject -> JsonObject(element.keys.sorted().associateWith { canon(element[it]) })
        else -> element
    }

    private fun compare(actual: JsonElement?, expect: JsonElement, path: String, out: MutableList<String>) {
        if (expect is JsonNull) {
            if (actual != null && actual !is JsonNull) out += "$path: 期望 null，实际 $actual"
            return
        }
        when (expect) {
            is JsonObject -> {
                if (actual !is JsonObject) {
                    out += "$path: 期望对象，实际 $actual"
                    return
                }
                for ((key, value) in expect) {
                    val child = actual[key]
                    if (child == null && value !is JsonNull) {
                        out += "$path.$key: 缺少字段"
                        continue
                    }
                    compare(child, value, "$path.$key", out)
                }
            }

            is JsonArray -> {
                val a = canon(actual)
                val e = canon(expect)
                if (a.toString() != e.toString()) out += "$path: 期望 $e，实际 $a"
            }

            is JsonPrimitive -> {
                if (expect.isString) {
                    if (actual?.jsonPrimitive?.content != expect.content) {
                        out += "$path: 期望 \"${expect.content}\"，实际 $actual"
                    }
                } else if (expect.booleanOrNull != null) {
                    if (actual?.jsonPrimitive?.booleanOrNull != expect.booleanOrNull) {
                        out += "$path: 期望 ${expect.booleanOrNull}，实际 $actual"
                    }
                } else {
                    val want = expect.doubleOrNull
                    val got = actual?.jsonPrimitive?.doubleOrNull
                    if (want == null || got == null || kotlin.math.abs(want - got) > 1e-6) {
                        out += "$path: 期望 $want，实际 $got"
                    }
                }
            }

            else -> Unit
        }
    }
}
