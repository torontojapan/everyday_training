package com.goexercise.app.data.review

import android.content.Context
import com.goexercise.app.domain.ReviewPromptStore
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

/**
 * [ReviewPromptStore] の SharedPreferences 実装(同期, iOS UserDefaults 相当)。
 * 具象クラスなので Hilt は @Inject コンストラクタで直接解決でき、@Binds/@Provides は不要。
 * HomeViewModel がこの具象を注入し ReviewRequestController を内部で組み立てる
 * ([com.goexercise.app.data.rankup.SharedPrefsRankUpStore] と同じ方針)。
 */
@Singleton
class SharedPrefsReviewPromptStore @Inject constructor(@ApplicationContext context: Context) : ReviewPromptStore {
    private val prefs = context.getSharedPreferences("review", Context.MODE_PRIVATE)

    override fun lastRequestEpochDay(): Long? =
        if (prefs.contains(KEY_LAST)) prefs.getLong(KEY_LAST, 0L) else null

    override fun setLastRequestEpochDay(day: Long) {
        prefs.edit().putLong(KEY_LAST, day).apply()
    }

    override fun promptedMilestones(): Set<Int> =
        (prefs.getStringSet(KEY_PROMPTED, emptySet()) ?: emptySet()).mapNotNull { it.toIntOrNull() }.toSet()

    override fun addPromptedMilestone(streak: Int) {
        // getStringSet の返り値は直接変更してはいけない(Android 仕様)。コピーして書き戻す。
        val updated = (prefs.getStringSet(KEY_PROMPTED, emptySet()) ?: emptySet()).toMutableSet()
        updated.add(streak.toString())
        prefs.edit().putStringSet(KEY_PROMPTED, updated).apply()
    }

    private companion object {
        const val KEY_LAST = "last_request_epoch_day"
        const val KEY_PROMPTED = "prompted_milestones"
    }
}
