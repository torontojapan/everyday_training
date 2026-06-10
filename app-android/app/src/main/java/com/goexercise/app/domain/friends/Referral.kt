package com.goexercise.app.domain.friends

import java.time.Instant
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter

/**
 * 自分の紹介状況の集計。iOS `ReferralSummary` の移植。
 * - starBadges: 累計 confirmed 紹介数(referrer側・無制限)。
 * - freezeBonusThisMonth: 今月 confirmed の自分向けフリーズ加算
 *   (= 今月 confirmed の referrer 件数 + 自分が referee で今月 confirmed なら +1)。
 */
data class ReferralSummary(
    val starBadges: Int,
    val freezeBonusThisMonth: Int,
) {
    companion object { val EMPTY = ReferralSummary(0, 0) }
}

/** 確定(confirmed)イベント1件。ポップ表示に使う。 */
data class ReferralConfirmation(
    val id: String,
    val friendDisplayName: String,
    val role: Role,
) {
    enum class Role { REFERRER, REFEREE }
}

/** timestamptz 文字列の解析と「今月か(ローカル暦)」判定。iOS `ReferralClock` の移植。 */
object ReferralClock {
    fun parseTimestamp(iso: String): Instant? = try {
        OffsetDateTime.parse(iso, DateTimeFormatter.ISO_OFFSET_DATE_TIME).toInstant()
    } catch (e: Exception) {
        try { Instant.parse(iso) } catch (e2: Exception) { null }
    }

    // フリーズ allowance の「今月」判定は LocalDate(端末ローカル暦, RescueTicketLogic.monthKey)
    // で行うため、紹介ボーナスの月判定も**ローカル暦**に揃える。UTC で割ると JST(UTC+9)では
    // 月境界の最大 9h でローカル月とズレ、今月ボーナスが隣月の allowance に載る(月境界 UTC-local 型のバグ)。
    private fun monthKey(instant: Instant): Int {
        val d = instant.atZone(ZoneId.systemDefault())
        return d.year * 100 + d.monthValue
    }

    /** `iso`(timestamptz)が `now` と同じ暦月(ローカル)か。null/解析不能は false。 */
    fun isInMonth(iso: String?, now: Instant): Boolean {
        val parsed = iso?.let { parseTimestamp(it) } ?: return false
        return monthKey(parsed) == monthKey(now)
    }
}

/**
 * オンボ以外(設定)から招待コードを入力できるかの判定。iOS `ReferralEntryPolicy` の移植。
 * 初回起動から graceDays 以内 かつ まだ紹介者がいない場合のみ許可。
 */
object ReferralEntryPolicy {
    const val GRACE_DAYS = 7
    fun canEnterCodeLater(
        firstLaunchAt: Instant?,
        now: Instant,
        hasExistingReferral: Boolean,
        graceDays: Int = GRACE_DAYS,
    ): Boolean {
        if (hasExistingReferral || firstLaunchAt == null) return false
        val days = (now.epochSecond - firstLaunchAt.epochSecond) / 86400
        return days in 0..graceDays.toLong()
    }
}
