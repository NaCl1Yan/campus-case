package com.nacl1yan.campuscase.domain

import kotlinx.serialization.json.Json

/** 测试资源读取：内容与 fixtures 都来自仓库根的 shared/（单源，不复制）。 */
object TestResources {

    private val json = Json {
        ignoreUnknownKeys = true
        explicitNulls = false
    }

    fun text(path: String): String {
        val stream = TestResources::class.java.getResourceAsStream(path)
            ?: error("找不到测试资源 $path（检查 domain/build.gradle.kts 的 sourceSets.test.resources）")
        return stream.bufferedReader(Charsets.UTF_8).use { it.readText() }
    }

    fun case(): CaseFile =
        CaseLoader.parse(text("/case/campus_001.json")).getOrElse {
            error("案件内容解析失败：${it.message}")
        }

    fun fixture(name: String): String = text("/fixtures/$name.json")

    fun json(): Json = json
}
