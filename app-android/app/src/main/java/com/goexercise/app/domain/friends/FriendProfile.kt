package com.goexercise.app.domain.friends

/**
 * 友達(または自分)の共有プロフィール。iOS `FriendProfile` の移植(P1b-1 で必要な項目に集中)。
 * 体重・体調は含めない(プライバシー設計)。週間ランキング用に weekly/monthly 集計を保持。
 */
data class FriendProfile(
    val friendCode: String,
    val username: String,
    val displayName: String,
    val currentStreak: Int,
    val totalAchievedDays: Int,
    val todayAchieved: Boolean,
    val todayCategoryName: String? = null,
    val todayExerciseNames: List<String> = emptyList(),
    val decorationTier: Int = 0,
    val weeklyAchievements: List<Boolean>? = null,
    val weeklyTotalMinutes: Int? = null,
    val monthlyTotalMinutes: Int? = null,
    val monthlyAchievedDays: Int? = null,
) {
    val id: String get() = friendCode

    /** 7 要素(月→日)。未設定は false 埋め。iOS weeklyAchievementsOrEmpty 相当。 */
    val weeklyAchievementsOrEmpty: List<Boolean>
        get() {
            val raw = weeklyAchievements ?: emptyList()
            return when {
                raw.size == 7 -> raw
                raw.size > 7 -> raw.take(7)
                else -> raw + List(7 - raw.size) { false }
            }
        }
}

/** 友達申請。iOS `FriendRequest` の移植。 */
data class FriendRequest(
    val id: String,
    val fromProfile: FriendProfile,
)

/** 応援スタンプ種別。iOS `CheerKind` の移植。 */
enum class CheerKind(val rawValue: String, val emoji: String, val label: String) {
    Fight("fight", "💪", "がんばれ"),
    Great("great", "🌟", "すごい"),
    Clap("clap", "👏", "拍手"),
    Fire("fire", "🔥", "応援"),
}
