package com.goexercise.app

import com.goexercise.app.navigation.AppRoute

/**
 * 機能フラグの一元管理。iOS `AppFeatureFlags.swift` の移植。
 *
 * 友達機能は **iOS+Android 同時ローンチ方針(2026-06-03)で初回から有効**(true)。
 * gate OFF にすると友達/週間ランキングへの遷移は home に振り替わる(回帰テスト用)。
 */
object AppFeatureFlags {
    const val FRIENDS_ENABLED: Boolean = true

    /** 友達紹介(リファラル)を有効にするか。友達BE前提なので FRIENDS_ENABLED と AND。 */
    const val REFERRAL_ENABLED: Boolean = true

    /** 紹介機能を出してよいか(友達有効 かつ 紹介有効)。 */
    val isReferralActive: Boolean get() = FRIENDS_ENABLED && REFERRAL_ENABLED

    /** 友達無効時に到達してはいけないルートを home に振り替える(iOS resolvedRoute と一致)。 */
    fun resolvedRoute(route: AppRoute, friendsEnabled: Boolean = FRIENDS_ENABLED): AppRoute {
        if (friendsEnabled) return route
        return when (route) {
            AppRoute.Friends, AppRoute.WeeklyRanking -> AppRoute.Home
            else -> route
        }
    }
}
