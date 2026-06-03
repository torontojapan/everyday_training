package com.goexercise.app.navigation

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.goexercise.app.ui.theme.LocalAppPalette

/**
 * P0 のナビ骨組み。iOS `AppRoute` の全ルートに対応する NavHost を張り、
 * いまは各ルートにプレースホルダ画面を割り当てる。実画面(ホーム/記録/履歴/設定/
 * 友達/週間ランキング等)は後続フェーズで差し替える。タブ/ディープリンク/通知タップは
 * この route 体系に集約する(iOS と同じ単一真実源)。
 */
@Composable
fun AppNavHost(
    navController: NavHostController = rememberNavController(),
) {
    NavHost(navController = navController, startDestination = AppRoute.Home.path) {
        AppRoute.entries.forEach { route ->
            composable(route.path) {
                RoutePlaceholder(route)
            }
        }
    }
}

@Composable
private fun RoutePlaceholder(route: AppRoute) {
    val palette = LocalAppPalette.current
    Column(
        modifier = Modifier.fillMaxSize().padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(text = route.name, style = MaterialTheme.typography.titleLarge)
        Text(
            text = "route: goexercise://${route.path}",
            style = MaterialTheme.typography.bodyMedium,
        )
        Text(
            text = "theme: ${palette.displayName}",
            style = MaterialTheme.typography.bodySmall,
        )
    }
}
