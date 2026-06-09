package com.goexercise.app.presentation.review

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import com.google.android.play.core.review.ReviewManagerFactory

/** Compose の LocalContext(ContextWrapper)から Activity を辿る。見つからなければ null。 */
fun Context.findActivity(): Activity? {
    var ctx: Context? = this
    while (ctx is ContextWrapper) {
        if (ctx is Activity) return ctx
        ctx = ctx.baseContext
    }
    return null
}

/**
 * Play In-App Review を起動する。実際にダイアログを表示するかは Google が決定する(クォータあり)。
 * iOS の `requestReview()` 相当。失敗時は静かに無視する(ユーザー操作を妨げない)。
 * 「いつ出すか」の判定は [com.goexercise.app.domain.ReviewRequestController] が担う。
 */
fun launchInAppReview(activity: Activity) {
    val manager = ReviewManagerFactory.create(activity)
    manager.requestReviewFlow().addOnCompleteListener { task ->
        if (task.isSuccessful) {
            runCatching { manager.launchReviewFlow(activity, task.result) }
        }
    }
}
