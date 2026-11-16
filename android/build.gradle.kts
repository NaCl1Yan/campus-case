// 根构建脚本：只声明插件版本，不配置任何模块
plugins {
    alias(libs.plugins.kotlin.jvm) apply false
    alias(libs.plugins.kotlin.serialization) apply false
}
