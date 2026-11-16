plugins {
    alias(libs.plugins.kotlin.jvm)
    alias(libs.plugins.kotlin.serialization)
}

kotlin {
    jvmToolchain(17)
}

// 纯 JVM 模块：不依赖 Android SDK、不依赖 Context，单测直接跑
dependencies {
    implementation(libs.kotlinx.serialization.json)

    testImplementation(libs.junit.jupiter)
    testRuntimeOnly(libs.junit.platform.launcher)
}

// 一致性用例与内容文件来自仓库根的 shared/（单源，不复制进仓库）
sourceSets {
    test {
        resources.srcDir(layout.projectDirectory.dir("../../shared"))
    }
}

tasks.test {
    useJUnitPlatform()
    testLogging {
        events("passed", "failed", "skipped")
        showStandardStreams = false
    }
}
