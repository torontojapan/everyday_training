package com.goexercise.app.presentation.friends

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.Pets
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.goexercise.app.domain.friends.FriendAvatarResolver
import com.goexercise.app.domain.friends.RankingPeriod
import com.goexercise.app.domain.friends.WeeklyRankingEntry
import com.goexercise.app.ui.components.CatAvatar
import com.goexercise.app.ui.theme.AppTheme
import com.goexercise.app.ui.theme.AppType
import com.goexercise.app.ui.theme.LocalAppPalette

@Composable
fun WeeklyRankingRoute(onBack: () -> Unit = {}, viewModel: WeeklyRankingViewModel = hiltViewModel()) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    WeeklyRankingContent(state, onBack, viewModel::setPeriod)
}

@Composable
fun WeeklyRankingContent(
    state: RankingUiState,
    onBack: () -> Unit = {},
    onSetPeriod: (RankingPeriod) -> Unit = {},
) {
    val palette = LocalAppPalette.current
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(palette.background)
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        // iOS パリティ: 中央タイトル + 左の円形戻る(surface 円 + textPrimary chevron。設定 SubPage と統一)。
        Box(Modifier.fillMaxWidth()) {
            Box(
                modifier = Modifier.align(Alignment.CenterStart).size(36.dp).clip(CircleShape).background(palette.surface).clickable(onClick = onBack),
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.Filled.ChevronLeft, contentDescription = "戻る", tint = palette.textPrimary, modifier = Modifier.size(22.dp))
            }
            Text("ランキング", color = palette.textPrimary, modifier = Modifier.align(Alignment.Center), style = AppType.body.copy(fontWeight = FontWeight.SemiBold))
        }

        PeriodPicker(state.period, palette, onSetPeriod)
        RulesCard(state.period, palette)
        state.myEntry?.let { MySummaryCard(it, state.entries.size, state.period, palette) }

        if (state.entries.isEmpty()) {
            RankingEmptyState("ランキングを表示するには、友達を追加してください。", palette)
        } else {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                state.entries.forEach { RankRow(it, palette) }
            }
        }
    }
}

@Composable
private fun PeriodPicker(period: RankingPeriod, palette: AppTheme, onSet: (RankingPeriod) -> Unit) {
    // iOS `.pickerStyle(.segmented)` パリティ: 薄いライトグレーのトラック + 白の選択ピル(微小な影)+
    // 濃色テキスト。旧 coral 塗りピルは iOS のセグメント表現と別物だったため是正(角丸も pill→小角丸)。
    Surface(color = Color(0xFFEDE8E2), shape = RoundedCornerShape(9.dp), modifier = Modifier.fillMaxWidth()) {  // parity-allow: セグメント track の淡灰(iOS .segmented 標準トラック相当)
        Row(Modifier.padding(2.dp)) {
            RankingPeriod.entries.forEach { p ->
                val selected = p == period
                Surface(
                    color = if (selected) Color.White else Color.Transparent,
                    shape = RoundedCornerShape(7.dp),
                    shadowElevation = if (selected) 2.dp else 0.dp,
                    modifier = Modifier.weight(1f).clickable { onSet(p) },
                ) {
                    Text(
                        p.label,
                        fontSize = 13.sp,
                        fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Medium,
                        color = if (selected) palette.textPrimary else palette.textSecondary,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.padding(vertical = 6.dp).fillMaxWidth(),
                    )
                }
            }
        }
    }
}

@Composable
private fun RulesCard(period: RankingPeriod, palette: AppTheme) {
    Surface(color = palette.surface, shape = RoundedCornerShape(18.dp), modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Icon(Icons.Filled.EmojiEvents, contentDescription = null, tint = palette.settingsAccent, modifier = Modifier.size(18.dp))
                Text(period.rulesTitle, style = AppType.headline, color = palette.settingsAccent)
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                PriorityPill(1, "連続日数が長い", palette.primary, palette)
                PriorityPill(2, "運動時間が長い", palette.settingsAccent, palette)
            }
            Text(period.resetHint, style = AppType.caption, color = palette.textSecondary)
        }
    }
}

@Composable
private fun PriorityPill(number: Int, label: String, color: Color, palette: AppTheme) {
    Surface(color = color.copy(alpha = 0.10f), shape = RoundedCornerShape(50)) {
        Row(
            Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Box(Modifier.size(18.dp).clip(CircleShape).background(color), contentAlignment = Alignment.Center) {
                Text("$number", color = Color.White, style = AppType.caption2.copy(fontWeight = FontWeight.ExtraBold))
            }
            Text(label, style = AppType.caption, color = palette.textPrimary)
        }
    }
}

@Composable
private fun MySummaryCard(me: WeeklyRankingEntry, total: Int, period: RankingPeriod, palette: AppTheme) {
    // iOS パリティ: グラデ(primary 0.18→0.06, 左上→右下)+ 枠線(primary@0.4, 1.5dp)。
    val shape = RoundedCornerShape(20.dp)
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(
                Brush.linearGradient(
                    colors = listOf(palette.primary.copy(alpha = 0.18f), palette.primary.copy(alpha = 0.06f)),
                    start = Offset.Zero,
                    end = Offset.Infinite,
                ),
            )
            .border(1.5.dp, palette.primary.copy(alpha = 0.4f), shape),
    ) {
        Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            Box(Modifier.size(64.dp).clip(CircleShape).background(palette.primary.copy(alpha = 0.18f)), contentAlignment = Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("${me.rank}", fontSize = 24.sp, fontWeight = FontWeight.Black, color = palette.primaryDeep) // parity-allow: iOS WeeklyRankingView 自分順位 size24 .black 準拠
                    Text("位", fontSize = 10.sp, fontWeight = FontWeight.SemiBold, color = palette.primaryDeep) // parity-allow: iOS 順位ラベル小サイズ
                }
            }
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text("あなたは ${me.rank} 位 / 全 $total 人中", style = AppType.headline, color = palette.textPrimary)
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    StatLabel(Icons.Filled.Pets, "${me.profile.currentStreak} 日連続", palette.primaryDeep)
                    StatLabel(Icons.Filled.Schedule, "${me.totalMinutes} 分", palette.textSecondary)
                }
            }
        }
    }
}

@Composable
private fun RankRow(entry: WeeklyRankingEntry, palette: AppTheme) {
    val shape = RoundedCornerShape(14.dp)
    Surface(
        color = if (entry.isMe) palette.primary.copy(alpha = 0.08f) else palette.surface,
        shape = shape,
        // iOS パリティ: 自分の行は 2dp primary 枠。
        modifier = Modifier.fillMaxWidth().then(if (entry.isMe) Modifier.border(2.dp, palette.primary, shape) else Modifier),
    ) {
        Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            RankBadge(entry.rank, palette)
            // iOS は常に猫アバター(未設定は friendCode 由来の決定論的猫)。アイコンfallbackは置かない。
            CatAvatar(breed = FriendAvatarResolver.resolve(entry.profile), size = 44.dp)
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(entry.profile.displayName, style = AppType.headline, color = palette.textPrimary)
                    if (entry.isMe) {
                        Surface(color = palette.primary, shape = RoundedCornerShape(50)) {
                            Text("あなた", fontSize = 10.sp, fontWeight = FontWeight.ExtraBold, color = Color.White, modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp))
                        }
                    }
                }
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    StatLabel(Icons.Filled.Pets, "${entry.profile.currentStreak}", palette.primaryDeep)
                    StatLabel(Icons.Filled.Schedule, "${entry.totalMinutes}分", palette.textSecondary)
                }
            }
        }
    }
}

/** 順位バッジ。iOS は絵文字メダルを廃止し「金/銀/銅の色丸 + 番号」。Android も追従(iOS RGB 一致)。 */
@Composable
private fun RankBadge(rank: Int, palette: AppTheme) {
    // iOS パリティ: メダル塗りに不透明度(金0.85/銀0.90/銅0.85)、数字色は段ごとの暗色。
    val medalColor = when (rank) {
        1 -> Color(1.00f, 0.84f, 0.30f).copy(alpha = 0.85f)   // gold
        2 -> Color(0.78f, 0.78f, 0.82f).copy(alpha = 0.90f)   // silver
        3 -> Color(0.82f, 0.55f, 0.32f).copy(alpha = 0.85f)   // bronze
        else -> palette.chipBackground
    }
    val numberColor = when (rank) {
        1 -> Color(0.42f, 0.30f, 0.0f)
        2 -> Color(0.28f, 0.28f, 0.32f)
        3 -> Color(0.38f, 0.22f, 0.08f)
        else -> palette.textPrimary
    }
    Box(
        modifier = Modifier.size(40.dp).clip(CircleShape).background(medalColor),
        contentAlignment = Alignment.Center,
    ) {
        Text("$rank", color = numberColor, style = AppType.body.copy(fontWeight = FontWeight.ExtraBold))
    }
}

/** 空状態(pawprint 34dp in 86dp primary@0.12 円 + メッセージを surface@0.75 カード)。iOS EmptyStateView 相当。 */
@Composable
private fun RankingEmptyState(message: String, palette: AppTheme) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(22.dp))
            .background(palette.surface.copy(alpha = 0.75f))
            .padding(28.dp),
        contentAlignment = Alignment.Center,
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Box(
                Modifier.size(86.dp).clip(CircleShape).background(palette.primary.copy(alpha = 0.12f)),
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.Filled.Pets, contentDescription = null, tint = palette.primary, modifier = Modifier.size(34.dp))
            }
            Text(message, color = palette.textSecondary, textAlign = TextAlign.Center, style = AppType.subheadline.copy(fontWeight = FontWeight.Normal))
        }
    }
}

/** アイコン + テキストの小さな統計ラベル(肉球=連続 / 時計=分)。iOS Label パリティ。 */
@Composable
private fun StatLabel(icon: androidx.compose.ui.graphics.vector.ImageVector, text: String, tint: Color) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(13.dp))
        Text(text, color = tint, style = AppType.caption.copy(fontWeight = FontWeight.SemiBold))
    }
}
