package com.goexercise.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.Composable
import com.goexercise.app.navigation.AppNavHost
import com.goexercise.app.ui.theme.AppTheme
import com.goexercise.app.ui.theme.GOExerciseTheme
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        setContent { App() }
    }
}

@Composable
private fun App() {
    // P0: 既定テーマ固定。テーマ切替UI + DataStore 永続化(iOS の UserDefaults 相当)は
    // 永続層フェーズで追加する。
    GOExerciseTheme(theme = AppTheme.Peach) {
        AppNavHost()
    }
}
