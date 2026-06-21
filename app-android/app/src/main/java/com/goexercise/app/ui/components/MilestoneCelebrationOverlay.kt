package com.goexercise.app.ui.components

import android.content.Intent
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.IosShare
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.goexercise.app.domain.CatState
import com.goexercise.app.domain.Milestone
import com.goexercise.app.domain.PetBreed
import com.goexercise.app.ui.theme.LocalAppPalette

/**
 * 大節目の全画面お祝い。iOS `MilestoneCelebrationSheet` パリティ:
 * 猫(連続更新ポーズ)+ 金バッジ + 大見出し + 説明 + 主役の共有 CTA「シェアして運動仲間とつながる」+ 閉じる。
 * 旧 compact AlertDialog を置き換え、達成の感情的ピークを iOS と同じ全画面の演出にする。
 */
@Composable
fun MilestoneCelebrationOverlay(
    milestone: Milestone,
    pet: PetBreed,
    badgeIcon: ImageVector,
    onDismiss: () -> Unit,
) {
    val palette = LocalAppPalette.current
    val context = LocalContext.current
    Box(
        modifier = Modifier
            .fillMaxSize()
            // 背面のスクリム(タップで閉じる)。
            .background(Color.Black.copy(alpha = 0.45f))
            .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null, onClick = onDismiss),
        contentAlignment = Alignment.Center,
    ) {
        // カード本体(スクリムのタップが貫通しないよう、カードは onClick を消費)。
        Surface(
            color = palette.surface,
            shape = RoundedCornerShape(28.dp),
            shadowElevation = 16.dp,
            modifier = Modifier
                .padding(horizontal = 28.dp)
                .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null, onClick = {}),
        ) {
            Box {
                Column(
                    modifier = Modifier.fillMaxWidth().padding(24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(14.dp),
                ) {
                    // 猫(祝福ポーズ)+ 金バッジ。連続更新ポーズ(streakExtended)は炎入りで
                    // ユーザーに「火はださい」と指摘されたため celebrating(炎なし)に変更(2026-06-19)。
                    Box(contentAlignment = Alignment.BottomEnd) {
                        PetImage(pet = pet, state = CatState.Celebrating, modifier = Modifier.size(180.dp))
                        Box(
                            Modifier.size(52.dp).clip(CircleShape).background(palette.surface),
                            contentAlignment = Alignment.Center,
                        ) {
                            Icon(badgeIcon, contentDescription = null, tint = Color(0xFFFFB300), modifier = Modifier.size(40.dp))
                        }
                    }
                    Text(milestone.headline, fontSize = 30.sp, fontWeight = FontWeight.Black, color = palette.textPrimary, textAlign = TextAlign.Center)
                    Text(milestone.detail, fontSize = 15.sp, color = palette.textSecondary, textAlign = TextAlign.Center)
                    // 主役 CTA: SNS シェア(iOS「シェアして運動仲間とつながる」)。
                    Surface(
                        color = palette.primary,
                        shape = RoundedCornerShape(14.dp),
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable {
                                val intent = Intent(Intent.ACTION_SEND).apply {
                                    type = "text/plain"
                                    putExtra(Intent.EXTRA_TEXT, "${milestone.shareMessage}\nhttps://goexercise.app")
                                }
                                runCatching { context.startActivity(Intent.createChooser(intent, "シェア")) }
                                onDismiss()
                            },
                    ) {
                        Row(
                            Modifier.fillMaxWidth().padding(vertical = 14.dp),
                            horizontalArrangement = Arrangement.Center,
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Icon(Icons.Filled.IosShare, contentDescription = null, tint = Color.White, modifier = Modifier.size(18.dp))
                            Text("  シェアして運動仲間とつながる", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 15.sp)
                        }
                    }
                    TextButton(onClick = onDismiss) { Text("閉じる", color = palette.textSecondary, fontSize = 15.sp) }
                }
                // X 閉じる(右上)。
                Box(
                    Modifier.align(Alignment.TopEnd).padding(8.dp).size(32.dp).clip(CircleShape)
                        .background(palette.chipBackground).clickable(onClick = onDismiss),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Icons.Filled.Close, contentDescription = "閉じる", tint = palette.textSecondary, modifier = Modifier.size(18.dp))
                }
            }
        }
    }
}
