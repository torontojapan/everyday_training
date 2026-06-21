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
    /**
     * 7 要素(月→日)の **日ごとの状態**(運動/休養/フリーズ/未達/今日/未来)。友達詳細の
     * 「今週の達成」を本人ホーム週ストリップと同じ状態別表示にするための正本(iOS 1.3 パリティ)。
     * null = 旧データ/旧クライアント → weeklyAchievements(Bool)から近似復元する。
     */
    val weeklyStatuses: List<com.goexercise.app.domain.DailyStatus>? = null,
    val weeklyTotalMinutes: Int? = null,
    val monthlyTotalMinutes: Int? = null,
    val monthlyAchievedDays: Int? = null,
    /** 共有するキャラ(猫 or 犬。友達一覧のアバター表示用)。未設定は hash 既定。iOS `myPet` 相当。
     * Supabase の `my_cat_breed` text 列に [[PetBreed.friendBreedString]] で載る(犬対応・移行不要)。 */
    val myPet: com.goexercise.app.domain.PetBreed? = null,
    /** プロフィール最終更新時刻。友達詳細の「最終更新 N分前」。iOS `lastUpdated` 相当。 */
    val lastUpdated: java.time.Instant? = null,
    /** 友達になった日時。詳細の「つながって N日」タイル。iOS `connectedSince` 相当。 */
    val connectedSince: java.time.Instant? = null,
    /** 今日の運動の種目別詳細(相手が「回数・時間・セット数も共有」ON のときのみ)。iOS `todayExerciseDetails` 相当。 */
    val todayExerciseDetails: List<SharedExerciseDetail>? = null,
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

    /**
     * 友達ストリップ描画用の 7 状態(月→日)。weeklyStatuses があればそれを使い、無い(旧データ/
     * 旧クライアント)場合は Bool 配列から近似復元(true→achieved / false→missed)。長さは常に 7。
     * iOS weeklyStatusesOrEmpty 相当。
     */
    val weeklyStatusesOrEmpty: List<com.goexercise.app.domain.DailyStatus>
        get() {
            val raw = weeklyStatuses
            if (raw != null && raw.isNotEmpty()) {
                return when {
                    raw.size == 7 -> raw
                    raw.size > 7 -> raw.take(7)
                    else -> raw + List(7 - raw.size) { com.goexercise.app.domain.DailyStatus.Future }
                }
            }
            return weeklyAchievementsOrEmpty.map {
                if (it) com.goexercise.app.domain.DailyStatus.Achieved else com.goexercise.app.domain.DailyStatus.Missed
            }
        }
}

/**
 * 今日の運動の種目別共有詳細。iOS `SharedExerciseDetail` 相当(構造化フィールド + 計算 summary)。
 * summary は iOS と**完全一致**の形式:「{reps}回 × {sets}セット」/「{reps}回」/「{sets}セット」に
 * 「{min}分」を付け、" / " で連結する(iOS `SharedExerciseDetail.summary`)。
 */
data class SharedExerciseDetail(
    val name: String,
    val durationMinutes: Int? = null,
    val reps: Int? = null,
    val sets: Int? = null,
) {
    val summary: String
        get() {
            val parts = mutableListOf<String>()
            when {
                reps != null && sets != null -> parts.add("${reps}回 × ${sets}セット")
                reps != null -> parts.add("${reps}回")
                sets != null -> parts.add("${sets}セット")
            }
            if (durationMinutes != null) parts.add("${durationMinutes}分")
            return parts.joinToString(" / ")
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
