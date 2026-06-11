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
import androidx.lifecycle.lifecycleScope
import com.goexercise.app.navigation.AppNavHost
import com.goexercise.app.presentation.friends.RealAccountAuthCoordinator
import com.goexercise.app.presentation.onboarding.OnboardingScreen
import com.goexercise.app.presentation.onboarding.OnboardingViewModel
import com.goexercise.app.presentation.settings.SettingsViewModel
import com.goexercise.app.ui.theme.GOExerciseTheme
import androidx.glance.appwidget.updateAll
import com.goexercise.app.widget.StreakWidget
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.launch

@AndroidEntryPoint
class MainActivity : ComponentActivity() {

    // goexercise:// ディープリンクの保留 URI。onCreate / onNewIntent で更新し、Compose 側で消費する。
    private var pendingDeepLink by mutableStateOf<String?>(null)

    @javax.inject.Inject lateinit var referralStore: com.goexercise.app.data.referral.ReferralStore
    @javax.inject.Inject lateinit var recordSync: com.goexercise.app.data.backup.RecordSyncCoordinator

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        if (com.goexercise.app.AppFeatureFlags.isReferralActive) {
            lifecycleScope.launch {
                referralStore.refresh()
                referralStore.pollReferrerPops()
            }
        }
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

    override fun onStop() {
        super.onStop()
        // アプリを離れる時にホーム画面ウィジェットを更新する。Glance の updatePeriodMillis(30分)を
        // 待たず、直前の記録/削除/猫変更/フリーズ使用を反映する(最も低結合な単一トリガ)。
        lifecycleScope.launch { runCatching { StreakWidget().updateAll(applicationContext) } }
        // バックグラウンド移行時にバックアップ同期(iOS scenePhase .background と対称。OFF なら即 return)。
        lifecycleScope.launch { runCatching { recordSync.syncNow() } }
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
    val onboardingViewModel: OnboardingViewModel = hiltViewModel()
    val onboarded by onboardingViewModel.isComplete.collectAsStateWithLifecycle()
    GOExerciseTheme(theme = theme) {
        when (onboarded) {
            // null=DataStore 読込前。チラつき防止に何も出さない(直後に false/true が来る)。
            null -> Unit
            false -> OnboardingScreen(onFinish = onboardingViewModel::complete, viewModel = onboardingViewModel)
            true -> AppNavHost(deepLinkUri = deepLinkUri, onDeepLinkConsumed = onDeepLinkConsumed)
        }
    }
}
