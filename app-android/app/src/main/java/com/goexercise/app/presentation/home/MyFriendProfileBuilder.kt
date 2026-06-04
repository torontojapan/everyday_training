package com.goexercise.app.presentation.home

import com.goexercise.app.domain.friends.FriendProfile

/**
 * 自分の [HomeUiState](実統計)+ 友達アイデンティティ(コード/ユーザー名/表示名)から、友達バックエンドに
 * publish する [FriendProfile] を組み立てる**純粋関数**。iOS `HomeView` の publishMyProfile 構築に対応。
 *
 * identity 側の friendCode/username/displayName は不変に保ち、統計(連続/週次/猫種など)を最新化する。
 * 月次集計は HomeUiState に無いため identity の値を踏襲(null)。
 */
object MyFriendProfileBuilder {

    fun build(state: HomeUiState, identity: FriendProfile): FriendProfile {
        val todayCategory = state.todaySummary.categoryCounts
            .maxByOrNull { it.value }?.key?.displayName
        return identity.copy(
            currentStreak = state.streak.currentStreak,
            totalAchievedDays = state.lifetimeStats.achievedDays,
            todayAchieved = state.todayStatus.countsAsAchieved,
            todayCategoryName = todayCategory,
            decorationTier = state.catDecoration.tier,
            weeklyAchievements = state.weekStatuses.map { it.status.countsAsAchieved },
            weeklyTotalMinutes = state.weeklySummary.totalMinutes,
            myCatBreed = state.catBreed,
        )
    }

    /**
     * publish するべき統計が変わったかを判定するためのシグネチャ(identity 非依存)。
     * 毎分 ticker や初期空状態での無駄な再 publish を distinctUntilChangedBy で抑えるのに使う。
     */
    fun statsSignature(state: HomeUiState): List<Any?> = listOf(
        state.streak.currentStreak,
        state.lifetimeStats.achievedDays,
        state.todayStatus.countsAsAchieved,
        state.weekStatuses.map { it.status.countsAsAchieved },
        state.weeklySummary.totalMinutes,
        state.todaySummary.categoryCounts.maxByOrNull { it.value }?.key?.displayName,
        state.catDecoration.tier,
        state.catBreed,
    )
}
