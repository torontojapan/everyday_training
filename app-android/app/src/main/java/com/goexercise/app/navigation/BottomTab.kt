package com.goexercise.app.navigation

import com.goexercise.app.AppFeatureFlags

/**
 * ボトムタブ。iOS `MainTabView.Tab` の移植(home/履歴/体重/友達/設定)。
 * 友達は FRIENDS_ENABLED でゲート(iOS visibleTabs と同じ)。
 * route 文字列は home/history/friends/settings は AppRoute.path と一致させる。
 * 体重(weight)は AppRoute(ディープリンク正本)に無いタブ専用 route。
 * アイコンは material-icons 依存を避け emoji で代用(アセット導入時に差し替え可)。
 */
enum class BottomTab(val route: String, val label: String, val emoji: String) {
    Home("home", "ホーム", "🏠"),
    History("history", "履歴", "📊"),
    Weight("weight", "体重", "⚖️"),
    Friends("friends", "友達", "👥"),
    Settings("settings", "設定", "⚙️");

    companion object {
        fun visible(friendsEnabled: Boolean = AppFeatureFlags.FRIENDS_ENABLED): List<BottomTab> =
            entries.filter { it != Friends || friendsEnabled }
    }
}
