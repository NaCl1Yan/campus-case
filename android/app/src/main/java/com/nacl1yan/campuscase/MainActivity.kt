package com.nacl1yan.campuscase

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.nacl1yan.campuscase.ui.LaunchScreen
import com.nacl1yan.campuscase.ui.theme.CampusCaseTheme

/**
 * 单 Activity + Compose（03 文档 §2）。
 * M1 只挂一个骨架页；M3 会换成 NavHost（Launch → Brief → Hub → SceneRoom → …）。
 */
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            CampusCaseTheme {
                LaunchScreen()
            }
        }
    }
}
