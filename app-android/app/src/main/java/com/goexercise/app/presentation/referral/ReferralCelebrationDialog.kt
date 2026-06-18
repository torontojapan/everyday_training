package com.goexercise.app.presentation.referral

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AcUnit
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.goexercise.app.domain.friends.ReferralConfirmation
import com.goexercise.app.ui.theme.AppType
import com.goexercise.app.ui.theme.LocalAppPalette

/**
 * 友達紹介の確定ポップ。新規(される側=ウェルカム)と紹介者(する側=参加通知)を出し分け。
 * 複数の紹介者ポップは1枚に列挙。iOS `ReferralCelebrationSheet` 相当。
 * 報酬行は iOS `rewardRow`(SF Symbol + 文言)に合わせ、Material アイコン + 絵文字なし文言で表示
 * (Android の絵文字→Material アイコン方針とも一致)。
 */
@Composable
fun ReferralCelebrationDialog(confirmations: List<ReferralConfirmation>, onDismiss: () -> Unit) {
    if (confirmations.isEmpty()) return
    val palette = LocalAppPalette.current
    val isWelcome = confirmations.first().role == ReferralConfirmation.Role.REFEREE
    val title = if (isWelcome) "友達とつながりました!" else "友達が参加しました!"
    AlertDialog(
        onDismissRequest = onDismiss,
        // iOS ヘッダアイコン: sparkles(welcome)/ star.fill。Material の AutoAwesome / Star で代替。
        icon = {
            Icon(
                if (isWelcome) Icons.Filled.AutoAwesome else Icons.Filled.Star,
                contentDescription = null,
                tint = palette.primaryDeep,
                modifier = Modifier.size(40.dp),
            )
        },
        title = { Text(title, fontWeight = FontWeight.Bold, color = palette.textPrimary, textAlign = TextAlign.Center) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                if (isWelcome) {
                    Text("${confirmations.first().friendDisplayName} さんの招待で参加", style = AppType.body, color = palette.textSecondary, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
                    RewardRow(Icons.Filled.AcUnit, "ウェルカム・保険チケット +1(今月)")
                } else {
                    confirmations.forEach { c ->
                        Text("${c.friendDisplayName} さんが参加!", style = AppType.body, color = palette.textSecondary, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
                    }
                    RewardRow(Icons.Filled.AcUnit, "保険チケット +1(今月・上限5)")
                    RewardRow(Icons.Filled.Star, "星バッジ +${confirmations.size}")
                }
            }
        },
        confirmButton = { TextButton(onClick = onDismiss) { Text("やったね!", color = palette.primaryDeep, fontWeight = FontWeight.Bold) } },
        containerColor = palette.surface,
    )
}

/** iOS rewardRow(アイコン primaryDeep + 文言)。 */
@Composable
private fun RewardRow(icon: ImageVector, text: String) {
    val palette = LocalAppPalette.current
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, contentDescription = null, tint = palette.primaryDeep, modifier = Modifier.size(18.dp))
        Text(text, style = AppType.body, color = palette.textPrimary)
    }
}
