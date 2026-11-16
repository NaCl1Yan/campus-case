plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
}

android {
    namespace = "com.nacl1yan.campuscase"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.nacl1yan.campuscase"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "1.0.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures {
        compose = true
    }
}

dependencies {
    implementation(project(":domain"))

    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.navigation.compose)
    debugImplementation(libs.androidx.compose.ui.tooling)
}

/**
 * 内容单源（AC-19）：构建期把 shared/case 复制到 assets，副本不入库。
 * 与 tools/sync-case.ps1 是同一件事的两个入口（IDE 用 Gradle，命令行用脚本）。
 */
val syncCaseContent by tasks.registering(Copy::class) {
    from(rootProject.layout.projectDirectory.dir("../shared/case")) {
        include("*.json")
        exclude("case.schema.json")
    }
    into(layout.projectDirectory.dir("src/main/assets/case"))
}

tasks.matching { it.name.startsWith("pre") && it.name.endsWith("Build") }.configureEach {
    dependsOn(syncCaseContent)
}
