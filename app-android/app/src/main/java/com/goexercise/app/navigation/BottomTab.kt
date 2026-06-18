package com.goexercise.app.navigation

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.MonitorWeight
import androidx.compose.material.icons.filled.People
import androidx.compose.material.icons.filled.Settings
import androidx.compose.ui.graphics.vector.ImageVector
import com.goexercise.app.AppFeatureFlags

/**
 * ボトムタブ。iOS `MainTabView.Tab` の移植(home/履歴/体重/友達/設定)。
 * 友達は FRIENDS_ENABLED でゲート(iOS visibleTabs と同じ)。
 * route 文字列は home/history/friends/settings は AppRoute.path と一致させる。
 * 体重(weight)は AppRoute(ディープリンク正本)に無いタブ専用 route。
 * アイコンは iOS の SF Symbol に対応する Material アイコン(house.fill/chart.bar.fill/
 * scalemass.fill/person.2.fill/gearshape.fill)。
 */
enum class BottomTab(val route: String, val label: String, val icon: ImageVector) {
    Home("home", "ホーム", Icons.Filled.Home),
    History("history", "履歴", Icons.Filled.BarChart),
    Weight("weight", "体重", Icons.Filled.MonitorWeight),
    Friends("friends", "友達", Icons.Filled.People),
    Settings("settings", "設定", Icons.Filled.Settings);

    companion object {
        fun visible(friendsEnabled: Boolean = AppFeatureFlags.FRIENDS_ENABLED): List<BottomTab> =
            entries.filter { it != Friends || friendsEnabled }
    }
}
