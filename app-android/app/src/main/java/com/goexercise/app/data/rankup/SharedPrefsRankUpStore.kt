package com.goexercise.app.data.rankup

import android.content.Context
import com.goexercise.app.domain.RankUpStore
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

/**
 * [RankUpStore] の SharedPreferences 実装。RankUpDetector の検知状態(lastRank / lastWeeklyMultiple)を
 * **同期**で読み書きする。ポートされた RankUpStore は getInt/putInt が同期 API のため、非同期の
 * DataStore ではなく SharedPreferences を使う(iOS UserDefaults 相当)。
 *
 * 具象クラスなので Hilt は @Inject コンストラクタで直接解決でき、別途 @Binds/@Provides は不要。
 * HomeViewModel はこの具象を注入し RankUpDetector を内部で組み立てる。
 */
@Singleton
class SharedPrefsRankUpStore @Inject constructor(@ApplicationContext context: Context) : RankUpStore {
    private val prefs = context.getSharedPreferences("rankup", Context.MODE_PRIVATE)
    override fun getInt(key: String): Int? = if (prefs.contains(key)) prefs.getInt(key, 0) else null
    override fun putInt(key: String, value: Int) {
        prefs.edit().putInt(key, value).apply()
    }
}
