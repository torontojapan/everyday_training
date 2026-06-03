package com.goexercise.app.domain

/**
 * 運動カテゴリ。iOS `WorkoutCategory` の 1:1 移植(P0 は cases のみ)。
 * displayName / アイコン等は P1a の本格移植時に iOS と突き合わせて追加する。
 */
enum class WorkoutCategory {
    Cardio,
    Strength,
    Yoga,
    Stretch,
    FasciaRelease,
    Other,
}
