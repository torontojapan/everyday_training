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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.goexercise.app.presentation.history.HistoryRoute
import com.goexercise.app.presentation.home.HomeRoute
import com.goexercise.app.presentation.record.RecordRoute
import com.goexercise.app.presentation.rescue.RescueRoute
import com.goexercise.app.presentation.settings.SettingsRoute
import com.goexercise.app.ui.theme.LocalAppPalette

private const val WEIGHT_ROUTE = "weight" // AppRoute(ディープリンク正本)に無いタブ専用 route
private const val RESCUE_ROUTE = "rescue" // フリーズ使用(履歴から遷移する詳細画面)

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

    // goexercise:// を解決して遷移(feature flag で friends→home 振替)。friendCode はフレンド画面実装時に消費。
    LaunchedEffect(deepLinkUri) {
        val uri = deepLinkUri ?: return@LaunchedEffect
        val (route, _) = DeepLink.resolve(uri)
        route?.let {
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
                        )
                        AppRoute.Record -> RecordRoute(
                            onSaved = { navController.popBackStack() },
                            onBack = { navController.popBackStack() },
                        )
                        AppRoute.Settings -> SettingsRoute()
                        AppRoute.History -> HistoryRoute(
                            onUseRescue = { navController.navigate(RESCUE_ROUTE) },
                        )
                        else -> RoutePlaceholder(route.path)
                    }
                }
            }
            // 体重タブ(AppRoute 外)。premium=P1.x で本実装。
            composable(WEIGHT_ROUTE) { RoutePlaceholder(WEIGHT_ROUTE) }
            // フリーズ使用(履歴から遷移)。
            composable(RESCUE_ROUTE) { RescueRoute(onBack = { navController.popBackStack() }) }
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
