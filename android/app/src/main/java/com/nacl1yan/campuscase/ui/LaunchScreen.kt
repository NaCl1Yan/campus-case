package com.nacl1yan.campuscase.ui

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.ui.unit.sp
import com.nacl1yan.campuscase.domain.CaseFile
import com.nacl1yan.campuscase.domain.CaseLoader
import com.nacl1yan.campuscase.domain.Engine

/**
 * M1 骨架页：只验证"内容能被读到 + 引擎能算"，不做视觉。
 * 与鸿蒙侧 pages/Index.ets 行为一致，便于对照排错。
 */
@Composable
fun LaunchScreen() {
    val context = LocalContext.current

    val loaded: Result<CaseFile> = remember {
        runCatching {
            val text = context.assets.open("case/campus_001.json")
                .bufferedReader(Charsets.UTF_8)
                .use { it.readText() }
            CaseLoader.parse(text).getOrThrow()
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        verticalArrangement = Arrangement.Center,
    ) {
        loaded.fold(
            onSuccess = { case ->
                val state = Engine.initialState(case)
                val problems = CaseLoader.validate(case)
                Text(case.title, style = MaterialTheme.typography.titleLarge)
                Spacer(Modifier.height(12.dp))
                Text("阶段：${state.stage.name}")
                Text("目标：${Engine.nextObjective(state, case)}")
                Text("进度：${Engine.computeProgress(state, case)}%")
                Text("线索：${state.ownedClues.size} / ${case.clues.size}")
                Spacer(Modifier.height(12.dp))
                Text(
                    text = if (problems.isEmpty()) "内容校验通过" else problems.joinToString("; "),
                    color = MaterialTheme.colorScheme.secondary,
                    fontSize = 13.sp,
                )
            },
            onFailure = { error ->
                Text("（未加载内容）", style = MaterialTheme.typography.titleLarge)
                Spacer(Modifier.height(12.dp))
                Text("内容未同步：请在仓库根执行 tools/sync-case.ps1，或直接 ./gradlew :app:assembleDebug")
                Text("${error.message}", color = MaterialTheme.colorScheme.secondary, fontSize = 13.sp)
            },
        )
    }
}
