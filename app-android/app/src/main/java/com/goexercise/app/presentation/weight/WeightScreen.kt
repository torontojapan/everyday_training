@file:OptIn(ExperimentalLayoutApi::class)

package com.goexercise.app.presentation.weight

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.ui.draw.clip
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.FormatListBulleted
import androidx.compose.material.icons.filled.AddCircle
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.ExpandLess
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material.icons.filled.ShowChart
import androidx.compose.material.icons.filled.WorkspacePremium
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SelectableDates
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.goexercise.app.domain.ChartPeriod
import com.goexercise.app.domain.WeightStats
import com.goexercise.app.domain.CatBreed
import com.goexercise.app.domain.CatState
import com.goexercise.app.ui.components.CatImage
import com.goexercise.app.ui.theme.AppTheme
import com.goexercise.app.ui.theme.LocalAppPalette
import java.time.LocalDate
import kotlin.math.abs

@Composable
fun WeightRoute(onOpenPremium: () -> Unit = {}, viewModel: WeightViewModel = hiltViewModel()) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val palette = LocalAppPalette.current
    Box(Modifier.fillMaxSize().background(palette.background)) {
        WeightContent(
            state = state,
            onAdd = viewModel::addWeight,
            onDelete = viewModel::deleteEntry,
            onSetPeriod = viewModel::setPeriod,
            onSetTarget = viewModel::setTargetKg,
            onSetHeight = viewModel::setHeightCm,
            onToggleCycle = viewModel::toggleCycleOverlay,
            onTogglePeriodDay = viewModel::togglePeriodDay,
            // 未加入時は中身をぼかして操作不可にする(iOS WeightTabRootView)。
            blurred = !state.isPremium,
        )
        if (!state.isPremium) {
            LockedOverlay(palette, state.isTrialEligible, onOpenPremium)
        }
    }
}

@Composable
private fun WeightContent(
    state: WeightUiState,
    onAdd: (LocalDate, Double, String?) -> Unit,
    onDelete: (String) -> Unit,
    onSetPeriod: (ChartPeriod) -> Unit,
    onSetTarget: (Double?) -> Unit,
    onSetHeight: (Double?) -> Unit,
    onToggleCycle: () -> Unit,
    onTogglePeriodDay: (LocalDate) -> Unit,
    blurred: Boolean,
) {
    val palette = LocalAppPalette.current
    Column(
        modifier = Modifier
            .fillMaxSize()
            .then(if (blurred) Modifier.blur(8.dp) else Modifier)
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text("体重", fontSize = 22.sp, fontWeight = FontWeight.Bold, color = palette.textPrimary)
        HeroCard(state, palette, onSetTarget)
        BmiStrip(state, palette, onSetHeight)
        // iOS WeightView: HeroCard/BMI の下は CollapsibleSection(既定折りたたみ)で
        // 記録する → レポート → 推移 → 履歴 の順。各セクションの subtitle を折りたたみ中に出す。
        WeightCollapsible("記録する", "新しい体重を追加", Icons.Filled.AddCircle, palette) {
            EntryBody(palette, onAdd)
        }
        if (state.weekStats != null || state.monthStats != null) {
            WeightCollapsible("レポート", reportSubtitle(state), Icons.Filled.BarChart, palette) {
                ReportBody(state, palette)
            }
        }
        if (state.dailyChart.size >= 2) {
            WeightCollapsible("推移", chartSubtitle(state), Icons.Filled.ShowChart, palette) {
                ChartBody(state, palette, onSetPeriod, onToggleCycle)
            }
        }
        // 生理日トラッキングはオプトイン(設定で ON)時のみ表示。既定 OFF=プライバシー優先。iOS パリティ。
        if (state.health.cycleTrackingEnabled) CyclePanel(state, palette, onTogglePeriodDay)
        if (state.entries.isNotEmpty()) {
            WeightCollapsible("履歴", historySubtitle(state), Icons.AutoMirrored.Filled.FormatListBulleted, palette) {
                HistoryBody(state, palette, onDelete)
            }
        }
    }
}

/** iOS CollapsibleSection 相当: カード + ヘッダ(アイコン+題+折りたたみ中 subtitle+シェブロン)。既定折りたたみ。 */
@Composable
private fun WeightCollapsible(
    title: String,
    subtitle: String,
    icon: ImageVector,
    palette: AppTheme,
    content: @Composable ColumnScope.() -> Unit,
) {
    var expanded by rememberSaveable(title) { mutableStateOf(false) }
    Surface(color = palette.surface, shape = RoundedCornerShape(18.dp), modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth().clickable { expanded = !expanded },
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Icon(icon, contentDescription = null, tint = palette.primaryDeep, modifier = Modifier.size(20.dp))
                Column(Modifier.weight(1f)) {
                    Text(title, fontSize = 15.sp, fontWeight = FontWeight.Bold, color = palette.textPrimary)
                    // iOS: 展開時は本文と二重になるので subtitle を隠す。
                    if (!expanded && subtitle.isNotEmpty()) {
                        Text(subtitle, fontSize = 12.sp, color = palette.textSecondary)
                    }
                }
                Icon(if (expanded) Icons.Filled.ExpandLess else Icons.Filled.ExpandMore, contentDescription = null, tint = palette.textSecondary)
            }
            if (expanded) content()
        }
    }
}

private fun reportSubtitle(s: WeightUiState): String {
    val st = s.weekStats ?: s.monthStats ?: return ""
    val label = if (s.weekStats != null) "今週" else "今月"
    return "%s %+.1fkg / 平均 %.1fkg".format(label, st.change, st.average)
}

private fun chartSubtitle(s: WeightUiState): String =
    if (s.dailyChart.isNotEmpty()) "30 日で ${s.dailyChart.size} 件記録" else "記録がありません"

private fun historySubtitle(s: WeightUiState): String =
    if (s.entries.isNotEmpty()) "全 ${s.entries.size} 件" else "履歴なし"

@Composable
private fun LockedOverlay(palette: AppTheme, trialEligible: Boolean, onOpenPremium: () -> Unit) {
    // 全画面で**タップを消費**し、ぼかした下層フォームへ非加入ユーザーが触れて
    // 体重/目標/生理日を変更できないようにする(iOS .disabled(!isUnlocked) 相当)。
    Box(
        Modifier
            .fillMaxSize()
            .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) {}
            .padding(28.dp),
        contentAlignment = Alignment.Center,
    ) {
        Surface(color = palette.surface, shape = RoundedCornerShape(24.dp)) {
            Column(
                Modifier.padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                // iOS lockedOverlay: crown.fill(コーラル単色)。crown ベクター(ic_crown)で字形一致。
                Icon(
                    painter = androidx.compose.ui.res.painterResource(com.goexercise.app.R.drawable.ic_crown),
                    contentDescription = null, tint = palette.primary, modifier = Modifier.size(44.dp),
                )
                Text("体重タブは GOプレミアム機能です", fontSize = 16.sp, fontWeight = FontWeight.Bold, color = palette.textPrimary, textAlign = TextAlign.Center)
                Text(
                    // トライアル消化済みは「14日間無料」を出さない(誤表示=審査リスク。Codex R4)。
                    if (trialEligible) "14日間無料でお試しいただけます。推移グラフ・BMI・レポート・周期オーバーレイなどを解放。"
                    else "推移グラフ・BMI・レポート・周期オーバーレイなどを解放。",
                    fontSize = 12.sp, color = palette.textSecondary, textAlign = TextAlign.Center,
                )
                Button(
                    onClick = onOpenPremium,
                    colors = ButtonDefaults.buttonColors(containerColor = palette.primary),
                    shape = RoundedCornerShape(50), // iOS Capsule。
                ) {
                    Text("GOプレミアムを見る", color = Color.White, fontWeight = FontWeight.SemiBold)
                }
                // iOS フッター: ホーム「記録する」からの体重入力は無料(無料導線を明示)。
                Text(
                    "ホーム画面の「記録する」からの体重入力は\n引き続き無料でご利用いただけます",
                    fontSize = 11.sp, color = palette.textSecondary, textAlign = TextAlign.Center,
                )
            }
        }
    }
}

@Composable
private fun HeroCard(state: WeightUiState, palette: AppTheme, onSetTarget: (Double?) -> Unit) {
    var showTargetDialog by remember { mutableStateOf(false) }
    Surface(color = palette.surface, shape = RoundedCornerShape(20.dp), modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            // iOS WeightHeroDashboard 上段ヘッダ「最新の体重 · {日付}」。
            val header = state.latest?.let {
                "最新の体重 · " + it.recordedAt.format(java.time.format.DateTimeFormatter.ofPattern("yyyy/M/d HH:mm"))
            } ?: "最新の体重"
            Text(header, fontSize = 12.sp, color = palette.textSecondary)
            // iOS 中段: 巨大な現在体重(左)+ 達成リング+猫(右)。
            Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.Top) {
                Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Row(verticalAlignment = Alignment.Bottom) {
                        Text(
                            state.latest?.let { "%.1f".format(it.weightKg) } ?: "—",
                            fontSize = 44.sp, fontWeight = FontWeight.Black, color = palette.primaryDeep,
                        )
                        Text(" kg", fontSize = 18.sp, color = palette.textSecondary, modifier = Modifier.padding(bottom = 6.dp))
                    }
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        state.remainingToTarget?.let { rem ->
                            val within = abs(rem) < 0.05
                            Chip(if (within) "✓ 目標圏内" else "📏 あと %.1fkg".format(abs(rem)), if (within) palette.success else palette.primaryDeep, palette)
                        }
                        state.weekStats?.change?.let { ch ->
                            Chip("${if (ch <= 0) "↘" else "↗"} 今週 %+.1fkg".format(ch), if (ch <= 0) palette.success else palette.primaryDeep, palette)
                        }
                        state.forecastDays?.let { d ->
                            Chip(if (d == 0) "🎯 目標達成" else "⏳ あと約${d}日", palette.settingsAccent, palette)
                        }
                    }
                }
                // iOS ringWithCat(達成リング+中央猫+%バッジ)。目標/開始未設定(progress=null)でも空リング+猫は出す。
                WeightAchievementRing(progress = state.progress, breed = state.breed, palette = palette)
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                state.health.startKg?.let { Text("開始 %.1f →".format(it), fontSize = 12.sp, color = palette.textSecondary) }
                Spacer(Modifier.width(6.dp))
                Text(state.health.targetKg?.let { "目標 %.1f kg".format(it) } ?: "目標未設定", fontSize = 13.sp, fontWeight = FontWeight.Bold, color = palette.primaryDeep)
                Spacer(Modifier.weight(1f))
                TextButton(onClick = { showTargetDialog = true }) { Text(if (state.health.targetKg == null) "目標を設定" else "変更", color = palette.primaryDeep, fontSize = 12.sp) }
            }
        }
    }
    if (showTargetDialog) {
        NumberDialog("目標体重 (kg)", state.health.targetKg, palette, onDismiss = { showTargetDialog = false }) {
            onSetTarget(it); showTargetDialog = false
        }
    }
}

/**
 * iOS `WeightHeroDashboard.ringWithCat` 移植: 達成リング(円弧進捗)+ 中央に選択猫 + 右下%バッジ。
 * 仕様: ring 108 / line 9 / 背景リング primary@0.18 / 進捗 primary round-cap -90°開始 /
 *       中央 surface円(84)+猫(82, clipCircle) / バッジ "{N}%" white on primaryDeep capsule offset(30,38)+白枠2。
 */
@Composable
private fun WeightAchievementRing(progress: Double?, breed: CatBreed, palette: AppTheme) {
    val ring = 108.dp
    val line = 9.dp
    Box(modifier = Modifier.size(ring + 12.dp), contentAlignment = Alignment.Center) {
        Canvas(modifier = Modifier.size(ring)) {
            val sw = line.toPx()
            val d = size.minDimension - sw
            val tl = androidx.compose.ui.geometry.Offset(sw / 2, sw / 2)
            val sz = androidx.compose.ui.geometry.Size(d, d)
            drawArc(color = palette.primary.copy(alpha = 0.18f), startAngle = 0f, sweepAngle = 360f, useCenter = false,
                topLeft = tl, size = sz, style = Stroke(width = sw))
            progress?.let { p ->
                drawArc(color = palette.primary, startAngle = -90f, sweepAngle = (p.coerceIn(0.0, 1.0) * 360).toFloat(),
                    useCenter = false, topLeft = tl, size = sz, style = Stroke(width = sw, cap = androidx.compose.ui.graphics.StrokeCap.Round))
            }
        }
        // 中央 surface 円 + 猫。
        Box(modifier = Modifier.size(ring - 24.dp).clip(CircleShape).background(palette.surface), contentAlignment = Alignment.Center) {
            CatImage(breed = breed, state = CatState.Celebrating, modifier = Modifier.size(ring - 26.dp).clip(CircleShape))
        }
        // 進捗バッジ(右下)。
        progress?.let { p ->
            Box(
                modifier = Modifier.align(Alignment.BottomEnd).offset(x = (-2).dp, y = (-2).dp)
                    .clip(CircleShape).background(palette.primaryDeep)
                    .border(2.dp, palette.surface, CircleShape).padding(horizontal = 8.dp, vertical = 3.dp),
            ) {
                Text("${(p.coerceIn(0.0, 1.0) * 100).toInt()}%", color = Color.White, fontSize = 11.sp, fontWeight = FontWeight.Black)
            }
        }
    }
}

@Composable
private fun BmiStrip(state: WeightUiState, palette: AppTheme, onSetHeight: (Double?) -> Unit) {
    var showHeightDialog by remember { mutableStateOf(false) }
    Surface(color = palette.chipBackground, shape = RoundedCornerShape(50), modifier = Modifier.fillMaxWidth()) {
        Row(Modifier.padding(horizontal = 14.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            Text("📏 ", fontSize = 13.sp)
            if (state.bmi != null) {
                Text("BMI %.1f".format(state.bmi), fontSize = 13.sp, fontWeight = FontWeight.Bold, color = palette.primaryDeep)
                state.health.heightCm?.let { Text("  身長 ${it.toInt()}cm", fontSize = 12.sp, color = palette.textSecondary) }
            } else {
                Text("身長を設定すると BMI が表示されます", fontSize = 12.sp, color = palette.textSecondary)
            }
            Spacer(Modifier.weight(1f))
            TextButton(onClick = { showHeightDialog = true }) { Text("編集", color = palette.primaryDeep, fontSize = 12.sp) }
        }
    }
    if (showHeightDialog) {
        NumberDialog("身長 (cm)", state.health.heightCm, palette, onDismiss = { showHeightDialog = false }) {
            onSetHeight(it); showHeightDialog = false
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun EntryBody(palette: AppTheme, onAdd: (LocalDate, Double, String?) -> Unit) {
    var weight by remember { mutableStateOf("") }
    var memo by remember { mutableStateOf("") }
    var mode by remember { mutableStateOf(0) } // 0=今日, 1=昨日, 2=その他(任意過去日)
    var customDate by remember { mutableStateOf(LocalDate.now().minusDays(2)) }
    var showPicker by remember { mutableStateOf(false) }
    // 保存日は**保存タップ時**に算出(日跨ぎで画面を開いたまま「今日」が前日になる回帰を防ぐ。Codex 指摘)。
    fun effectiveDate(): LocalDate = when (mode) { 0 -> LocalDate.now(); 1 -> LocalDate.now().minusDays(1); else -> customDate }

    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf("今日", "昨日", "その他").forEachIndexed { i, label ->
                    val sel = mode == i
                    Surface(
                        color = if (sel) palette.primary else palette.chipBackground,
                        shape = RoundedCornerShape(50),
                        modifier = Modifier.clickable { if (i == 2) showPicker = true else mode = i },
                    ) {
                        Text(label, fontSize = 12.sp, fontWeight = FontWeight.Bold, color = if (sel) Color.White else palette.textPrimary, modifier = Modifier.padding(horizontal = 14.dp, vertical = 6.dp))
                    }
                }
            }
            // 「その他」選択時は対象日を明示(任意過去日入力。iOS dateSegment パリティ)。
            if (mode == 2) {
                Text("対象日: ${customDate}", fontSize = 12.sp, color = palette.textSecondary)
            }
            OutlinedTextField(
                value = weight, onValueChange = { weight = it.filter { c -> c.isDigit() || c == '.' } },
                label = { Text("体重 (kg)") }, singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(value = memo, onValueChange = { memo = it }, label = { Text("メモ (任意)") }, singleLine = true, modifier = Modifier.fillMaxWidth())
            Button(
                onClick = {
                    weight.toDoubleOrNull()?.let { onAdd(effectiveDate(), it, memo.ifBlank { null }); weight = ""; memo = "" }
                },
                enabled = weight.toDoubleOrNull() != null,
                colors = ButtonDefaults.buttonColors(containerColor = palette.primary),
                modifier = Modifier.fillMaxWidth(),
            ) { Text("✓ 保存", color = Color.White) }
    }

    if (showPicker) {
        val todayMillis = LocalDate.now().atStartOfDay(java.time.ZoneOffset.UTC).toInstant().toEpochMilli()
        val dpState = rememberDatePickerState(
            initialSelectedDateMillis = customDate.atStartOfDay(java.time.ZoneOffset.UTC).toInstant().toEpochMilli(),
            selectableDates = object : SelectableDates {
                override fun isSelectableDate(utcTimeMillis: Long) = utcTimeMillis <= todayMillis // 未来日は不可
            },
        )
        DatePickerDialog(
            onDismissRequest = { showPicker = false },
            confirmButton = {
                TextButton(onClick = {
                    dpState.selectedDateMillis?.let {
                        customDate = java.time.Instant.ofEpochMilli(it).atZone(java.time.ZoneOffset.UTC).toLocalDate()
                        mode = 2
                    }
                    showPicker = false
                }) { Text("決定") }
            },
            dismissButton = { TextButton(onClick = { showPicker = false }) { Text("キャンセル") } },
        ) { DatePicker(state = dpState) }
    }
}

@Composable
private fun ChartBody(state: WeightUiState, palette: AppTheme, onSetPeriod: (ChartPeriod) -> Unit, onToggleCycle: () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        // 期間チップ(iOS は推移セクション内の期間ピッカー。題はコラプシブルのヘッダへ移動)。
        Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            ChartPeriod.entries.forEach { p ->
                val sel = p == state.period
                Surface(color = if (sel) palette.primary else palette.chipBackground, shape = RoundedCornerShape(50), modifier = Modifier.clickable { onSetPeriod(p) }) {
                    Text(p.shortLabel, fontSize = 11.sp, color = if (sel) Color.White else palette.textPrimary, modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp))
                }
            }
        }
        WeightChart(state, palette, Modifier.fillMaxWidth().height(200.dp))
        if (state.periodDays.isNotEmpty()) {
            Text(
                if (state.showCycleOverlay) "周期オーバーレイ: ON（タップで切替）" else "周期オーバーレイ: OFF（タップで切替）",
                fontSize = 11.sp, color = palette.textSecondary, modifier = Modifier.clickable { onToggleCycle() },
            )
        }
    }
}

@Composable
private fun WeightChart(state: WeightUiState, palette: AppTheme, modifier: Modifier) {
    val daily = state.dailyChart // 古→新
    val today = LocalDate.now()
    val xMinDay = daily.first().date.toEpochDay().toFloat()
    val xMaxDay = today.toEpochDay().toFloat()
    val xSpan = (xMaxDay - xMinDay).coerceAtLeast(1f)
    val allKg = daily.map { it.weightKg } + state.trend.map { it.average }
    val yMin = (allKg.min() - 0.5)
    val yMax = (allKg.max() + 0.5)
    val ySpan = (yMax - yMin).coerceAtLeast(0.1)
    val primary = palette.primary
    val primaryDeep = palette.primaryDeep
    // タップで最近傍の実測点を選択(再タップ解除)。iOS グラフのタップ選択パリティ。
    var selectedIndex by remember(daily) { mutableStateOf<Int?>(null) }

    Canvas(
        modifier.pointerInput(daily, xMinDay, xSpan) {
            detectTapGestures { tap ->
                val w = size.width.toFloat()
                fun pxLocal(day: Float) = (day - xMinDay) / xSpan * w
                val nearest = daily.indices.minByOrNull { i ->
                    kotlin.math.abs(pxLocal(daily[i].date.toEpochDay().toFloat()) - tap.x)
                }
                selectedIndex = if (nearest == selectedIndex) null else nearest
            }
        },
    ) {
        val w = size.width
        val h = size.height
        fun px(day: Float) = (day - xMinDay) / xSpan * w
        fun py(kg: Double) = (h - ((kg - yMin) / ySpan * h)).toFloat()

        // 周期帯(背景)
        state.cycleSpans.forEach { span ->
            val x0 = px(span.startDay.toEpochDay().toFloat()).coerceIn(0f, w)
            val x1 = px(span.endDay.toEpochDay().toFloat()).coerceIn(0f, w)
            if (x1 > x0) {
                drawRect(color = Color(span.phase.tintArgb).copy(alpha = 0.13f), topLeft = Offset(x0, 0f), size = androidx.compose.ui.geometry.Size(x1 - x0, h))
            }
        }
        // 7日移動平均トレンド(破線)
        if (state.trend.size >= 2) {
            val path = Path()
            state.trend.forEachIndexed { i, p ->
                val x = px(p.date.toEpochDay().toFloat()); val y = py(p.average)
                if (i == 0) path.moveTo(x, y) else path.lineTo(x, y)
            }
            drawPath(path, color = primaryDeep.copy(alpha = 0.45f), style = Stroke(width = 4f, pathEffect = PathEffect.dashPathEffect(floatArrayOf(12f, 9f))))
        }
        // 日次の実測ライン + 点
        val raw = Path()
        daily.forEachIndexed { i, e ->
            val x = px(e.date.toEpochDay().toFloat()); val y = py(e.weightKg)
            if (i == 0) raw.moveTo(x, y) else raw.lineTo(x, y)
        }
        drawPath(raw, color = primary, style = Stroke(width = 6f))
        daily.forEach { e ->
            drawCircle(color = primaryDeep, radius = 7f, center = Offset(px(e.date.toEpochDay().toFloat()), py(e.weightKg)))
        }
        // 選択点を強調 + 値ラベル。
        selectedIndex?.let { idx ->
            val e = daily.getOrNull(idx) ?: return@let
            val cx = px(e.date.toEpochDay().toFloat()); val cy = py(e.weightKg)
            drawCircle(color = primaryDeep, radius = 12f, center = Offset(cx, cy))
            drawCircle(color = Color.White, radius = 5f, center = Offset(cx, cy))
            drawContext.canvas.nativeCanvas.drawText(
                "${e.weightKg}kg",
                cx.coerceIn(40f, w - 40f),
                (cy - 22f).coerceAtLeast(30f),
                android.graphics.Paint().apply {
                    color = android.graphics.Color.DKGRAY
                    textSize = 30f
                    isAntiAlias = true
                    textAlign = android.graphics.Paint.Align.CENTER
                },
            )
        }
    }
}

@Composable
private fun ReportBody(state: WeightUiState, palette: AppTheme) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        state.weekStats?.let { StatsRow("今週 (7 日)", it, palette) }
        state.monthStats?.let { StatsRow("今月 (30 日)", it, palette) }
    }
}

@Composable
private fun StatsRow(label: String, s: WeightStats, palette: AppTheme) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Row {
            Text(label, fontSize = 12.sp, color = palette.textSecondary)
            Spacer(Modifier.weight(1f))
            Text("%+.1f kg".format(s.change), fontSize = 14.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Monospace, color = if (s.change <= 0) palette.success else palette.primaryDeep)
        }
        Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
            StatCell("最小", s.min, palette)
            StatCell("平均", s.average, palette)
            StatCell("最大", s.max, palette)
        }
    }
}

@Composable
private fun StatCell(title: String, value: Double, palette: AppTheme) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(title, fontSize = 10.sp, color = palette.textSecondary)
        Text("%.1f".format(value), fontSize = 14.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Monospace, color = palette.primaryDeep)
    }
}

@Composable
private fun CyclePanel(state: WeightUiState, palette: AppTheme, onTogglePeriodDay: (LocalDate) -> Unit) {
    val today = LocalDate.now()
    val isMarked = today in state.periodDays
    Surface(color = palette.surface, shape = RoundedCornerShape(18.dp), modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("月経周期オーバーレイ", fontSize = 14.sp, fontWeight = FontWeight.Bold, color = palette.textPrimary)
            Text("生理日を登録すると、グラフ背景に周期の相(月経/卵胞/排卵/黄体)が重なります。黄体期は水分で体重が増えやすい時期です。", fontSize = 11.sp, color = palette.textSecondary)
            // 凡例
            FlowRow(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                com.goexercise.app.domain.CyclePhase.entries.forEach { phase ->
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                        Box(Modifier.size(12.dp).background(Color(phase.tintArgb).copy(alpha = 0.65f), RoundedCornerShape(2.dp)))
                        Text(phase.displayName, fontSize = 11.sp, color = palette.textPrimary)
                    }
                }
            }
            Button(
                onClick = { onTogglePeriodDay(today) },
                colors = ButtonDefaults.buttonColors(containerColor = if (isMarked) palette.chipBackground else palette.primary),
            ) {
                Text(if (isMarked) "今日の生理日登録を解除" else "今日を生理日に登録", color = if (isMarked) palette.textPrimary else Color.White, fontSize = 13.sp)
            }
        }
    }
}

@Composable
private fun HistoryBody(state: WeightUiState, palette: AppTheme, onDelete: (String) -> Unit) {
    var pendingDelete by remember { mutableStateOf<String?>(null) }
    // 折りたたみカード内なので各行は素の Row(入れ子カードを避ける)。
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        state.entries.take(30).forEach { e ->
            Row(Modifier.fillMaxWidth().padding(vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text("${e.date}", fontSize = 13.sp, color = palette.textPrimary)
                    e.memo?.let { Text(it, fontSize = 11.sp, color = palette.textSecondary) }
                }
                Text("%.1f kg".format(e.weightKg), fontSize = 15.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Monospace, color = palette.primaryDeep)
                TextButton(onClick = { pendingDelete = e.id }) { Text("🗑", fontSize = 14.sp) }
            }
        }
    }
    pendingDelete?.let { id ->
        AlertDialog(
            onDismissRequest = { pendingDelete = null },
            title = { Text("削除しますか？") },
            confirmButton = { TextButton(onClick = { onDelete(id); pendingDelete = null }) { Text("削除", color = palette.primaryDeep) } },
            dismissButton = { TextButton(onClick = { pendingDelete = null }) { Text("キャンセル") } },
            containerColor = palette.surface,
        )
    }
}

@Composable
private fun Chip(text: String, fg: Color, palette: AppTheme) {
    Surface(color = fg.copy(alpha = 0.12f), shape = RoundedCornerShape(50)) {
        Text(text, fontSize = 12.sp, fontWeight = FontWeight.Bold, color = fg, modifier = Modifier.padding(horizontal = 10.dp, vertical = 5.dp))
    }
}

@Composable
private fun NumberDialog(title: String, initial: Double?, palette: AppTheme, onDismiss: () -> Unit, onConfirm: (Double?) -> Unit) {
    var text by remember { mutableStateOf(initial?.let { "%.1f".format(it) } ?: "") }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title) },
        text = {
            OutlinedTextField(
                value = text, onValueChange = { text = it.filter { c -> c.isDigit() || c == '.' } },
                singleLine = true, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
            )
        },
        confirmButton = { TextButton(onClick = { onConfirm(text.toDoubleOrNull()) }) { Text("保存", color = palette.primaryDeep) } },
        dismissButton = { TextButton(onClick = { onConfirm(null) }) { Text("クリア", color = palette.textSecondary) } },
        containerColor = palette.surface,
    )
}
