package com.goexercise.app

import android.app.Application
import dagger.hilt.android.HiltAndroidApp

/**
 * Hilt の DI ルート。iOS の `@Environment` 注入 / コンポジションルートに相当(計画書 §2)。
 * Room / DataStore / Supabase リポジトリ等は今後 Hilt モジュールとしてここにぶら下げる。
 */
@HiltAndroidApp
class GOExerciseApp : Application()
