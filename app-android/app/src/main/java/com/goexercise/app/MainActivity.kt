package com.goexercise.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.goexercise.app.navigation.AppNavHost
import com.goexercise.app.presentation.settings.SettingsViewModel
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
    // 永続化済みテーマ(DataStore)を購読してアプリ全体に適用。設定画面の切替が即反映される。
    val settingsViewModel: SettingsViewModel = hiltViewModel()
    val theme by settingsViewModel.theme.collectAsStateWithLifecycle()
    GOExerciseTheme(theme = theme) {
        AppNavHost()
    }
}
