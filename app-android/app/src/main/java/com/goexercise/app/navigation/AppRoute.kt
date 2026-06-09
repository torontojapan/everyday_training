package com.goexercise.app.navigation

/**
 * アプリが deep-link 可能な全ルートの単一真実源。iOS `AppRoute`(DeepLinkRouter.swift)の移植。
 * `path` は iOS の rawValue と一致させる(`goexercise://<path>` / 通知タップ / NavHost route)。
 */
enum class AppRoute(val path: String) {
    Home("home"),
    Record("record"),
    History("history"),
    Settings("settings"),
    NotificationSettings("notification-settings"),
    StreakShare("streak-share"),
    Friends("friends"),
    WeeklyRanking("weekly-ranking");

    companion object {
        fun fromPath(path: String): AppRoute? =
            entries.firstOrNull { it.path == path.lowercase() }
    }
}
