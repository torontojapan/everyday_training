package com.goexercise.app.presentation.referral

import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.sp
import com.goexercise.app.domain.friends.ReferralConfirmation
import com.goexercise.app.ui.theme.LocalAppPalette

/**
 * 友達紹介の確定ポップ。新規(される側=ウェルカム)と紹介者(する側=参加通知)を出し分け。
 * 複数の紹介者ポップは1枚に列挙。iOS `ReferralCelebrationSheet` 相当。
 */
@Composable
fun ReferralCelebrationDialog(confirmations: List<ReferralConfirmation>, onDismiss: () -> Unit) {
    if (confirmations.isEmpty()) return
    val palette = LocalAppPalette.current
    val isWelcome = confirmations.first().role == ReferralConfirmation.Role.REFEREE
    val title = if (isWelcome) "友達とつながりました！" else "紹介した友達が参加しました！"
    val body = if (isWelcome) {
        "${confirmations.first().friendDisplayName} さんの招待で参加\n❄️ ウェルカム・フリーズ +1(今月)"
    } else {
        confirmations.joinToString("\n") { "${it.friendDisplayName} さんが参加！" } +
            "\n❄️ フリーズ +1(今月・上限5)\n⭐ 星バッジ +${confirmations.size}"
    }
    AlertDialog(
        onDismissRequest = onDismiss,
        icon = { Text(if (isWelcome) "✨" else "⭐", fontSize = 40.sp) },
        title = { Text(title, fontWeight = FontWeight.Bold, color = palette.textPrimary, textAlign = TextAlign.Center) },
        text = { Text(body, color = palette.textSecondary, textAlign = TextAlign.Center) },
        confirmButton = { TextButton(onClick = onDismiss) { Text("やったね！", color = palette.primaryDeep, fontWeight = FontWeight.Bold) } },
        containerColor = palette.surface,
    )
}
