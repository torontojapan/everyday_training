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
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
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
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.runtime.withFrameNanos
import kotlinx.coroutines.launch
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
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.StarBorder
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
    val referralRow by viewModel.referralRow.collectAsStateWithLifecycle()
    Box(modifier = Modifier.fillMaxSize()) {
        HomeContent(
            state = state,
            onRecordClick = onRecordClick,
            onShareClick = onShareClick,
            celebrate = celebrateConfetti,
            onCelebrateConsumed = viewModel::consumeCelebrateConfetti,
            referralRow = referralRow,
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
                    // iOS「やったね!」(絵文字除去方針のためタイトルは「⭐」→「星10」)。本文は iOS と同一文言。
                    TextButton(onClick = { viewModel.consumeBreedUnlock() }) { Text("やったね!") }
                },
                title = { Text("星10達成！") },
                text = { Text("友達を10人紹介しました!設定や猫選びの画面から、好きな猫が無料で選べるようになりました。") },
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
    // ホーム上段3行目の紹介スター行(iOS referralStarsFullRow)。ゲート未充足なら null。
    referralRow: ReferralRowUi? = null,
) {
    // 週カレンダーの日タップで開く DayDetailSheet 用の選択日(iOS selectedDayEntry)。
    var selectedDay by remember { mutableStateOf<DailyStatusEntry?>(null) }
    Box(modifier = Modifier.fillMaxSize()) {
        // 連続ランク駆動の進化背景(最背面)。
        com.goexercise.app.ui.components.MilestoneBackdrop(streak = state.streak.currentStreak)
        // 常時の環境パーティクル(時刻別: 朝=花/昼=泡/夕=葉/夜=星)。iOS AmbientParticlesView パリティ。
        AmbientParticles(hour = remember { java.time.LocalTime.now().hour }, modifier = Modifier.fillMaxSize())
        Column(modifier = Modifier.fillMaxSize()) {
            // 上段クラスタ(今週 + 連続/称号/状態)。
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp)
                    .padding(top = 4.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                WeeklyMini(state, onDayClick = { selectedDay = it })
                TopStatusBar(state, onShareClick)
                // 上段3行目: 紹介スター行(称号と分離して全幅・最大10星が折り返さず一直線)。
                referralRow?.let { ReferralStarsRow(it) }
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
    // 週カレンダー日タップ → 履歴と同じ DayDetailSheet を再利用(iOS .sheet(item: selectedDayEntry))。
    // その日の記録だけ weekRecords から絞り込む(iOS は store.records を同日フィルタ)。
    selectedDay?.let { entry ->
        com.goexercise.app.presentation.history.DayDetailSheet(
            date = entry.date,
            status = entry.status,
            records = state.weekRecords.filter { it.date == entry.date },
            onDismiss = { selectedDay = null },
        )
    }
}

// MARK: - 今週ミニ -----------------------------------------------------------------

@Composable
private fun WeeklyMini(state: HomeUiState, onDayClick: (DailyStatusEntry) -> Unit = {}) {
    val palette = LocalAppPalette.current
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("今週", style = AppType.headline.copy(fontWeight = FontWeight.Black), color = palette.textPrimary)
            Spacer(Modifier.weight(1f))
            Text(
                "${state.weeklyProgress.achievedCount} / ${state.weeklyProgress.totalDays} 日達成",
                // iOS: monospacedDigit。等幅数字で達成数の桁ぶれを防ぐ。
                style = AppType.headline.copy(fontWeight = FontWeight.SemiBold, fontFeatureSettings = "tnum"),
                color = palette.textSecondary,
            )
        }
        WeeklyCalendar(state.weekStatuses, onDayClick)
    }
}

private val WeekdayLabels = listOf("月", "火", "水", "木", "金", "土", "日")

@Composable
private fun WeeklyCalendar(week: List<DailyStatusEntry>, onDayClick: (DailyStatusEntry) -> Unit = {}) {
    val palette = LocalAppPalette.current
    // iOS WeeklyCalendarView: 今日セルは 1.05↔1.0 の呼吸アニメ(repeatForever autoreverse)。
    val breath = rememberInfiniteTransition(label = "today-breath")
    val breathScale by breath.animateFloat(
        initialValue = 1.0f, targetValue = 1.05f,
        animationSpec = infiniteRepeatable(tween(1400), RepeatMode.Reverse), label = "breathScale",
    )
    Surface(color = palette.surface, shape = RoundedCornerShape(22.dp), modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.padding(12.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            week.forEachIndexed { index, entry ->
                val isToday = entry.status == DailyStatus.TodayAchieved || entry.status == DailyStatus.TodayPending
                // iOS は曜日ラベル込みのセル全体を「今日」だけ呼吸スケールで強調する。
                // iOS WeeklyCalendarView: 各セルは plain Button → タップで DayDetailSheet。
                // 全日タップ可。リップル無し(plain 相当)で iOS の見た目に合わせる。
                Column(
                    modifier = Modifier
                        .weight(1f)
                        .scale(if (isToday) breathScale else 1f)
                        .clickable(
                            interactionSource = remember { MutableInteractionSource() },
                            indication = null,
                        ) { onDayClick(entry) },
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

// MARK: - 紹介スター行 (iOS ReferralStarsRow) -------------------------------------

/** 金の星は「ご褒美」感を出すため常に暖色のゴールド(iOS Color.orange = systemOrange #FF9500)。 */
private val ReferralStarGold = Color(0xFFFF9500)

/**
 * ホーム上段3行目の紹介スター行。星(上)+キャプション(下)を縦積みし、全幅をタップで招待を共有する。
 * iOS `ReferralStarsRow` / `ReferralStarsDisplay.style` のパリティ:
 *   1〜9 → 金 filled + 枠 で 10 個並べ「あとN人で猫が解放」/ 10 → 全金 / 11+ → 金1個+数値。
 */
@Composable
private fun ReferralStarsRow(row: ReferralRowUi) {
    val palette = LocalAppPalette.current
    val context = LocalContext.current
    val total = com.goexercise.app.domain.CatBreedAccess.BREED_UNLOCK_STARS
    val count = row.stars
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clickable {
                val intent = Intent(Intent.ACTION_SEND).apply {
                    type = "text/plain"
                    putExtra(Intent.EXTRA_TEXT, referralInviteText(row.friendCode))
                }
                context.startActivity(Intent.createChooser(intent, "友達を招待"))
            },
        verticalArrangement = Arrangement.spacedBy(3.dp),
    ) {
        when {
            // collapsed(11+): 金の星1個 + 数値。
            count > total -> Row(
                horizontalArrangement = Arrangement.spacedBy(4.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                ReferralStar(filled = true)
                Text(
                    "$count",
                    style = AppType.headline.copy(fontWeight = FontWeight.Black),
                    color = palette.textPrimary,
                )
            }
            // progress(1〜9) / complete(10): 10 個並べ、先頭 count 個を金 filled。
            else -> FlowRow(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                repeat(total) { i -> ReferralStar(filled = i < count) }
            }
        }
        if (count in 1 until total) {
            Text(
                "あと${total - count}人で猫が解放",
                style = AppType.caption.copy(fontWeight = FontWeight.Medium),
                color = palette.textSecondary,
            )
        }
    }
}

@Composable
private fun ReferralStar(filled: Boolean) {
    val palette = LocalAppPalette.current
    Icon(
        imageVector = if (filled) Icons.Filled.Star else Icons.Filled.StarBorder,
        contentDescription = null,
        tint = if (filled) ReferralStarGold else palette.textSecondary.copy(alpha = 0.3f),
        modifier = Modifier.size(18.dp),
    )
}

/** 招待共有テキスト。iOS ReferralStarsRow.inviteText パリティ(URL のみ Play ストアに差し替え)。 */
private fun referralInviteText(friendCode: String): String =
    "GOエクササイズで一緒に運動しよう！オンボーディングでこの招待コードを入れると、" +
        "お互いに保険チケットがもらえます → $friendCode\n" +
        "https://play.google.com/store/apps/details?id=com.goexercise.app"

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

// MARK: - 環境パーティクル(iOS AmbientParticlesView 移植) --------------------------

private enum class AmbientShape { Circle, Star, Leaf, Petal }

private fun ambientPalette(hour: Int): List<Color> = when (hour) {
    in 5..10 -> listOf(Color(1.0f, 0.78f, 0.78f), Color(1.0f, 0.88f, 0.85f), Color(1.0f, 0.72f, 0.65f))   // 朝
    in 11..15 -> listOf(Color(1.0f, 0.94f, 0.78f), Color(1.0f, 0.90f, 0.70f), Color(0.98f, 0.85f, 0.65f)) // 昼
    in 16..20 -> listOf(Color(1.0f, 0.65f, 0.40f), Color(1.0f, 0.75f, 0.45f), Color(0.95f, 0.55f, 0.30f))  // 夕
    else -> listOf(Color(0.85f, 0.88f, 0.95f), Color(0.70f, 0.78f, 0.90f), Color(0.95f, 0.95f, 0.85f))     // 夜
}

private fun ambientShapeFor(hour: Int): AmbientShape = when (hour) {
    in 5..10 -> AmbientShape.Petal
    in 11..15 -> AmbientShape.Circle
    in 16..20 -> AmbientShape.Leaf
    else -> AmbientShape.Star
}

/** ホーム背景にゆっくり漂う時刻別パーティクル(18粒)。iOS AmbientParticlesView の純関数描画を移植。 */
@Composable
private fun AmbientParticles(hour: Int, modifier: Modifier = Modifier) {
    val now = remember { mutableStateOf(0.0) }
    LaunchedEffect(Unit) {
        val start = withFrameNanos { it }
        while (true) {
            withFrameNanos { frame -> now.value = (frame - start) / 1_000_000_000.0 }
        }
    }
    val palette = ambientPalette(hour)
    val shape = ambientShapeFor(hour)
    androidx.compose.foundation.Canvas(modifier) {
        val t = now.value
        val w = size.width
        val h = size.height
        for (i in 0 until 18) {
            val seed = i * 13.37
            val baseX = ((kotlin.math.sin(seed * 1.13) % 1.0) + 1.0) * 0.5 * w
            val period = 18.0 + (i % 12)
            var phase = (t / period + seed) % 1.0
            if (phase < 0) phase += 1.0
            val y = h * (1.0 - phase)
            val wobble = kotlin.math.sin(t * 0.6 + seed) * 24.0
            val x = (baseX + wobble)
            val alpha = (kotlin.math.sin(phase * Math.PI) * 0.55).toFloat().coerceIn(0f, 1f)
            val radius = (8.0 + (i % 5) * 2).toFloat()
            val color = palette[i % palette.size].copy(alpha = alpha)
            val cx = x.toFloat()
            val cy = y.toFloat()
            when (shape) {
                AmbientShape.Circle -> drawOval(
                    color = color,
                    topLeft = androidx.compose.ui.geometry.Offset(cx - radius, cy - radius),
                    size = androidx.compose.ui.geometry.Size(radius * 2, radius * 2),
                )
                AmbientShape.Star -> drawPath(starPath(cx, cy, radius, 5), color)
                AmbientShape.Leaf, AmbientShape.Petal -> drawPath(leafPath(cx, cy, radius, radius), color)
            }
        }
    }
}

private fun leafPath(cx: Float, cy: Float, rx: Float, ry: Float): Path = Path().apply {
    moveTo(cx, cy - ry)
    quadraticBezierTo(cx + rx, cy, cx, cy + ry)
    quadraticBezierTo(cx - rx, cy, cx, cy - ry)
    close()
}

private fun starPath(cx: Float, cy: Float, outer: Float, points: Int): Path = Path().apply {
    val inner = outer * 0.45f
    for (i in 0 until points * 2) {
        val r = if (i % 2 == 0) outer else inner
        val theta = i * Math.PI / points - Math.PI / 2
        val px = (cx + r * kotlin.math.cos(theta)).toFloat()
        val py = (cy + r * kotlin.math.sin(theta)).toFloat()
        if (i == 0) moveTo(px, py) else lineTo(px, py)
    }
    close()
}

// MARK: - 猫劇場 -------------------------------------------------------------------

@Composable
private fun CatTheater(state: HomeUiState) {
    val haptic = androidx.compose.ui.platform.LocalHapticFeedback.current
    val scope = androidx.compose.runtime.rememberCoroutineScope()
    // iOS BigCatView の合成アイドル: 呼吸(2.4s) / 浮遊(3.2s) / 傾き(4.1s)。
    val idle = rememberInfiniteTransition(label = "cat-idle")
    val breathing by idle.animateFloat(1f, 1.03f, infiniteRepeatable(tween(2400), RepeatMode.Reverse), label = "breath")
    val floatY by idle.animateFloat(4f, -8f, infiniteRepeatable(tween(3200), RepeatMode.Reverse), label = "float")
    val sway by idle.animateFloat(-2f, 2f, infiniteRepeatable(tween(4100), RepeatMode.Reverse), label = "sway")
    // タップ bounce(iOS scaleEffect 1.08 + haptic)。
    val bounce = remember { androidx.compose.animation.core.Animatable(1f) }
    val tint = Color(state.catBreed.tintArgb)
    // 吹き出しの pop-in(scale0.7→1 + fade, delay0.15)。
    var bubbleAppeared by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { kotlinx.coroutines.delay(150); bubbleAppeared = true }
    val bubbleScale by androidx.compose.animation.core.animateFloatAsState(
        targetValue = if (bubbleAppeared) 1f else 0.7f,
        animationSpec = androidx.compose.animation.core.spring(dampingRatio = 0.7f, stiffness = androidx.compose.animation.core.Spring.StiffnessMediumLow),
        label = "bubbleScale",
    )
    val bubbleAlpha by androidx.compose.animation.core.animateFloatAsState(
        targetValue = if (bubbleAppeared) 1f else 0f, label = "bubbleAlpha",
    )
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(
            modifier = Modifier
                .size(280.dp)
                .clickable(
                    interactionSource = remember { androidx.compose.foundation.interaction.MutableInteractionSource() },
                    indication = null,
                ) {
                    haptic.performHapticFeedback(androidx.compose.ui.hapticfeedback.HapticFeedbackType.LongPress)
                    scope.launch {
                        bounce.animateTo(1.08f, androidx.compose.animation.core.spring(stiffness = 900f, dampingRatio = 0.45f))
                        bounce.animateTo(1f, androidx.compose.animation.core.spring(dampingRatio = 0.55f, stiffness = androidx.compose.animation.core.Spring.StiffnessLow))
                    }
                },
            contentAlignment = Alignment.Center,
        ) {
            // 背景の光輪(iOS: breed tint .32→.06、画像より一回り内側 0.88)。
            Box(
                Modifier.fillMaxSize(0.88f).clip(CircleShape)
                    .background(Brush.linearGradient(listOf(tint.copy(alpha = 0.32f), tint.copy(alpha = 0.06f)))),
            )
            com.goexercise.app.ui.components.CatImage(
                breed = state.catBreed,
                state = state.catState,
                useShaker = !state.todayStatus.countsAsAchieved,
                modifier = Modifier.fillMaxSize().graphicsLayer {
                    val s = breathing * bounce.value
                    scaleX = s; scaleY = s
                    translationY = floatY.dp.toPx()
                    rotationZ = sway
                },
            )
        }
        SpeechBubble(
            state.catMessage.text,
            modifier = Modifier.padding(horizontal = 24.dp).graphicsLayer {
                scaleX = bubbleScale; scaleY = bubbleScale; alpha = bubbleAlpha
            },
        )
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
                maxLines = 3, // iOS lineLimit(3)
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
