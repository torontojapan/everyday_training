package com.goexercise.app

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.goexercise.app.navigation.AppNavHost
import com.goexercise.app.presentation.settings.SettingsViewModel
import com.goexercise.app.ui.theme.GOExerciseTheme
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {

    // goexercise:// ディープリンクの保留 URI。onCreate / onNewIntent で更新し、Compose 側で消費する。
    private var pendingDeepLink by mutableStateOf<String?>(null)

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        pendingDeepLink = intent?.dataString
        setContent {
            App(
                deepLinkUri = pendingDeepLink,
                onDeepLinkConsumed = { pendingDeepLink = null },
            )
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        pendingDeepLink = intent.dataString
    }
}

@Composable
private fun App(
    deepLinkUri: String?,
    onDeepLinkConsumed: () -> Unit,
) {
    // 永続化済みテーマ(DataStore)を購読してアプリ全体に適用。設定画面の切替が即反映される。
    val settingsViewModel: SettingsViewModel = hiltViewModel()
    val theme by settingsViewModel.theme.collectAsStateWithLifecycle()
    GOExerciseTheme(theme = theme) {
        AppNavHost(deepLinkUri = deepLinkUri, onDeepLinkConsumed = onDeepLinkConsumed)
    }
}
