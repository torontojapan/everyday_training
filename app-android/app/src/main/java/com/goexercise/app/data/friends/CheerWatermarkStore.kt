package com.goexercise.app.data.friends

import android.content.Context
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

/**
 * 受信応援の「前回チェック時刻」を uid 別に SharedPreferences で保持する。
 * iOS の `cheers.lastSeenAt.<uid>`(UserDefaults)ミラー。
 * 初回(未記録)は「今」を起点にして過去の蓄積を一気に出さない。
 */
@Singleton
class CheerWatermarkStore @Inject constructor(@ApplicationContext context: Context) {
    private val prefs = context.getSharedPreferences("cheers_watermark", Context.MODE_PRIVATE)

    private fun key(uid: String) = "lastSeenAt.${uid.lowercase()}"

    /** uid の watermark(epoch ms)。未記録なら null。 */
    fun lastSeen(uid: String): Long? =
        if (prefs.contains(key(uid))) prefs.getLong(key(uid), 0L) else null

    fun setLastSeen(uid: String, epochMs: Long) {
        prefs.edit().putLong(key(uid), epochMs).apply()
    }
}
