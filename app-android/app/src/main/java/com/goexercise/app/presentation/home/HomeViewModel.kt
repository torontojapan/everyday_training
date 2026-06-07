package com.goexercise.app.presentation.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.goexercise.app.data.WeightRepository
import com.goexercise.app.data.WorkoutRepository
import com.goexercise.app.data.billing.PremiumRepository
import com.goexercise.app.data.friends.FriendsService
import com.goexercise.app.data.milestone.MilestoneRepository
import com.goexercise.app.data.rankup.SharedPrefsRankUpStore
import com.goexercise.app.data.rescue.RescueTicketRepository
import com.goexercise.app.data.rescue.ReviveDismissStore
import com.goexercise.app.data.settings.HealthRepository
import com.goexercise.app.data.settings.SettingsRepository
import com.goexercise.app.domain.AchievementEvaluator
import com.goexercise.app.domain.CatRank
import com.goexercise.app.domain.ChartPeriod
import com.goexercise.app.domain.DailyStatus
import com.goexercise.app.domain.Milestone
import com.goexercise.app.domain.MilestoneDetector
import com.goexercise.app.domain.RankUpDetector
import com.goexercise.app.domain.RankUpEvent
import com.goexercise.app.domain.RescueTicketAllowance
import com.goexercise.app.domain.RescueTicketLogic
import com.goexercise.app.domain.RestDayResolver
import com.goexercise.app.domain.StreakFreezeWindow
import com.goexercise.app.domain.WeightAnalytics
import com.goexercise.app.domain.WorkoutRecord
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.filter
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.time.Clock
import java.time.LocalDate
import java.time.LocalDateTime
import javax.inject.Inject

/**
 * ホームの UDF ViewModel。repo の `Flow<List<WorkoutRecord>>` を [HomeStateReducer] で
 * [HomeUiState] に畳み込み StateFlow で公開する(iOS `@Observable HomeViewModel` に対応)。
 * 記録の変化に加え、1 分ごとの ticker で再計算し**日跨ぎ/時間帯変化**を反映する
 * (猫状態は時刻依存、today 判定は日付依存のため)。集計は reducer(純粋)に隔離。
 */
@HiltViewModel
class HomeViewModel @Inject constructor(
    private val repository: WorkoutRepository,
    private val rescueTickets: RescueTicketRepository,
    private val settings: SettingsRepository,
    private val milestones: MilestoneRepository,
    private val weightRepo: WeightRepository,
    private val health: HealthRepository,
    private val friendsService: FriendsService,
    private val premium: PremiumRepository,
    rankUpStore: SharedPrefsRankUpStore,
    private val reviveDismissStore: ReviveDismissStore,
    private val clock: Clock,
) : ViewModel() {

    private val rankUpDetector = RankUpDetector(rankUpStore)

    init {
        // 初回利用日を一度だけ確定(以後不変)。iOS LifetimeUsageTracker と同じ起点。
        viewModelScope.launch { settings.setFirstUseDateIfAbsent(LocalDate.now(clock)) }
    }

    val uiState: StateFlow<HomeUiState> =
        combine(
            repository.observeRecords(),
            timeKeyTicker(),
            settings.firstUseDate,
            rescueTickets.rescuedDates,
            settings.catBreed,
        ) { records, _, firstUse, rescued, breed ->
            HomeStateReducer.reduce(records, LocalDateTime.now(clock), rescuedDates = rescued, firstUseDate = firstUse)
                .copy(catBreed = breed)
        }.stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5_000),
            initialValue = HomeUiState(),
        )

    /** 未祝いの達成節目(あればホームでお祝いを表示)。acknowledged は DataStore で永続。
     *  migration 完了(`migrated`)を待ってから出すことで、閾値拡充時に silent-ack 前の節目が
     *  一瞬表示されるレースを防ぐ(ack とフラグは同一 edit で原子的に書かれる)。 */
    val pendingMilestone: StateFlow<Milestone?> =
        combine(
            uiState,
            settings.firstUseDate,
            milestones.state,
            health.prefs,
            weightRepo.observeEntries(),
        ) { state, firstUse, milestoneState, healthPrefs, weightEntries ->
            if (!milestoneState.migrated) return@combine null // migration 完了まで出さない
            val today = LocalDate.now(clock)
            // 体重マイルストーン(#9 接続): 開始時/現在体重 + 減量目標で発火。
            val currentKg = WeightAnalytics.dailyLatest(weightEntries, ChartPeriod.All, today).firstOrNull()?.weightKg
            val weightSnapshot = MilestoneDetector.WeightLossSnapshot(
                startKg = healthPrefs.startKg,
                currentKg = currentKg,
                isLossGoal = healthPrefs.isLossGoal,
            )
            val candidates = MilestoneDetector.candidates(
                firstUseDate = firstUse,
                today = today,
                lifetimeAchieved = state.lifetimeStats.achievedDays,
                currentStreak = state.streak.currentStreak,
                weightLoss = weightSnapshot,
            )
            MilestoneDetector.nextPending(candidates, milestoneState.acknowledged)
        }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), null)

    fun acknowledgeMilestone(milestone: Milestone) {
        viewModelScope.launch { milestones.acknowledge(milestone) }
    }

    // ── 機能B: 小節目(称号アップ / 週間連続)の軽量演出 ───────────────────────────────
    // RankUpDetector を streak の変化で評価し、未消化イベントを 1 件保持する。pendingMilestone(大節目)
    // が表示中の時は出さない(二重抑止)。pendingMilestone は上で宣言済みなので .value を安全に読める。
    private val _pendingRankEvent = MutableStateFlow<RankUpEvent?>(null)
    val pendingRankEvent: StateFlow<RankUpEvent?> = _pendingRankEvent.asStateFlow()

    init {
        viewModelScope.launch {
            // ⚠️ uiState の initialValue=HomeUiState() は streak 0(weekStatuses 空)の合成初期値。
            //    これを評価すると RankUpStore の lastRank/lastWeeklyMultiple を 0 にリセットしてしまい、
            //    実 streak 到来時に過去イベントが再発火する。reduce 済みの実状態(weekStatuses 7 要素)を待つ。
            uiState
                .filter { it.weekStatuses.isNotEmpty() }
                .map { it.streak.currentStreak }
                .distinctUntilChanged()
                .collect { streak ->
                val events = rankUpDetector.evaluate(streak)
                // 大節目シート提示中は出さない(二重抑止)。表示中の小節目があればそれを優先し上書きしない。
                if (pendingMilestone.value == null && _pendingRankEvent.value == null) {
                    (events.firstOrNull { it is RankUpEvent.RankUp } ?: events.firstOrNull())
                        ?.let { _pendingRankEvent.value = it }
                }
            }
        }
    }

    fun clearRankEvent() {
        _pendingRankEvent.value = null
    }

    // ── 機能D: 連続記録フリーズ復活ポップ ────────────────────────────────────────────
    /** 復活可能ウィンドウ + 表示用の復元後 streak。revivable でなければ null。 */
    data class ReviveState(
        val result: StreakFreezeWindow.Result,
        val potentialStreak: Int,
        val remaining: Int,
    )

    val reviveState: StateFlow<ReviveState?> = combine(
        repository.observeRecords(),
        rescueTickets.rescuedDates,
        premium.isPremiumActive,
    ) { records, rescued, isPremium ->
        val today = LocalDate.now(clock)
        val allowance = RescueTicketAllowance.current(isPremium)
        val remaining = RescueTicketLogic.remaining(rescued, today, allowance)
        val w = StreakFreezeWindow.evaluate(records, today, rescued, remaining)
        if (!w.revivable) return@combine null
        val potential = restoredStreakLength(records, rescued, w.missedOffsets, today)
        // hasEnough は「各 Missed 日の所属月の枠」を月境界跨ぎでも正しく見るため、月ごとに累積適用を
        // シミュレートして判定する(useTicket は Missed 日の月の枠を強制するため、today 月の remaining
        // 比較では月境界で誤判定する)。remaining は表示用に today 月の値を保持する。
        val missedDates = StreakFreezeWindow.missedDatesForOffsets(w.missedOffsets, today)
        val hasEnough = canReviveAll(missedDates, rescued, allowance)
        ReviveState(result = w.copy(hasEnough = hasEnough), potentialStreak = potential, remaining = remaining)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), null)

    /**
     * 各 Missed 日に対し、その日が属する月の枠でフリーズが使えるかを **累積的に** 検証する。
     * 同一月に複数の Missed があってもチケット消費を sim に積みながら判定するため、
     * 月境界(例: 月初に去年の月末を救済)でも today 月の remaining では拾えない不足を正しく検知する。
     * iOS `RescueTicketStore` の月次集計ミラー。
     */
    private fun canReviveAll(missed: List<LocalDate>, rescued: Set<LocalDate>, allowance: Int): Boolean {
        val sim = rescued.toMutableSet()
        for (d in missed) {
            if (!RescueTicketLogic.hasAvailable(sim, d, allowance)) return false
            sim.add(d)
        }
        return true
    }

    /**
     * 復活を適用する。Missed 各日にフリーズを消費し、その途切れを handled に積む(再ポップ防止)。
     * rescuedDates Flow が更新されると reviveState が再計算され null に落ちる。
     */
    fun applyRevive() {
        viewModelScope.launch {
            val state = reviveState.value ?: return@launch
            val today = LocalDate.now(clock)
            val allowance = RescueTicketAllowance.current(premium.isPremiumActive.value)
            val missedDates = StreakFreezeWindow.missedDatesForOffsets(state.result.missedOffsets, today)
            // ⚠️ 先に markHandled してはいけない: useTicket が一部でも失敗すると streak 未復元のまま
            //    ポップが恒久的に消える。全 Missed 日のチケット使用を**先に**試み、全成功した時だけ handled に積む
            //    (iOS `applyRevive` の `guard applied == missed.count` ミラー)。
            var applied = 0
            for (date in missedDates) {
                if (rescueTickets.useTicket(date, allowance)) applied += 1
            }
            if (applied == missedDates.size) {
                ReviveDismissStore.breakKey(missedDates)?.let { reviveDismissStore.markHandled(it) }
            }
            // 全成功しなかった場合は handled に積まない(ユーザーが再試行できる)。
        }
    }

    /** 「今回はしない」: この途切れを handled に積み再ポップを止める(救済は行わない)。 */
    fun dismissRevive() {
        val state = reviveState.value ?: return
        val today = LocalDate.now(clock)
        val missedDates = StreakFreezeWindow.missedDatesForOffsets(state.result.missedOffsets, today)
        ReviveDismissStore.breakKey(missedDates)?.let { reviveDismissStore.markHandled(it) }
    }

    /** この途切れが既に対応済みか(HomeRoute が launch ごとの提示判定に使う)。 */
    fun reviveBreakHandled(state: ReviveState): Boolean {
        val today = LocalDate.now(clock)
        val missedDates = StreakFreezeWindow.missedDatesForOffsets(state.result.missedOffsets, today)
        val key = ReviveDismissStore.breakKey(missedDates) ?: return true
        return reviveDismissStore.isHandled(key)
    }

    /**
     * iOS `restoredStreakLength` ミラー: Missed を rescued 扱いにした上で、最新の Missed 日から後方へ
     * Achieved/TodayAchieved を数え(Rest はスキップ、それ以外で打ち切り)、復元後の連続日数を求める。
     * today は実 today を使う(Missed は過去日として扱われる)。
     */
    private fun restoredStreakLength(
        records: List<WorkoutRecord>,
        rescued: Set<LocalDate>,
        missedOffsets: List<Int>,
        today: LocalDate,
    ): Int {
        val missedDates = StreakFreezeWindow.missedDatesForOffsets(missedOffsets, today)
        val effectiveRescued = rescued + missedDates
        val start = missedDates.maxOrNull() ?: return 0
        var count = 0
        var date = start
        while (true) {
            val restDays = RestDayResolver.restDaySet(date, records, today)
            val status = AchievementEvaluator.dailyStatus(
                date = date,
                records = records,
                restDays = restDays,
                rescuedDates = effectiveRescued,
                today = today,
            )
            when (status) {
                DailyStatus.Achieved, DailyStatus.TodayAchieved -> count += 1
                DailyStatus.Rest -> { /* skip — 連続は切れない、カウントもしない */ }
                else -> break
            }
            date = date.minusDays(1)
        }
        return count
    }

    // uiState 初期化後に実行する 2 つめの init(init は宣言順に走るため、uiState を参照する処理は
    // 必ず uiState 宣言の後に置く。先に置くと未初期化 null 参照でクラッシュする)。
    init {
        // streak 閾値拡充の migration を版ごとに一度だけ実行する。
        // ⚠️ `uiState` は initialValue=HomeUiState()(streak 0, weekStatuses 空)を即返すため、合成初期値で
        //    migration を確定すると将来の閾値拡充時に既存ユーザーの通過済み streak を silent-ack できない。
        //    reduce 済みの**実状態**(weekStatuses は常に 7 要素)を待ってから実 streak で migrate する。
        viewModelScope.launch {
            val state = uiState.first { it.weekStatuses.isNotEmpty() }
            val streakKeys = MilestoneDetector.currentStreakMilestones(state.streak.currentStreak)
                .map { Milestone.CurrentStreak(it).key }
            milestones.migrateExpandedThresholdsIfNeeded(streakKeys)
        }
    }

    // 友達バックエンドへ自分の実統計(連続/週次達成/猫種など)を反映する(iOS `HomeView` の
    // publishMyProfile ミラー)。**opt-in 厳守**: 既にサインイン済み(`myProfile() != null`)の時だけ
    // publish し、匿名アカウントを新規作成しない。統計が実際に変わった時だけ送る(毎分 ticker や
    // 初期空状態では送らない)。送信失敗(ネット断等)はホームを壊さないよう runCatching で握る。
    init {
        viewModelScope.launch {
            // de-dupe は collector 内で手動管理する。**未サインインのサンプルでは進めない**ことで、
            // 「未サインイン中に統計を観測 → 後で Friends からサインイン → 統計据え置きでも初回 publish される」
            // を保証する(distinctUntilChangedBy を上流に置くと未サインインで消費され初回 publish が欠落する: Codex)。
            var lastPublishedSig: List<Any?>? = null
            uiState
                .filter { it.weekStatuses.isNotEmpty() } // reduce 済みの実状態のみ
                .collect { state ->
                    val sig = MyFriendProfileBuilder.statsSignature(state)
                    if (sig == lastPublishedSig) return@collect // publish 済みの統計は再評価しない(時刻 ticker 等の無駄打ち回避)
                    runCatching {
                        // 未サインインは送らない・作らない(myProfile は未サインイン時 network 不要で null)。
                        // ここで return すると lastPublishedSig を進めないので、サインイン後に再評価される。
                        val current = friendsService.myProfile() ?: return@collect
                        val updated = MyFriendProfileBuilder.build(state, current)
                        if (updated != current) friendsService.publishMyProfile(updated) // 変化が無ければ書かない(iOS guard 相当)
                        lastPublishedSig = sig // サインイン済みで評価できた時だけ de-dupe を進める
                    }
                }
        }
    }

    /**
     * 購読中 1 分ごとに現在の (日付, 時) を発火し distinctUntilChanged で重複除去。
     * 猫状態は時間帯(朝/昼/夜)、today/猫メッセージは日付に依存するので、**時が変わった時だけ**
     * 下流を再計算する(毎分のフル再計算を回避。WhileSubscribed が非表示時に停止)。
     */
    private fun timeKeyTicker() = flow {
        while (true) {
            val now = LocalDateTime.now(clock)
            emit(now.toLocalDate() to now.hour)
            delay(60_000)
        }
    }.distinctUntilChanged()
}
