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
    /** 共有する猫の種類(友達一覧のアバター表示用)。未設定は emoji フォールバック。iOS `myCatBreed` 相当。 */
    val myCatBreed: com.goexercise.app.domain.CatBreed? = null,
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

/**
 * 応援スタンプ種別。iOS `CheerKind` の移植。
 * rawValue は **クロスOS契約**(iOS と一致): fight/wontlose/protein/catpunch。
 * 絵文字は Android 表示用(iOS は SF Symbol)。旧 kind(great/clap/fire)は受信側で
 * [receivedFromRaw] が解釈してフォールバック表示するので、送信メニューから外しても受信は壊れない。
 */
enum class CheerKind(val rawValue: String, val emoji: String, val label: String) {
    Fight("fight", "📣", "がんばれ"),
    WontLose("wontlose", "⚡️", "負けないぞ"),
    Protein("protein", "🥤", "プロテイン"),
    CatPunch("catpunch", "🐾", "ねこぱんち");

    companion object {
        /** 受信表示用: 未知/旧 kind も解釈して落とさない(emoji, label)。iOS received(fromRaw:) 相当。 */
        fun receivedFromRaw(raw: String): Pair<String, String> {
            entries.firstOrNull { it.rawValue == raw }?.let { return it.emoji to it.label }
            return when (raw) {
                "great" -> "🌟" to "すごい"
                "clap" -> "👏" to "拍手"
                "fire" -> "🔥" to "応援"
                else -> "❤️" to "応援"
            }
        }
    }
}

/** 自分宛てに届いた応援(前回チェック以降の未読分)。iOS `ReceivedCheer` 移植。 */
data class ReceivedCheer(
    val id: String,
    val fromDisplayName: String,
    val kindRaw: String,
    /** 任意の一言コメント(message 列。旧クライアント/旧データは null → kind のラベルで表示)。 */
    val message: String?,
    val createdAtEpochMs: Long,
)
