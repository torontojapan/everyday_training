package com.goexercise.app.navigation

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.goexercise.app.presentation.friends.FriendsRoute
import com.goexercise.app.presentation.friends.WeeklyRankingRoute
import com.goexercise.app.presentation.history.HistoryRoute
import com.goexercise.app.presentation.home.HomeRoute
import com.goexercise.app.presentation.premium.PaywallContext
import com.goexercise.app.presentation.premium.PremiumPaywallRoute
import com.goexercise.app.presentation.record.RecordRoute
import com.goexercise.app.presentation.rescue.RescueRoute
import com.goexercise.app.presentation.share.StreakShareRoute
import com.goexercise.app.presentation.share.HighlightShareRoute
import com.goexercise.app.presentation.record.RecordCompletionRoute
import com.goexercise.app.presentation.settings.SettingsRoute
import com.goexercise.app.presentation.weight.WeightRoute
import com.goexercise.app.ui.theme.LocalAppPalette

private const val WEIGHT_ROUTE = "weight" // AppRoute(ディープリンク正本)に無いタブ専用 route
private const val RESCUE_ROUTE = "rescue" // フリーズ使用(履歴から遷移する詳細画面)
private const val HIGHLIGHT_ROUTE = "highlight-share" // ハイライト共有(履歴から weekly/monthly/alltime で遷移)
private const val RECORD_COMPLETION_ROUTE = "record-completion" // 記録完了の祝福画面(保存後に着地)
private const val PREMIUM_ROUTE = "premium" // GOプレミアム ペイウォール(#6)。?ctx= で文脈を渡す
private const val MENSTRUAL_ROUTE = "menstrual" // 生理日まとめ入力(履歴から遷移する専用カレンダー)

/**
 * アプリの骨格。ボトムタブ(home/履歴/体重/友達/設定)を持つ Scaffold + NavHost。
 * 記録入力(record)等の詳細画面ではボトムバーを隠す。iOS `MainTabView` 相当。
 */
@Composable
fun AppNavHost(
    navController: NavHostController = rememberNavController(),
    deepLinkUri: String? = null,
    onDeepLinkConsumed: () -> Unit = {},
) {
    val backStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = backStackEntry?.destination?.route
    val tabs = BottomTab.visible()
    // iOS は menstrual/rescue/ランキングを各タブの NavigationStack 内に push するためタブバーが残る。
    // Android もこれらの詳細ルートではボトムバーを維持し、親タブを選択状態にする(iOS パリティ)。
    val detailParentTab = mapOf(
        MENSTRUAL_ROUTE to AppRoute.History.path,
        RESCUE_ROUTE to AppRoute.History.path,
        AppRoute.WeeklyRanking.path to AppRoute.Friends.path,
        // 記録完了は iOS では home タブの NavigationStack 内 push → タブバー(ホーム選択)が残る。
        RECORD_COMPLETION_ROUTE to AppRoute.Home.path,
    )
    val parentTabRoute = detailParentTab[currentRoute]
    val showBottomBar = tabs.any { it.route == currentRoute } || parentTabRoute != null

    // friends に着地した deep link の検証済みコード。FriendsRoute が消費し追加シートを開く。
    var pendingFriendCode by rememberSaveable { mutableStateOf<String?>(null) }

    // goexercise:// を解決して遷移(feature flag で friends→home 振替)。
    LaunchedEffect(deepLinkUri) {
        val uri = deepLinkUri ?: return@LaunchedEffect
        val (route, code) = DeepLink.resolve(uri)
        route?.let {
            if (it == AppRoute.Friends && code != null) pendingFriendCode = code
            navController.navigate(it.path) { launchSingleTop = true } // 同一 deep link で重複積みしない
        }
        onDeepLinkConsumed()
    }

    val palette = com.goexercise.app.ui.theme.LocalAppPalette.current
    Scaffold(
        containerColor = palette.background,
        bottomBar = {
            if (showBottomBar) {
                // iOS は浮いた角丸の「島」型タブバー(白地・余白付き・影)。Material の全幅バーでなく
                // Surface でラップして角丸 + インセット + 影にし、iOS build 12 の見た目に合わせる。
                androidx.compose.material3.Surface(
                    color = palette.surface,
                    shape = androidx.compose.foundation.shape.RoundedCornerShape(28.dp),
                    shadowElevation = 8.dp,
                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 10.dp),
                ) {
                    NavigationBar(containerColor = androidx.compose.ui.graphics.Color.Transparent) {
                        tabs.forEach { tab ->
                            NavigationBarItem(
                                selected = currentRoute == tab.route || parentTabRoute == tab.route,
                                onClick = { navController.navigateToTab(tab.route) },
                                icon = { Icon(tab.icon, contentDescription = tab.label) },
                                label = { Text(tab.label) },
                                colors = androidx.compose.material3.NavigationBarItemDefaults.colors(
                                    selectedIconColor = palette.primaryDeep,
                                    selectedTextColor = palette.primaryDeep,
                                    indicatorColor = palette.primary.copy(alpha = 0.22f),
                                    unselectedIconColor = palette.textPrimary,
                                    unselectedTextColor = palette.textSecondary,
                                ),
                            )
                        }
                    }
                }
            }
        },
    ) { innerPadding ->
        NavHost(
            navController = navController,
            startDestination = AppRoute.Home.path,
            modifier = Modifier.padding(innerPadding),
        ) {
            AppRoute.entries.forEach { route ->
                composable(route.path) {
                    when (route) {
                        AppRoute.Home -> HomeRoute(
                            onRecordClick = { navController.navigate(AppRoute.Record.path) },
                            onShareClick = { navController.navigate(AppRoute.StreakShare.path) },
                            onOpenFreezePaywall = { navController.navigate("$PREMIUM_ROUTE/${PaywallContext.Freeze.name}") },
                        )
                        AppRoute.StreakShare -> StreakShareRoute(
                            onBack = { navController.popBackStack() },
                        )
                        AppRoute.Record -> RecordRoute(
                            // 保存後は記録完了の祝福画面へ(Record をスタックから外す=戻るでホーム)。iOS RecordCompletionView パリティ。
                            onSaved = {
                                navController.navigate(RECORD_COMPLETION_ROUTE) {
                                    popUpTo(AppRoute.Record.path) { inclusive = true }
                                }
                            },
                            onBack = { navController.popBackStack() },
                        )
                        AppRoute.Settings -> SettingsRoute(
                            onOpenPremium = { navController.navigate("$PREMIUM_ROUTE/${PaywallContext.General.name}") },
                        )
                        // 通知設定の deep link(goexercise://notification-settings, iOS は専用 View)。
                        // Android は通知設定(リマインダー)を Settings 内 ReminderSection に持つため、
                        // 専用画面を作らず Settings に着地させる(従来のプレースホルダ行き止まりを解消)。
                        AppRoute.NotificationSettings -> SettingsRoute(
                            onOpenPremium = { navController.navigate("$PREMIUM_ROUTE/${PaywallContext.General.name}") },
                        )
                        AppRoute.History -> HistoryRoute(
                            onUseRescue = { navController.navigate(RESCUE_ROUTE) },
                            onOpenHighlight = { kind -> navController.navigate("$HIGHLIGHT_ROUTE/$kind") },
                            onOpenPremium = { navController.navigate("$PREMIUM_ROUTE/${PaywallContext.General.name}") },
                            onOpenMenstrual = { navController.navigate(MENSTRUAL_ROUTE) },
                        )
                        AppRoute.Friends -> FriendsRoute(
                            onOpenRanking = { navController.navigate(AppRoute.WeeklyRanking.path) },
                            pendingFriendCode = pendingFriendCode,
                            onCodeConsumed = { pendingFriendCode = null },
                        )
                        AppRoute.WeeklyRanking -> WeeklyRankingRoute(
                            onBack = { navController.popBackStack() },
                        )
                        else -> RoutePlaceholder(route.path)
                    }
                }
            }
            // 体重タブ(premium。未加入は paywall[weight 文脈]へ)。
            composable(WEIGHT_ROUTE) {
                WeightRoute(onOpenPremium = { navController.navigate("$PREMIUM_ROUTE/${PaywallContext.Weight.name}") })
            }
            // 生理日まとめ入力(履歴の entry-row から遷移)。周期トラッキング ON のときだけ到達。
            composable(MENSTRUAL_ROUTE) {
                com.goexercise.app.presentation.history.MenstrualEntryRoute(onBack = { navController.popBackStack() })
            }
            // フリーズ使用(履歴から遷移)。無料枠なら paywall(freeze 文脈)へ誘導。
            composable(RESCUE_ROUTE) {
                RescueRoute(
                    onBack = { navController.popBackStack() },
                    onUpgrade = { navController.navigate("$PREMIUM_ROUTE/${PaywallContext.Freeze.name}") },
                )
            }
            // ハイライト共有カード(履歴から weekly/monthly/alltime。VM が kind を SavedStateHandle で受ける)。
            composable("$HIGHLIGHT_ROUTE/{kind}") {
                HighlightShareRoute(onBack = { navController.popBackStack() })
            }
            // 記録完了の祝福画面(保存後に着地)。ホームに戻る / もう一種目を記録する。iOS RecordCompletionView パリティ。
            composable(RECORD_COMPLETION_ROUTE) {
                RecordCompletionRoute(
                    onDone = { navController.popBackStack() },
                    onRecordAgain = {
                        navController.navigate(AppRoute.Record.path) {
                            popUpTo(RECORD_COMPLETION_ROUTE) { inclusive = true }
                        }
                    },
                )
            }
            // GOプレミアム ペイウォール(#6)。ctx で見出しを出し分ける。
            composable("$PREMIUM_ROUTE/{ctx}") { entry ->
                val ctx = runCatching { PaywallContext.valueOf(entry.arguments?.getString("ctx") ?: "") }
                    .getOrDefault(PaywallContext.General)
                PremiumPaywallRoute(context = ctx, onClose = { navController.popBackStack() })
            }
        }
    }
}

/** タブ選択時のナビ。バックスタックを積まず状態を保存/復元する(標準のタブ挙動)。 */
private fun NavHostController.navigateToTab(route: String) {
    navigate(route) {
        popUpTo(graph.findStartDestination().id) { saveState = true }
        launchSingleTop = true
        restoreState = true
    }
}

@Composable
private fun RoutePlaceholder(route: String) {
    val palette = LocalAppPalette.current
    Column(
        modifier = Modifier.fillMaxSize().padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(text = route, style = MaterialTheme.typography.titleLarge, color = palette.textPrimary)
        Text(text = "(この画面は今後のフェーズで実装)", style = MaterialTheme.typography.bodySmall, color = palette.textSecondary)
    }
}
