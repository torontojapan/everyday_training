package com.goexercise.app.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AcUnit
import androidx.compose.material3.Icon
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.goexercise.app.ui.theme.LocalAppPalette

/**
 * 連続記録フリーズ復活の落ち着いたポップ(iOS ミラー)。**損失回避を煽らない**穏やかなトーン。
 * 雪結晶 + 「連続◯日を守れます」+ 手持ちに応じた本文 + 主ボタン(フリーズ使用 or プレミアム)+
 * 明確で控えめな却下導線(「今回はしない」= ダークパターン回避)。
 *
 * @param hasEnough 手持ちフリーズが必要数以上か。true=フリーズ使用ボタン、false=プレミアム導線。
 */
@Composable
fun StreakRevivePopup(
    potentialStreak: Int,
    freezesNeeded: Int,
    remaining: Int,
    hasEnough: Boolean,
    onUseFreeze: () -> Unit,
    onSeePremium: () -> Unit,
    onDismiss: () -> Unit,
) {
    val palette = LocalAppPalette.current
    val icy = Color(0xFF6FB7E8)

    AlertDialog(
        onDismissRequest = onDismiss,
        // iOS は Image(systemName: "snowflake")。絵文字 ❄️ ではなく Material アイコンに統一(絵文字全廃)。
        icon = { Icon(Icons.Filled.AcUnit, contentDescription = null, tint = icy, modifier = Modifier.size(40.dp)) },
        title = {
            Text(
                text = "連続${potentialStreak}日を守れます",
                fontWeight = FontWeight.Bold,
                color = palette.textPrimary,
                textAlign = TextAlign.Center,
            )
        },
        text = {
            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                val body = if (hasEnough) {
                    "保険チケットを使うと、途切れた日を埋めて連続記録を続けられます。(残り${remaining}回)"
                } else {
                    "復活には保険チケットが${freezesNeeded}回必要です。GOプレミアムなら毎月4回使えます。"
                }
                Text(
                    text = body,
                    color = palette.textSecondary,
                    textAlign = TextAlign.Center,
                )
            }
        },
        confirmButton = {
            if (hasEnough) {
                Button(
                    onClick = onUseFreeze,
                    colors = ButtonDefaults.buttonColors(containerColor = icy),
                ) {
                    Text("保険チケットを使う(${freezesNeeded}回)", color = Color.White, fontWeight = FontWeight.Bold)
                }
            } else {
                Button(
                    onClick = onSeePremium,
                    colors = ButtonDefaults.buttonColors(containerColor = icy),
                ) {
                    Text("プレミアムを見てみる", color = Color.White, fontWeight = FontWeight.Bold)
                }
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("今回はしない", color = palette.textSecondary)
            }
        },
        containerColor = palette.surface,
    )
}
