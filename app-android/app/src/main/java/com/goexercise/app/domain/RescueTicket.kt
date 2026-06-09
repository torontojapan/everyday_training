package com.goexercise.app.domain

import java.time.LocalDate

/** 連続記録フリーズ(保険チケット)の月次付与枠。iOS `RescueTicketAllowance` の移植。 */
object RescueTicketAllowance {
    /** GOプレミアムなら月4、無料なら月1。 */
    fun current(isPremium: Boolean): Int = if (isPremium) 4 else 1
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
