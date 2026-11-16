package com.nacl1yan.campuscase.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val LightColors = lightColorScheme(
    primary = Color(0xFF26324A),
    secondary = Color(0xFF6B7280),
    background = Color(0xFFFDFDFD),
    surface = Color(0xFFFFFFFF),
    onPrimary = Color(0xFFFFFFFF),
    onBackground = Color(0xFF1A1C1E),
)

/**
 * 主题只放 token；字号缩放由 LocalDensity 与设置项共同决定（03 §10）。
 * 深色模式在 M3 接系统 uiMode（P1）。
 */
@Composable
fun CampusCaseTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = LightColors,
        content = content,
    )
}
