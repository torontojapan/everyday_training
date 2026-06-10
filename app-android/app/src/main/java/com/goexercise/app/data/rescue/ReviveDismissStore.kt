package com.goexercise.app.data.rescue

import android.content.Context
import dagger.hilt.android.qualifiers.ApplicationContext
import java.time.LocalDate
import javax.inject.Inject
import javax.inject.Singleton

/**
 * 「対応済みの途切れ(break)」を SharedPreferences で記録し、同じ途切れを再度ポップしないようにする。
 * iOS ミラー: breakKey = 一番古い Missed 日の epoch-day(LocalDate.toEpochDay())を文字列化。
 *
 * フリーズ復活(applyRevive)を実行した時、または「今回はしない」(dismissRevive)を選んだ時に handled に積む。
 */
@Singleton
class ReviveDismissStore @Inject constructor(@ApplicationContext context: Context) {
    private val prefs = context.getSharedPreferences("revive", Context.MODE_PRIVATE)

    fun isHandled(key: String): Boolean = prefs.getStringSet("handled", emptySet())!!.contains(key)

    fun markHandled(key: String) {
        val s = prefs.getStringSet("handled", emptySet())!!.toMutableSet()
        s.add(key)
        prefs.edit().putStringSet("handled", s).apply()
    }

    companion object {
        /** 途切れキー = 最も古い Missed 日の epoch-day 文字列。Missed が無ければ null。 */
        fun breakKey(missedDates: List<LocalDate>): String? =
            missedDates.minOrNull()?.toEpochDay()?.toString()
    }
}
