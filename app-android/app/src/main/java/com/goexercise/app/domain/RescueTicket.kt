package com.goexercise.app.domain

import java.time.LocalDate

/** 連続記録フリーズ(保険チケット)の月次付与枠。iOS `RescueTicketAllowance` の移植。 */
object RescueTicketAllowance {
    /** 月次フリーズ上限(全員共通)。base + 今月紹介ボーナスもこれを超えない。 */
    const val MONTHLY_CAP = 5

    /** 後方互換: 紹介ボーナス無しの従来 API。GOプレミアムなら月4、無料なら月1。 */
    fun current(isPremium: Boolean): Int = current(isPremium, referralBonus = 0)

    /** base + 今月紹介ボーナスを MONTHLY_CAP でクリップ。ボーナス負値は0に丸め。 */
    fun current(isPremium: Boolean, referralBonus: Int): Int {
        val base = if (isPremium) 4 else 1
        return minOf(MONTHLY_CAP, base + maxOf(0, referralBonus))
    }

    /**
     * 指定日の枠。紹介フリーズボーナスは **当月のみ** 加算する(iOS `HomeViewModel.allowance(for:)`)。
     * 月境界で前月の Missed を救済する際に当月の紹介ボーナスを食わせない/前月へ流用しないための関数。
     */
    fun forDate(date: LocalDate, today: LocalDate, isPremium: Boolean, referralBonus: Int): Int {
        val bonus = if (java.time.YearMonth.from(date) == java.time.YearMonth.from(today)) referralBonus else 0
        return current(isPremium, bonus)
    }
}

/**
 * フリーズ使用状況の純粋ロジック。iOS `RescueTicketStore` の月次集計部分を移植
 * (永続化は data 層の RescueTicketRepository)。月キーは year*100+month。
 */
object RescueTicketLogic {
    fun monthKey(date: LocalDate): Int = date.year * 100 + date.monthValue

    fun usedCountInMonth(used: Set<LocalDate>, month: LocalDate): Int =
        used.count { monthKey(it) == monthKey(month) }

    fun hasAvailable(used: Set<LocalDate>, today: LocalDate, allowance: Int): Boolean =
        usedCountInMonth(used, today) < allowance

    fun remaining(used: Set<LocalDate>, today: LocalDate, allowance: Int): Int =
        maxOf(0, allowance - usedCountInMonth(used, today))
}
