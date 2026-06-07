package com.goexercise.app.presentation.home

import androidx.compose.foundation.background
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
import android.content.Intent
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.goexercise.app.domain.CatRank
import com.goexercise.app.domain.DailyStatus
import com.goexercise.app.domain.DailyStatusEntry
import com.goexercise.app.domain.Milestone
import com.goexercise.app.domain.RankUpEvent
import com.goexercise.app.ui.components.RankCelebrationOverlay
import com.goexercise.app.ui.components.StreakRevivePopup
import com.goexercise.app.ui.theme.AppTheme
import com.goexercise.app.ui.theme.GOExerciseTheme
import com.goexercise.app.ui.theme.LocalAppPalette

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
    val pendingRankEvent by viewModel.pendingRankEvent.collectAsStateWithLifecycle()
    val reviveState by viewModel.reviveState.collectAsStateWithLifecycle()

    Box(modifier = Modifier.fillMaxSize()) {
        HomeContent(state = state, onRecordClick = onRecordClick, onShareClick = onShareClick)
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

/** 達成お祝いダイアログ(emoji + 見出し + 詳細 + シェア + 閉じる)。iOS MilestoneCelebrationSheet 相当。 */
@Composable
private fun MilestoneCelebrationDialog(milestone: Milestone, onDismiss: () -> Unit) {
    val palette = LocalAppPalette.current
    val context = LocalContext.current
    AlertDialog(
        onDismissRequest = onDismiss,
        icon = { Text(milestone.emoji, fontSize = 48.sp) },
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

/** ステートレスなホーム本体(プレビュー/テストしやすいよう状態を引数で受ける)。 */
@Composable
fun HomeContent(
    state: HomeUiState,
    onRecordClick: () -> Unit = {},
    onShareClick: () -> Unit = {},
) {
    val palette = LocalAppPalette.current
    Box(modifier = Modifier.fillMaxSize()) {
        // 連続ランク駆動の進化背景(最背面)。背景は backdrop が描くので Column 側の
        // .background(palette.background) は外す(付けると backdrop を覆って見えなくなる)。
        com.goexercise.app.ui.components.MilestoneBackdrop(streak = state.streak.currentStreak)
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            CatTheater(state)
            WeekStrip(state.weekStatuses)
            StatsRow(state)
            Button(
                onClick = onRecordClick,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text("記録する")
            }
            // 連続記録がある時だけシェア導線を出す(マイルストーン画像)。
            if (state.streak.currentStreak > 0) {
                TextButton(
                    onClick = onShareClick,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text("🔥 ${state.streak.currentStreak}日連続をシェア", color = palette.primaryDeep)
                }
            }
        }
    }
}

@Composable
private fun CatTheater(state: HomeUiState) {
    val palette = LocalAppPalette.current
    Row(verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        // 猫劇場: ユーザーの猫種 × 今の状態(77 画像)。
        com.goexercise.app.ui.components.CatImage(
            breed = state.catBreed,
            state = state.catState,
            modifier = Modifier.size(96.dp),
            // 今日まだ未記録なら補給(シェイカー)版で「これからやろう」を演出。iOS: !todayStatus.countsAsAchieved。
            useShaker = !state.todayStatus.countsAsAchieved,
        )
        Surface(
            color = palette.surface,
            shape = RoundedCornerShape(20.dp),
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text(
                text = state.catMessage.text,
                color = palette.textPrimary,
                modifier = Modifier.padding(16.dp),
            )
        }
    }
}

@Composable
private fun WeekStrip(week: List<DailyStatusEntry>) {
    val palette = LocalAppPalette.current
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        week.forEach { entry ->
            Column(
                modifier = Modifier.weight(1f),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Text(text = "${entry.date.dayOfMonth}", color = palette.textSecondary, fontSize = 11.sp)
                Box(
                    modifier = Modifier
                        .size(32.dp)
                        .clip(CircleShape)
                        .background(com.goexercise.app.ui.theme.colorForStatus(entry.status)),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(text = entry.status.symbol, fontSize = 14.sp)
                }
            }
        }
    }
}

@Composable
private fun StatsRow(state: HomeUiState) {
    val palette = LocalAppPalette.current
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
        StatPill(label = "連続", value = "${state.streak.currentStreak}日", modifier = Modifier.weight(1f))
        StatPill(label = "累計達成", value = "${state.lifetimeStats.achievedDays}日", modifier = Modifier.weight(1f))
        StatPill(label = "今週", value = "${state.weeklySummary.totalMinutes}分", modifier = Modifier.weight(1f))
        RankPill(streak = state.streak.currentStreak, modifier = Modifier.weight(1f))
    }
}

/** 称号(連続ベースのメタルチップ)を表示する StatPill。rank0 は「—」で見栄えを保つ。 */
@Composable
private fun RankPill(streak: Int, modifier: Modifier = Modifier) {
    val palette = LocalAppPalette.current
    val rank = com.goexercise.app.domain.CatRank.of(streak)
    Surface(color = palette.chipBackground, shape = RoundedCornerShape(14.dp), modifier = modifier) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 12.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            if (rank.rank > 0) {
                com.goexercise.app.ui.components.CatRankChip(rank = rank, compact = true)
            } else {
                Text(text = "—", color = palette.textPrimary, fontWeight = FontWeight.Bold)
            }
            Text(text = "称号", color = palette.textSecondary, fontSize = 11.sp, textAlign = TextAlign.Center)
        }
    }
}

@Composable
private fun StatPill(label: String, value: String, modifier: Modifier = Modifier) {
    val palette = LocalAppPalette.current
    Surface(color = palette.chipBackground, shape = RoundedCornerShape(14.dp), modifier = modifier) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 12.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(text = value, color = palette.textPrimary, fontWeight = FontWeight.Bold)
            Text(text = label, color = palette.textSecondary, fontSize = 11.sp, textAlign = TextAlign.Center)
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
