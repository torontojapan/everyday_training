package com.goexercise.app.presentation.history

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.EventAvailable
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.TouchApp
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.goexercise.app.data.settings.MenstrualRepository
import com.goexercise.app.ui.theme.AppType
import com.goexercise.app.ui.theme.LocalAppPalette
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.YearMonth
import javax.inject.Inject

/** 生理日まとめ入力画面の VM。`MenstrualRepository` の periodDays を購読し、過去・当日のトグルを行う。 */
@HiltViewModel
class MenstrualEntryViewModel @Inject constructor(
    private val menstrual: MenstrualRepository,
) : ViewModel() {
    val periodDays: StateFlow<Set<LocalDate>> =
        menstrual.periodDays.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptySet())

    fun toggle(date: LocalDate) {
        viewModelScope.launch { menstrual.toggle(date) }
    }
}

@Composable
fun MenstrualEntryRoute(
    onBack: () -> Unit = {},
    viewModel: MenstrualEntryViewModel = hiltViewModel(),
) {
    val periodDays by viewModel.periodDays.collectAsStateWithLifecycle()
    MenstrualEntryScreen(periodDays = periodDays, onToggle = viewModel::toggle, onBack = onBack)
}

/** 生理日マークの基準色(履歴カレンダーの ★ と揃える。iOS markColor RGB(0.86,0.36,0.45))。 */
private val MarkColor = Color(0.86f, 0.36f, 0.45f)
private val Weekdays = listOf("月", "火", "水", "木", "金", "土", "日")

/**
 * 過去・当日の生理日を後付けで一括記録する専用カレンダー。iOS `MenstrualEntryView` の移植。
 * 設定で「体調・周期を記録する」ON のときだけ履歴タブからリンクされる。トグルは履歴カレンダーの
 * ★ にも即時反映される(同一 MenstrualRepository を購読)。
 */
@Composable
fun MenstrualEntryScreen(
    periodDays: Set<LocalDate>,
    onToggle: (LocalDate) -> Unit = {},
    onBack: () -> Unit = {},
) {
    val palette = LocalAppPalette.current
    val today = remember { LocalDate.now() }
    var currentMonth by remember { mutableStateOf(YearMonth.from(today)) }
    val canGoNext = currentMonth.isBefore(YearMonth.from(today))

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(palette.background)
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        // iOS navigationTitle "生理日"(inline)= 中央タイトル + 左の円形戻る(surface 円 + textPrimary chevron。設定 SubPage と統一)。
        Box(Modifier.fillMaxWidth()) {
            Box(
                modifier = Modifier.align(Alignment.CenterStart).size(36.dp).clip(CircleShape).background(palette.surface).clickable(onClick = onBack),
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.Filled.ChevronLeft, contentDescription = "戻る", tint = palette.textPrimary, modifier = Modifier.size(22.dp))
            }
            Text("生理日", color = palette.textPrimary, modifier = Modifier.align(Alignment.Center), style = AppType.body.copy(fontWeight = FontWeight.SemiBold))
        }

        // カレンダーカード(月ナビ + 曜日 + グリッド + 当月の記録数)。
        Surface(color = palette.surface, shape = RoundedCornerShape(22.dp), modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                // ヘッダ: 前月/翌月(翌月は当月以降に進めない)+ 中央 yyyy年M月。
                Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                    MonthChip(Icons.Filled.ChevronLeft, "前の月", enabled = true) { currentMonth = currentMonth.minusMonths(1) }
                    Text(
                        "${currentMonth.year}年${currentMonth.monthValue}月",
                        style = AppType.headline,
                        color = palette.textPrimary,
                        modifier = Modifier.weight(1f),
                        textAlign = TextAlign.Center,
                    )
                    MonthChip(Icons.Filled.ChevronRight, "次の月", enabled = canGoNext) { if (canGoNext) currentMonth = currentMonth.plusMonths(1) }
                }
                // 曜日行。
                Row(Modifier.fillMaxWidth()) {
                    Weekdays.forEach { day ->
                        Text(day, style = AppType.caption, color = palette.textSecondary, textAlign = TextAlign.Center, modifier = Modifier.weight(1f))
                    }
                }
                // グリッド(月曜始まり・先頭に空白セル)。
                val cells = remember(currentMonth) { monthCells(currentMonth) }
                cells.chunked(7).forEach { week ->
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        week.forEach { date ->
                            if (date == null) {
                                Box(Modifier.weight(1f).height(44.dp))
                            } else {
                                DayMarkCell(
                                    date = date,
                                    isMarked = date in periodDays,
                                    isToday = date == today,
                                    isFuture = date.isAfter(today),
                                    modifier = Modifier.weight(1f),
                                    onClick = { if (!date.isAfter(today)) onToggle(date) },
                                )
                            }
                        }
                        repeat(7 - week.size) { Box(Modifier.weight(1f)) }
                    }
                }
                // 当月の記録数。
                val markedInMonth = cells.count { it != null && it in periodDays }
                Text("${currentMonth.monthValue}月の記録: $markedInMonth 日", style = AppType.caption, color = palette.textSecondary)
            }
        }

        // 説明カード(操作ヒント 3 点)。iOS explainer(chipBackground@0.6, r14)。
        Surface(color = palette.chipBackground.copy(alpha = 0.6f), shape = RoundedCornerShape(14.dp), modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                ExplainerRow(Icons.Filled.TouchApp, "日付をタップで★トグル")
                ExplainerRow(Icons.Filled.EventAvailable, "入力した日は履歴カレンダーにも★で表示されます")
                ExplainerRow(Icons.Filled.Lock, "未来の日付は選択できません")
            }
        }
    }
}

/** 月ナビの丸ボタン(chipBackground 円・primaryDeep アイコン)。無効時は淡色。iOS header chevron。 */
@Composable
private fun MonthChip(icon: ImageVector, desc: String, enabled: Boolean, onClick: () -> Unit) {
    val palette = LocalAppPalette.current
    Box(
        modifier = Modifier
            .size(44.dp)
            .clickable(enabled = enabled, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Box(Modifier.size(36.dp).clip(CircleShape).background(palette.chipBackground), contentAlignment = Alignment.Center) {
            Icon(
                icon, contentDescription = desc,
                tint = if (enabled) palette.primaryDeep else palette.textSecondary.copy(alpha = 0.4f),
                modifier = Modifier.size(18.dp),
            )
        }
    }
}

/** 日セル: 日付 + ★(マーク時)。マーク時は塗り+枠、当日は薄塗り、未来は淡色・非活性。iOS cellView。 */
@Composable
private fun DayMarkCell(
    date: LocalDate,
    isMarked: Boolean,
    isToday: Boolean,
    isFuture: Boolean,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    val palette = LocalAppPalette.current
    val bg = when {
        isMarked -> MarkColor.copy(alpha = 0.18f)
        isToday -> palette.primary.copy(alpha = 0.18f)
        else -> palette.surface
    }
    val textColor = when {
        isFuture -> palette.textSecondary.copy(alpha = 0.5f)
        isMarked -> MarkColor
        else -> palette.textPrimary
    }
    Box(
        modifier = modifier
            .height(44.dp)
            .clip(RoundedCornerShape(9.dp))
            .background(bg)
            .then(
                if (isMarked) Modifier.border(1.5.dp, MarkColor, RoundedCornerShape(9.dp)) else Modifier,
            )
            .clickable(
                enabled = !isFuture,
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = onClick,
            ),
        contentAlignment = Alignment.Center,
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                "${date.dayOfMonth}",
                style = androidx.compose.ui.text.TextStyle(fontFeatureSettings = "tnum"), // iOS monospacedDigit
                fontSize = 14.sp,  // parity-allow: Android カードセクション/チップ見出し適応(iOS Form header/chip 相当・density393照合済)
                fontWeight = if (isMarked || isToday) FontWeight.ExtraBold else FontWeight.SemiBold,
                color = textColor,
            )
            if (isMarked) {
                Text("★", color = MarkColor, style = AppType.caption2.copy(fontWeight = FontWeight.ExtraBold))
            }
        }
    }
}

@Composable
private fun ExplainerRow(icon: ImageVector, text: String) {
    val palette = LocalAppPalette.current
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Icon(icon, contentDescription = null, tint = palette.textSecondary, modifier = Modifier.size(16.dp))
        Text(text, style = AppType.caption, color = palette.textSecondary)
    }
}

/** 月曜始まりの月セル(先頭に null=空白を詰める)。iOS cells。 */
private fun monthCells(month: YearMonth): List<LocalDate?> {
    val first = month.atDay(1)
    val leading = first.dayOfWeek.value - 1 // Mon=1 → 0, Sun=7 → 6
    val cells = ArrayList<LocalDate?>(leading + month.lengthOfMonth())
    repeat(leading) { cells.add(null) }
    for (d in 1..month.lengthOfMonth()) cells.add(month.atDay(d))
    while (cells.size % 7 != 0) cells.add(null)
    return cells
}
