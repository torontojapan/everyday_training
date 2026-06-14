package com.goexercise.app.data.referral

/**
 * 紹介サマリ(星バッジ/今月フリーズ加算)の**口座スコープ・ガード**(純粋関数)。
 * iOS `currentAccountStarBadges` / `currentAccountFreezeBonus` と同型。
 *
 * summary が現在サインイン中のアカウント(friend_code)由来のときだけ値を通す。
 * アカウント切替/復元の直後で summary がまだ前アカウント由来(または未確定)の間は 0 を返し、
 * 前アカウントの星/フリーズ加算を新アカウントの文脈で表示・付与する口座跨ぎ stale を防ぐ。
 */
object ReferralAccountScope {
    fun scoped(value: Int, summaryAccountCode: String?, currentAccountCode: String?): Int =
        if (summaryAccountCode != null && summaryAccountCode == currentAccountCode) value else 0
}
