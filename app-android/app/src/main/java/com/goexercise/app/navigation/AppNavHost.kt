package com.goexercise.app.navigation

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
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
import com.goexercise.app.presentation.settings.SettingsRoute
import com.goexercise.app.presentation.weight.WeightRoute
import com.goexercise.app.ui.theme.LocalAppPalette

private const val WEIGHT_ROUTE = "weight" // AppRoute(ディープリンク正本)に無いタブ専用 route
private const val RESCUE_ROUTE = "rescue" // フリーズ使用(履歴から遷移する詳細画面)
private const val PREMIUM_ROUTE = "premium" // GOプレミアム ペイウォール(#6)。?ctx= で文脈を渡す

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
    val showBottomBar = tabs.any { it.route == currentRoute }

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

    Scaffold(
        bottomBar = {
            if (showBottomBar) {
                NavigationBar {
                    tabs.forEach { tab ->
                        NavigationBarItem(
                            selected = currentRoute == tab.route,
                            onClick = { navController.navigateToTab(tab.route) },
                            icon = { Text(tab.emoji) },
                            label = { Text(tab.label) },
                        )
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
                            onSaved = { navController.popBackStack() },
                            onBack = { navController.popBackStack() },
                        )
                        AppRoute.Settings -> SettingsRoute(
                            onOpenPremium = { navController.navigate("$PREMIUM_ROUTE/${PaywallContext.General.name}") },
                        )
                        AppRoute.History -> HistoryRoute(
                            onUseRescue = { navController.navigate(RESCUE_ROUTE) },
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
            // フリーズ使用(履歴から遷移)。無料枠なら paywall(freeze 文脈)へ誘導。
            composable(RESCUE_ROUTE) {
                RescueRoute(
                    onBack = { navController.popBackStack() },
                    onUpgrade = { navController.navigate("$PREMIUM_ROUTE/${PaywallContext.Freeze.name}") },
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
