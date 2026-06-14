package com.goexercise.app.data.friends

import android.content.Context
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

/**
 * 受信応援の「前回チェック時刻」を uid 別に SharedPreferences で保持する。
 * iOS の `cheers.lastSeenAt.<uid>`(UserDefaults)ミラー。
 * 初回(未記録)は「今」を起点にして過去の蓄積を一気に出さない。
 *
 * 永続層は [Backing] で抽象化し、JVM 単体テストでは Android フレームワーク無しに
 * 検証できる(uid の小文字正規化・初回 null・口座別独立を [CheerWatermarkStoreTest] で担保)。
 */
@Singleton
class CheerWatermarkStore(private val backing: Backing) {

    /** 単純な key→Long の永続層。SharedPreferences の最小ラッパ(テストでは in-memory に差替え)。 */
    interface Backing {
        fun getLong(key: String): Long?
        fun putLong(key: String, value: Long)
    }

    @Inject constructor(@ApplicationContext context: Context) : this(SharedPrefsBacking(context))

    /** uid は大小を正規化(同一ユーザーが端末/OS をまたいでも同じ watermark を指すため)。 */
    private fun key(uid: String) = "lastSeenAt.${uid.lowercase()}"

    /** uid の watermark(epoch ms)。未記録なら null。 */
    fun lastSeen(uid: String): Long? = backing.getLong(key(uid))

    fun setLastSeen(uid: String, epochMs: Long) {
        backing.putLong(key(uid), epochMs)
    }

    private class SharedPrefsBacking(context: Context) : Backing {
        private val prefs = context.getSharedPreferences("cheers_watermark", Context.MODE_PRIVATE)
        override fun getLong(key: String): Long? =
            if (prefs.contains(key)) prefs.getLong(key, 0L) else null
        override fun putLong(key: String, value: Long) {
            prefs.edit().putLong(key, value).apply()
        }
    }
}
