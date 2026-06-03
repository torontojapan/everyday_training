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
import com.goexercise.app.presentation.friends.RealAccountAuthCoordinator
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
        pendingDeepLink = consumeIntentUri(intent?.dataString)
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
        pendingDeepLink = consumeIntentUri(intent.dataString)
    }

    override fun onResume() {
        super.onResume()
        // Custom Tab を閉じて戻ってきた(callback 未配達)Apple web フローはキャンセル扱いで畳む。
        // redirect が onNewIntent で配達済みなら no-op(コルーチンのハング/leak 防止)。
        RealAccountAuthCoordinator.cancelPendingIfUnfinished()
    }

    /**
     * Apple web 連携(#10)の `goexercise://auth-callback` は通常の deep link ルーティングに流さず、
     * 進行中の WebAuthFlow へ届ける(iOS が callback を友達 deep link と分離するのと同じ衝突回避)。
     * それ以外の goexercise:// はそのまま deep link として返す。
     */
    private fun consumeIntentUri(uri: String?): String? {
        if (uri != null && uri.startsWith("goexercise://auth-callback")) {
            RealAccountAuthCoordinator.deliverCallback(uri)
            return null
        }
        return uri
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
