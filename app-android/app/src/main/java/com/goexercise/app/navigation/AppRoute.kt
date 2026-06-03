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

        /**
         * `goexercise://<host>[?code=...]` を AppRoute に解決する(iOS DeepLinkRouter.route 相当)。
         * scheme 不一致/未知ホストは null。friend code 抽出と feature-flag ゲートは
         * friends フェーズ(P1b-1)で FriendCodeValidator と共に移植する。
         */
        fun fromUri(scheme: String?, host: String?): AppRoute? {
            if (scheme?.lowercase() != "goexercise") return null
            val key = host?.lowercase() ?: return null
            return fromPath(key)
        }
    }
}
