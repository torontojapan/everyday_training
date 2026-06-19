package com.goexercise.app.presentation.weight

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.goexercise.app.data.WeightRepository
import com.goexercise.app.data.billing.PremiumRepository
import com.goexercise.app.data.settings.HealthPrefs
import com.goexercise.app.data.settings.HealthRepository
import com.goexercise.app.data.settings.MenstrualRepository
import com.goexercise.app.data.settings.SettingsRepository
import com.goexercise.app.domain.CatBreed
import com.goexercise.app.domain.ChartPeriod
import com.goexercise.app.domain.CyclePhaseResolver
import com.goexercise.app.domain.WeightAnalytics
import com.goexercise.app.domain.WeightEntry
import com.goexercise.app.domain.WeightStats
import com.goexercise.app.domain.WeightTrendPoint
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.Clock
import java.time.LocalDate
import java.time.LocalDateTime
import javax.inject.Inject

/** 体重タブの UI 状態。プレミアム gate・最新・統計・チャート(日次+トレンド+周期帯)・予測・BMI。 */
data class WeightUiState(
    val isPremium: Boolean = false,
    val isTrialEligible: Boolean = false,
    val entries: List<WeightEntry> = emptyList(),
    val period: ChartPeriod = ChartPeriod.Month,
    /** 古→新の日次最新(チャート描画用)。 */
    val dailyChart: List<WeightEntry> = emptyList(),
    val trend: List<WeightTrendPoint> = emptyList(),
    val cycleSpans: List<CyclePhaseResolver.PhaseSpan> = emptyList(),
    val showCycleOverlay: Boolean = true,
    val periodDays: Set<LocalDate> = emptySet(),
    val weekStats: WeightStats? = null,
    val monthStats: WeightStats? = null,
    val health: HealthPrefs = HealthPrefs(),
    val latest: WeightEntry? = null,
    val forecastDays: Int? = null,
    val bmi: Double? = null,
    /** 選択中の猫種(HeroCard 達成リング中央。iOS WeightHeroDashboard の cachedCatAssetName 相当)。 */
    val breed: CatBreed = CatBreed.Default,
    /** 開始→目標の達成率(0..1)。nil=目標/開始未設定。iOS WeightView の progress(ringWithCat 用)。 */
    val progress: Double? = null,
) {
    /** 目標まで残り kg(目標設定時)。負号は UI 側で扱う。 */
    val remainingToTarget: Double? get() = health.targetKg?.let { t -> latest?.let { t - it.weightKg } }
}

private data class WeightToggles(val period: ChartPeriod = ChartPeriod.Month, val showCycle: Boolean = true)

@HiltViewModel
class WeightViewModel @Inject constructor(
    private val weightRepo: WeightRepository,
    private val health: HealthRepository,
    private val menstrual: MenstrualRepository,
    private val settings: SettingsRepository,
    premium: PremiumRepository,
    private val clock: Clock,
) : ViewModel() {

    private val toggles = MutableStateFlow(WeightToggles())

    val uiState: StateFlow<WeightUiState> =
        combine(
            // 加入状態 + トライアル適格 + 猫種を 1 入力にまとめる(combine の 5 引数上限に収める)。
            combine(premium.isPremiumActive, premium.isTrialEligible, settings.catBreed) { p, t, b -> Triple(p, t, b) },
            weightRepo.observeEntries(),
            health.prefs,
            menstrual.periodDays,
            toggles,
        ) { premiumState, entries, healthPrefs, periodDays, tg ->
            val (isPremium, trialEligible, breed) = premiumState
            val today = LocalDate.now(clock)
            val dailyDesc = WeightAnalytics.dailyLatest(entries, tg.period, today) // 新→古
            val dailyChart = dailyDesc.reversed() // 古→新
            val trend = WeightAnalytics.trendline(entries, tg.period, today)
            val latest = WeightAnalytics.dailyLatest(entries, ChartPeriod.All, today).firstOrNull()
            val spans = if (tg.showCycle && isPremium && periodDays.isNotEmpty() && dailyChart.isNotEmpty()) {
                CyclePhaseResolver.spans(dailyChart.first().date, today.plusDays(1), periodDays)
            } else {
                emptyList()
            }
            WeightUiState(
                isPremium = isPremium,
                isTrialEligible = trialEligible,
                entries = entries,
                period = tg.period,
                dailyChart = dailyChart,
                trend = trend,
                cycleSpans = spans,
                showCycleOverlay = tg.showCycle,
                periodDays = periodDays,
                weekStats = WeightAnalytics.stats(entries, ChartPeriod.Week, today),
                monthStats = WeightAnalytics.stats(entries, ChartPeriod.Month, today),
                health = healthPrefs,
                latest = latest,
                forecastDays = WeightAnalytics.forecastDaysToTarget(entries, healthPrefs.targetKg, today),
                bmi = WeightAnalytics.bmi(latest?.weightKg, healthPrefs.heightCm),
                breed = breed,
                progress = latest?.let { healthPrefs.progressRatio(it.weightKg) },
            )
        }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), WeightUiState())

    fun setPeriod(period: ChartPeriod) = toggles.update { it.copy(period = period) }
    fun toggleCycleOverlay() = toggles.update { it.copy(showCycle = !it.showCycle) }

    /** 体重記録を追加。最初の記録なら開始時体重も自動キャプチャ(iOS captureStartWeightIfNeeded)。 */
    fun addWeight(date: LocalDate, weightKg: Double, memo: String?) {
        viewModelScope.launch {
            val now = LocalDateTime.now(clock)
            // 過去日は その日の現在時刻(時系列の日内最新が成立するよう)。今日は now。
            val recordedAt = if (date == now.toLocalDate()) now else date.atTime(now.toLocalTime())
            weightRepo.add(recordedAt, weightKg, memo)
            health.setStartKgIfAbsent(weightKg)
        }
    }

    fun deleteEntry(id: String) = viewModelScope.launch { weightRepo.delete(id) }
    fun setTargetKg(kg: Double?) = viewModelScope.launch { health.setTargetKg(kg) }
    fun setHeightCm(cm: Double?) = viewModelScope.launch { health.setHeightCm(cm) }
    fun setIsLossGoal(isLoss: Boolean) = viewModelScope.launch { health.setIsLossGoal(isLoss) }
    fun togglePeriodDay(date: LocalDate) = viewModelScope.launch { menstrual.toggle(date) }
}
