package com.goexercise.app.presentation.home

import com.goexercise.app.domain.CatRank
import com.goexercise.app.domain.DailyStatus
import com.goexercise.app.domain.friends.FriendProfile
import com.goexercise.app.domain.friends.SharedExerciseDetail

/**
 * 自分の [HomeUiState](実統計)+ 友達アイデンティティ(コード/ユーザー名/表示名)から、友達バックエンドに
 * publish する [FriendProfile] を組み立てる**純粋関数**。iOS `HomeView` の publishMyProfile 構築に対応。
 *
 * identity 側の friendCode/username/displayName は不変に保ち、統計(連続/週次/猫種など)を最新化する。
 * 月次集計は HomeUiState に無いため identity の値を踏襲(null)。
 */
object MyFriendProfileBuilder {

    /** 今日の種目別詳細(共有 opt-in 時のみ)。iOS FriendSharedActivity.build(includeDetail:) 相当。
     *  duration は分(0 なら null)、reps/sets はそのまま。体重・体調は対象外。 */
    fun todayDetails(state: HomeUiState, shareDetail: Boolean): List<SharedExerciseDetail>? {
        if (!shareDetail) return null
        val today = state.weekStatuses.firstOrNull {
            it.status == DailyStatus.TodayAchieved || it.status == DailyStatus.TodayPending
        }?.date ?: return null
        return state.weekRecords.filter { it.date == today }.flatMap { it.exercises }.mapNotNull { ex ->
            val name = ex.name.trim()
            if (name.isEmpty()) return@mapNotNull null
            val minutes = (ex.durationSeconds ?: 0) / 60
            SharedExerciseDetail(name = name, durationMinutes = minutes.takeIf { it > 0 }, reps = ex.reps, sets = ex.sets)
        }.takeIf { it.isNotEmpty() }
    }

    fun build(state: HomeUiState, identity: FriendProfile, shareDetail: Boolean = false): FriendProfile {
        val todayCategory = state.todaySummary.categoryCounts
            .maxByOrNull { it.value }?.key?.displayName
        return identity.copy(
            todayExerciseDetails = todayDetails(state, shareDetail),
            currentStreak = state.streak.currentStreak,
            totalAchievedDays = state.lifetimeStats.achievedDays,
            todayAchieved = state.todayStatus.countsAsAchieved,
            todayCategoryName = todayCategory,
            // iOS パリティ: 旧 CatDecoration.tier(生涯達成ベース 0..4)ではなく、連続記録ベースの
            // CatRank.rank(0..11)を publish する。クロスプラットフォーム BE で同一ユーザーが
            // プラットフォーム間で異なる値を書き分けるのを防ぐ。友達表示は FriendProfile.rank を別途使うので影響なし。
            decorationTier = CatRank.of(state.streak.currentStreak).rank,
            weeklyAchievements = state.weekStatuses.map { it.status.countsAsAchieved },
            // 日ごとの状態も publish(友達詳細の状態別週ストリップ用。iOS 1.3 パリティ)。
            weeklyStatuses = state.weekStatuses.map { it.status },
            weeklyTotalMinutes = state.weeklySummary.totalMinutes,
            monthlyTotalMinutes = state.monthlyTotalMinutes,
            monthlyAchievedDays = state.monthlyAchievedDays,
            myPet = state.pet,
        )
    }

    /**
     * publish するべき統計が変わったかを判定するためのシグネチャ(identity 非依存)。
     * 毎分 ticker や初期空状態での無駄な再 publish を distinctUntilChangedBy で抑えるのに使う。
     */
    fun statsSignature(state: HomeUiState, shareDetail: Boolean = false): List<Any?> = listOf(
        state.streak.currentStreak,
        state.lifetimeStats.achievedDays,
        state.todayStatus.countsAsAchieved,
        state.weekStatuses.map { it.status.countsAsAchieved },
        // weeklyStatuses も再 publish 判定に含める(状態が変われば友達表示も更新する)。
        state.weekStatuses.map { it.status },
        state.weeklySummary.totalMinutes,
        state.monthlyTotalMinutes,
        state.monthlyAchievedDays,
        state.todaySummary.categoryCounts.maxByOrNull { it.value }?.key?.displayName,
        // publish される decorationTier(= CatRank.rank, 連続記録ベース 0..11)に合わせる。
        // currentStreak は既に含まれるが、publish 値を直接署名に反映して再 publish 判定を正しく保つ。
        CatRank.of(state.streak.currentStreak).rank,
        state.pet,
        // 共有 opt-in と今日の種目詳細(変化で再 publish。reps/sets 編集も検知)。
        shareDetail,
        todayDetails(state, shareDetail),
    )
}
