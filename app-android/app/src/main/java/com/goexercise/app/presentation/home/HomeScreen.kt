package com.goexercise.app.presentation.home

import android.content.Intent
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AddCircle
import androidx.compose.material.icons.filled.Bedtime
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.IosShare
import androidx.compose.material.icons.filled.MeetingRoom
import androidx.compose.material.icons.filled.MilitaryTech
import androidx.compose.material.icons.filled.Pets
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material.icons.filled.WorkspacePremium
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.goexercise.app.domain.CatRank
import com.goexercise.app.domain.DailyStatus
import com.goexercise.app.domain.DailyStatusEntry
import com.goexercise.app.domain.Milestone
import com.goexercise.app.domain.RankUpEvent
import com.goexercise.app.presentation.review.findActivity
import com.goexercise.app.presentation.review.launchInAppReview
import com.goexercise.app.ui.components.RankCelebrationOverlay
import com.goexercise.app.ui.components.StreakRevivePopup
import com.goexercise.app.ui.theme.AppTheme
import com.goexercise.app.ui.theme.AppType
import com.goexercise.app.ui.theme.GOExerciseTheme
import com.goexercise.app.ui.theme.LocalAppPalette
import java.time.LocalDateTime

/** Home ルートのエントリ。VM から状態を購読して [HomeContent] に渡す。 */
@Composable
fun HomeRoute(
    onRecordClick: () -> Unit = {},
    onShareClick: () -> Unit = {},
    onOpenFreezePaywall: () -> Unit = {},
    viewModel: HomeViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val pendingMilestone by viewModel.pendingMilestone.collectAsStateWithLifecycle()
    val welcome by viewModel.pendingWelcome.collectAsStateWithLifecycle()
    val referrerPops by viewModel.pendingReferrerPops.collectAsStateWithLifecycle()
    val breedUnlock by viewModel.pendingBreedUnlock.collectAsStateWithLifecycle()
    val pendingRankEvent by viewModel.pendingRankEvent.collectAsStateWithLifecycle()
    val reviveState by viewModel.reviveState.collectAsStateWithLifecycle()

    // レビュー依頼: VM が節目到達を検知したら Play In-App Review を起動(表示可否は Google 判断)。
    val reviewRequested by viewModel.pendingReviewRequest.collectAsStateWithLifecycle()
    val reviewContext = LocalContext.current
    LaunchedEffect(reviewRequested) {
        if (reviewRequested) {
            reviewContext.findActivity()?.let { launchInAppReview(it) }
            viewModel.clearReviewRequest()
        }
    }

    val celebrateConfetti by viewModel.celebrateConfetti.collectAsStateWithLifecycle()
    Box(modifier = Modifier.fillMaxSize()) {
        HomeContent(
            state = state,
            onRecordClick = onRecordClick,
            onShareClick = onShareClick,
            celebrate = celebrateConfetti,
            onCelebrateConsumed = viewModel::consumeCelebrateConfetti,
        )
        // 機能B: 小節目の軽量トースト(HomeContent の上に重ねる。自動消滅で操作は遮らない)。
        // 大節目ダイアログ提示中(pendingMilestone != null)は二重演出を避けて出さない(VM の guard と二重化)。
        if (pendingMilestone == null) pendingRankEvent?.let { event ->
            val (rank, message) = rankCelebrationDisplay(event)
            RankCelebrationOverlay(
                rank = rank,
                message = message,
                onFinished = { viewModel.clearRankEvent() },
            )
        }
    }

    pendingMilestone?.let { milestone ->
        MilestoneCelebrationDialog(
            milestone = milestone,
            onDismiss = { viewModel.acknowledgeMilestone(milestone) },
        )
    }
    if (com.goexercise.app.AppFeatureFlags.isReferralActive) {
        welcome?.let { com.goexercise.app.presentation.referral.ReferralCelebrationDialog(listOf(it)) { viewModel.consumeWelcome() } }
        if (referrerPops.isNotEmpty()) com.goexercise.app.presentation.referral.ReferralCelebrationDialog(referrerPops) { viewModel.consumeReferrerPops() }
        // ⭐10 達成で全猫種解放の祝福(アカウント別 1 回限り)。
        if (breedUnlock) {
            AlertDialog(
                onDismissRequest = { viewModel.consumeBreedUnlock() },
                confirmButton = {
                    TextButton(onClick = { viewModel.consumeBreedUnlock() }) { Text("やった！") }
                },
                title = { Text("星10個 達成！") },
                text = { Text("友達紹介の星が10個に到達しました。すべての猫種が解放されました！設定からいつでも変更できます。") },
            )
        }
    }

    // 機能D: 復活ポップ。**launch ごとに 1 度だけ**、復活可能 かつ この途切れが未対応の時に出す。
    var reviveShownThisLaunch by rememberSaveable { mutableStateOf(false) }
    var reviveDismissedLocal by remember { mutableStateOf(false) }
    reviveState?.let { rs ->
        val handled = viewModel.reviveBreakHandled(rs)
        if (!handled && !reviveShownThisLaunch && !reviveDismissedLocal) {
            StreakRevivePopup(
                potentialStreak = rs.potentialStreak,
                freezesNeeded = rs.result.freezesNeeded,
                remaining = rs.remaining,
                hasEnough = rs.result.hasEnough,
                onUseFreeze = {
                    reviveShownThisLaunch = true
                    viewModel.applyRevive()
                },
                onSeePremium = {
                    reviveShownThisLaunch = true
                    onOpenFreezePaywall()
                },
                onDismiss = {
                    reviveShownThisLaunch = true
                    reviveDismissedLocal = true
                    viewModel.dismissRevive()
                },
            )
        }
    }
}

/** RankUpEvent → 表示用の (称号ランク, メッセージ)。RankUp は到達した称号の閾値 streak でランクを作る。 */
private fun rankCelebrationDisplay(event: RankUpEvent): Pair<CatRank, String> = when (event) {
    is RankUpEvent.RankUp -> {
        // rank=to の閾値 streak からランクを再構成(thresholds は公開済み・1-indexed の to)。
        val thresholdStreak = CatRank.thresholds.getOrNull(event.to - 1) ?: 0
        CatRank.of(thresholdStreak) to "称号アップ!"
    }
    is RankUpEvent.Weekly -> CatRank.of(event.streak) to "${event.streak}日連続!"
}

/** 節目バッジの Material アイコン(iOS の SF Symbol rosette/trophy/medal/crown 相当)。
 *  iOS は「絵文字は安っぽい」とブランド方針で廃止し、金色のシンボルに統一。Android も追従。 */
private fun milestoneIcon(milestone: Milestone): ImageVector = when (milestone) {
    is Milestone.Anniversary -> Icons.Filled.WorkspacePremium                                          // rosette
    is Milestone.LifetimeDays -> if (milestone.days >= 365) Icons.Filled.EmojiEvents else Icons.Filled.MilitaryTech  // trophy / medal
    is Milestone.CurrentStreak -> Icons.Filled.WorkspacePremium                                        // crown→premium seal / rosette
    is Milestone.WeightLoss -> if (milestone.kg >= 10) Icons.Filled.EmojiEvents else Icons.Filled.MilitaryTech       // trophy / medal
}

/** 達成お祝いダイアログ(金色シンボル + 見出し + 詳細 + シェア + 閉じる)。iOS MilestoneCelebrationSheet 相当。 */
@Composable
private fun MilestoneCelebrationDialog(milestone: Milestone, onDismiss: () -> Unit) {
    val palette = LocalAppPalette.current
    val context = LocalContext.current
    AlertDialog(
        onDismissRequest = onDismiss,
        icon = {
            Icon(
                imageVector = milestoneIcon(milestone),
                contentDescription = null,
                tint = Color(0xFFFFB300), // 金色(iOS の金グラデ相当)
                modifier = Modifier.size(48.dp),
            )
        },
        title = { Text(milestone.headline, fontWeight = FontWeight.Bold, color = palette.textPrimary, textAlign = TextAlign.Center) },
        text = { Text(milestone.detail, color = palette.textSecondary, textAlign = TextAlign.Center) },
        confirmButton = {
            TextButton(onClick = {
                val intent = Intent(Intent.ACTION_SEND).apply {
                    type = "text/plain"
                    putExtra(Intent.EXTRA_TEXT, "${milestone.shareMessage}\nhttps://goexercise.app")
                }
                runCatching { context.startActivity(Intent.createChooser(intent, "シェア")) }
                onDismiss()
            }) { Text("シェアする", color = palette.primaryDeep, fontWeight = FontWeight.Bold) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("閉じる", color = palette.textSecondary) } },
        containerColor = palette.surface,
    )
}

/**
 * ステートレスなホーム本体。iOS `HomeView` の構成を 1:1 で踏襲する:
 * 上段(今週ミニ + 連続バッジ/称号/状態チップ)→ 猫劇場(中央主役・吹き出し三角しっぽ)→
 * 復帰カード(条件付き)→ 下部固定の大型 CTA。スクロールしない固定レイアウト。
 */
@Composable
fun HomeContent(
    state: HomeUiState,
    onRecordClick: () -> Unit = {},
    onShareClick: () -> Unit = {},
    // 紙吹雪は VM が「記録完了(今日の新規記録)」でのみ true にする one-shot 信号で駆動する。
    celebrate: Boolean = false,
    onCelebrateConsumed: () -> Unit = {},
) {
    Box(modifier = Modifier.fillMaxSize()) {
        // 連続ランク駆動の進化背景(最背面)。
        com.goexercise.app.ui.components.MilestoneBackdrop(streak = state.streak.currentStreak)
        Column(modifier = Modifier.fillMaxSize()) {
            // 上段クラスタ(今週 + 連続/称号/状態)。
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp)
                    .padding(top = 4.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                WeeklyMini(state)
                TopStatusBar(state, onShareClick)
            }
            // 猫劇場。余白を占有して中央のステージ感を出す。
            Box(modifier = Modifier.weight(1f), contentAlignment = Alignment.Center) {
                CatTheater(state)
            }
            if (state.isComebackToday) {
                ComebackWelcomeCard(modifier = Modifier.padding(horizontal = 20.dp))
            }
            LargePrimaryCTA(
                state = state,
                onClick = onRecordClick,
                modifier = Modifier
                    .padding(horizontal = 20.dp)
                    .padding(bottom = 10.dp),
            )
        }
        // 達成時の全画面紙吹雪(最前面)。記録完了でのみ VM が点火、終了で consume。iOS パリティ。
        com.goexercise.app.ui.components.ConfettiOverlay(play = celebrate, onFinished = onCelebrateConsumed)
    }
}

// MARK: - 今週ミニ -----------------------------------------------------------------

@Composable
private fun WeeklyMini(state: HomeUiState) {
    val palette = LocalAppPalette.current
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("今週", style = AppType.headline.copy(fontWeight = FontWeight.Black), color = palette.textPrimary)
            Spacer(Modifier.weight(1f))
            Text(
                "${state.weeklyProgress.achievedCount} / ${state.weeklyProgress.totalDays} 日達成",
                style = AppType.headline.copy(fontWeight = FontWeight.SemiBold),
                color = palette.textSecondary,
            )
        }
        WeeklyCalendar(state.weekStatuses)
    }
}

private val WeekdayLabels = listOf("月", "火", "水", "木", "金", "土", "日")

@Composable
private fun WeeklyCalendar(week: List<DailyStatusEntry>) {
    val palette = LocalAppPalette.current
    Surface(color = palette.surface, shape = RoundedCornerShape(22.dp), modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.padding(12.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            week.forEachIndexed { index, entry ->
                val isToday = entry.status == DailyStatus.TodayAchieved || entry.status == DailyStatus.TodayPending
                // iOS は曜日ラベル込みのセル全体を 1.05 倍にして「今日」を強調する。
                Column(
                    modifier = Modifier
                        .weight(1f)
                        .scale(if (isToday) 1.05f else 1f),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Text(WeekdayLabels.getOrElse(index) { "" }, style = AppType.caption, color = palette.textPrimary)
                    Box(
                        modifier = Modifier
                            .size(38.dp)
                            .clip(CircleShape)
                            .background(weeklyCellColor(entry, isToday)),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            entry.status.symbol,
                            style = AppType.headline.copy(fontWeight = FontWeight.Bold),
                            color = palette.textPrimary,
                        )
                    }
                }
            }
        }
    }
}

/** iOS WeeklyCalendarView.background(for:) と同じ不透明度調整つき配色。今日は primary。 */
@Composable
private fun weeklyCellColor(entry: DailyStatusEntry, isToday: Boolean): Color {
    val palette = LocalAppPalette.current
    if (isToday) return palette.primary.copy(alpha = 0.95f)
    return when (entry.status) {
        DailyStatus.Achieved, DailyStatus.TodayAchieved -> Color(0.93f, 0.33f, 0.30f).copy(alpha = 0.65f)
        DailyStatus.Rest -> Color(0.36f, 0.65f, 0.40f).copy(alpha = 0.60f)
        DailyStatus.Rescued -> Color(0.36f, 0.65f, 0.40f).copy(alpha = 0.35f)
        DailyStatus.Missed -> Color(0.38f, 0.55f, 0.90f).copy(alpha = 0.32f)
        DailyStatus.Future, DailyStatus.TodayPending -> palette.secondary.copy(alpha = 0.45f)
    }
}

// MARK: - 上段ステータスバー ------------------------------------------------------

@Composable
private fun TopStatusBar(state: HomeUiState, onShareClick: () -> Unit) {
    // IntrinsicSize.Min で行高=右列(称号+状態)に揃え、StreakBadge を fillMaxHeight で
    // 同じ高さに伸ばす(iOS StreakBadgeView fillHeight:true パリティ)。
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(IntrinsicSize.Min),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.Top,
    ) {
        StreakBadge(
            streak = state.streak.currentStreak,
            onShareClick = onShareClick,
            modifier = Modifier.fillMaxHeight(),
        )
        Spacer(Modifier.weight(1f))
        Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(6.dp)) {
            val rank = CatRank.of(state.streak.currentStreak)
            if (rank.rank > 0) com.goexercise.app.ui.components.CatRankChip(rank = rank)
            StatusChip(state.todayStatus)
        }
    }
}

/** 連続日数バッジ(肉球 + N日連続 + 共有アイコン)。iOS StreakBadgeView パリティ。旧 🔥 を肉球に統一。 */
@Composable
private fun StreakBadge(streak: Int, onShareClick: () -> Unit, modifier: Modifier = Modifier) {
    val palette = LocalAppPalette.current
    Surface(
        color = palette.secondary.copy(alpha = 0.8f),
        shape = RoundedCornerShape(20.dp),
        modifier = modifier.then(if (streak > 0) Modifier.clickable { onShareClick() } else Modifier),
    ) {
        Row(
            modifier = Modifier
                .fillMaxHeight()
                .padding(horizontal = 18.dp, vertical = 12.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(Icons.Filled.Pets, contentDescription = null, tint = palette.primaryDeep, modifier = Modifier.size(20.dp))
            Text("${streak}日連続", style = AppType.sectionTitle.copy(fontWeight = FontWeight.Black), color = palette.textPrimary)
            if (streak > 0) {
                Icon(Icons.Filled.IosShare, contentDescription = "共有", tint = palette.textSecondary, modifier = Modifier.size(16.dp))
            }
        }
    }
}

/** 今日の状態チップ。達成済み(緑)/ 回復日(青)/ 残り時間(無印)。iOS statusChip パリティ。 */
@Composable
private fun StatusChip(todayStatus: DailyStatus) {
    val palette = LocalAppPalette.current
    when (todayStatus) {
        DailyStatus.TodayAchieved -> ChipCapsule(bg = palette.success.copy(alpha = 0.18f)) {
            Icon(Icons.Filled.Verified, contentDescription = null, tint = palette.success, modifier = Modifier.size(15.dp))
            Text("今日は達成済み", style = AppType.caption.copy(fontWeight = FontWeight.Black), color = palette.success)
        }
        DailyStatus.Rest -> ChipCapsule(bg = palette.restDay.copy(alpha = 0.30f)) {
            Icon(Icons.Filled.Bedtime, contentDescription = null, tint = palette.textPrimary, modifier = Modifier.size(15.dp))
            Text("今日は回復日", style = AppType.caption.copy(fontWeight = FontWeight.Black), color = palette.textPrimary)
        }
        else -> ChipCapsule(bg = palette.surface) {
            Text(remainingTimeText(), style = AppType.caption.copy(fontWeight = FontWeight.SemiBold), color = palette.textSecondary)
        }
    }
}

@Composable
private fun ChipCapsule(bg: Color, content: @Composable () -> Unit) {
    Surface(color = bg, shape = RoundedCornerShape(50)) {
        Row(
            modifier = Modifier.padding(horizontal = 11.dp, vertical = 6.dp),
            horizontalArrangement = Arrangement.spacedBy(4.dp),
            verticalAlignment = Alignment.CenterVertically,
            content = { content() },
        )
    }
}

/** 「あと N 時間」(その日の終わりまで)。iOS remainingTimeText パリティ。 */
private fun remainingTimeText(): String {
    val now = LocalDateTime.now()
    val hours = 23 - now.hour
    return "あと${hours.coerceAtLeast(0)}時間"
}

// MARK: - 猫劇場 -------------------------------------------------------------------

@Composable
private fun CatTheater(state: HomeUiState) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        com.goexercise.app.ui.components.CatImage(
            breed = state.catBreed,
            state = state.catState,
            modifier = Modifier.size(280.dp),
            // 今日まだ未記録なら補給(シェイカー)版で「これからやろう」を演出。iOS: !todayStatus.countsAsAchieved。
            useShaker = !state.todayStatus.countsAsAchieved,
        )
        SpeechBubble(state.catMessage.text, modifier = Modifier.padding(horizontal = 24.dp))
    }
}

/** 吹き出し。上に三角しっぽを付けて猫の口元から話しているように見せる。iOS speechBubble パリティ。 */
@Composable
private fun SpeechBubble(text: String, modifier: Modifier = Modifier) {
    val palette = LocalAppPalette.current
    Column(modifier = modifier, horizontalAlignment = Alignment.CenterHorizontally) {
        Canvas(modifier = Modifier.size(width = 18.dp, height = 10.dp)) {
            val p = Path().apply {
                moveTo(0f, size.height)
                lineTo(size.width / 2f, 0f)
                lineTo(size.width, size.height)
                close()
            }
            drawPath(p, color = palette.surface)
        }
        Surface(color = palette.surface, shape = RoundedCornerShape(22.dp)) {
            Text(
                text = text,
                style = AppType.body.copy(fontWeight = FontWeight.SemiBold),
                color = palette.textPrimary,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(horizontal = 20.dp, vertical = 14.dp),
            )
        }
    }
}

// MARK: - 復帰カード / CTA ----------------------------------------------------------

/** 復帰日の歓迎カード(iOS comebackWelcomeCard パリティ)。再開のハードルを下げる。 */
@Composable
private fun ComebackWelcomeCard(modifier: Modifier = Modifier) {
    val palette = LocalAppPalette.current
    Surface(
        color = palette.surface,
        shape = RoundedCornerShape(16.dp),
        modifier = modifier
            .fillMaxWidth()
            .border(1.dp, palette.primary.copy(alpha = 0.35f), RoundedCornerShape(16.dp)),
    ) {
        Row(
            modifier = Modifier.padding(14.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(Icons.Filled.MeetingRoom, contentDescription = null, tint = palette.primaryDeep, modifier = Modifier.size(22.dp))
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text("おかえり", style = AppType.headline, color = palette.textPrimary)
                Text(
                    "昨日はおやすみだったね。今日は30秒でも戻れたら100点。",
                    style = AppType.caption,
                    color = palette.textSecondary,
                )
            }
        }
    }
}

/** 下部固定の大型 CTA。状態別の文言/アイコン、未達成時はパルス。iOS LargePrimaryCTA パリティ。 */
@Composable
private fun LargePrimaryCTA(state: HomeUiState, onClick: () -> Unit, modifier: Modifier = Modifier) {
    val palette = LocalAppPalette.current
    val (title, icon, pulsing) = when {
        state.todayStatus == DailyStatus.TodayAchieved -> Triple("もう一種目する", Icons.Filled.AddCircle, false)
        state.isComebackToday -> Triple("ただいま記録", Icons.Filled.Home, true)
        else -> Triple("今日の運動を記録する", Icons.Filled.AddCircle, true)
    }
    val transition = rememberInfiniteTransition(label = "cta-pulse")
    val scale by transition.animateFloat(
        initialValue = 1f,
        targetValue = if (pulsing) 1.04f else 1f,
        animationSpec = infiniteRepeatable(tween(1400), RepeatMode.Reverse),
        label = "cta-scale",
    )
    Surface(
        color = palette.primary,
        shape = RoundedCornerShape(24.dp),
        modifier = modifier
            .fillMaxWidth()
            .scale(if (pulsing) scale else 1f)
            .clickable { onClick() },
    ) {
        Row(
            modifier = Modifier.padding(vertical = 22.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Spacer(Modifier.weight(1f))
            Icon(icon, contentDescription = null, tint = Color.White, modifier = Modifier.size(26.dp))
            Text(title, style = AppType.sectionTitle.copy(fontWeight = FontWeight.Black), color = Color.White)
            Spacer(Modifier.weight(1f))
        }
    }
}

@androidx.compose.ui.tooling.preview.Preview(showBackground = true)
@Composable
private fun HomeContentPreview() {
    GOExerciseTheme(theme = AppTheme.Peach) {
        HomeContent(state = HomeUiState())
    }
}
