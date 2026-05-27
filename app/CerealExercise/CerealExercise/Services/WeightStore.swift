import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class WeightStore {
    private let context: ModelContext
    private let calendar: Calendar
    private let healthPrefs: UserHealthPreferences

    private(set) var entries: [WeightEntry] = []
    private(set) var lastErrorMessage: String?

    /// `healthPrefs` のデフォルトは `.shared` で本番経路を簡潔に保つ。
    /// テストでは isolated な `UserDefaults` から作った prefs を明示的に
    /// 渡すこと (cross-test pollution 防止)。
    init(context: ModelContext,
         calendar: Calendar = .mondayFirst,
         healthPrefs: UserHealthPreferences = .shared) {
        self.context = context
        self.calendar = calendar
        self.healthPrefs = healthPrefs
        fetchEntries()
    }

    func fetchEntries() {
        // 同一秒の二重 insert (高速タップ・インポート) で順序が不定にならないよう、
        // date 降順 → createdAt 降順 → id 文字列順 の **3 段ソート** で deterministic に。
        // 日内最新の判定 (chartEntries の先頭採用) もこれで安定する (Codex round1)。
        let descriptor = FetchDescriptor<WeightEntry>(sortBy: [
            SortDescriptor(\.date, order: .reverse),
            SortDescriptor(\.createdAt, order: .reverse),
            SortDescriptor(\.id, order: .reverse),
        ])
        do {
            entries = try context.fetch(descriptor)
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = "体重記録の読み込みに失敗しました"
            entries = []
        }
    }

    /// 同一日に複数記録できるよう **常に新規 insert** する (朝/晩などのユースケース)。
    /// 上書きが必要な場合は `delete` してから再 add する設計に統一。
    @discardableResult
    func add(date: Date, weightKilograms: Double, memo: String? = nil) -> WeightEntry {
        let wasEmpty = entries.isEmpty
        let entry = WeightEntry(date: date, weightKilograms: weightKilograms, memo: memo)
        context.insert(entry)
        let saved = save()
        // 一番最初の **永続化に成功した** 記録時のみ「開始時体重」を自動キャプチャ。
        // save 失敗時にスキップしないと、UserDefaults だけ進んで実エントリと
        // 整合しなくなる (Codex 指摘)。
        if wasEmpty && saved {
            captureStartWeightIfNeeded(weightKilograms: weightKilograms)
        }
        return entry
    }

    private func captureStartWeightIfNeeded(weightKilograms: Double) {
        if healthPrefs.startKilograms == nil {
            healthPrefs.startKilograms = weightKilograms
        }
    }

    func delete(_ entry: WeightEntry) {
        context.delete(entry)
        _ = save()
    }

    var latest: WeightEntry? { entries.first }

    /// 未来日エントリ (時計ズレ・インポートで紛れ込み得る) を除いた最新エントリ。
    /// 進捗の baseline 取得など分析系の計算には latest ではなくこちらを使う。
    /// "今日" の記録 (現在時刻入り) は未来扱いしないよう、明日の 00:00 を上限とする。
    var latestNonFuture: WeightEntry? {
        let tomorrowStart = startOfTomorrow()
        return entries.first { $0.date < tomorrowStart }
    }

    /// グラフの期間切替。`.month` がデフォルト。
    enum ChartPeriod: String, CaseIterable, Identifiable, Sendable {
        case week        // 直近7日
        case month       // 直近30日
        case threeMonths // 直近90日
        case sixMonths   // 直近180日
        case all         // 全期間

        var id: String { rawValue }

        var shortLabel: String {
            switch self {
            case .week: return "1週"
            case .month: return "1月"
            case .threeMonths: return "3月"
            case .sixMonths: return "半年"
            case .all: return "全期間"
            }
        }

        var days: Int? {
            switch self {
            case .week: return 7
            case .month: return 30
            case .threeMonths: return 90
            case .sixMonths: return 180
            case .all: return nil
            }
        }
    }

    /// 指定期間内のエントリを **「日内最新」で集約** して返す (新→古)。
    /// 同一日に複数記録があっても、その日の最新 1 件だけがグラフに乗る
    /// (あすけん方式。Happy Scale 流の全点表示よりシンプルさ優先)。
    ///
    /// - "直近N日" は **今日を含めた N 日間** を意味し、cutoff = 今日 - (N-1)。
    ///   例: week (7日) なら今日とその前 6 日 = 計 7 カレンダー日。
    /// - 上限は **明日 00:00** で、今日の現在時刻入りエントリも含める
    ///   (上限を今日 00:00 にすると、time-stamped な今日の記録が漏れる)。
    /// - 未来日 (明日以降) のエントリは時計ズレ・インポート対策で除外。
    func chartEntries(period: ChartPeriod, today: Date = Date()) -> [WeightEntry] {
        let todayStart = calendar.startOfDay(for: today)
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart
        let lowerBound: Date
        if let days = period.days {
            lowerBound = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) ?? Date.distantPast
        } else {
            lowerBound = Date.distantPast
        }

        // entries は date 降順。同じ日の中で最初に出てくる = 最新時刻。
        var seenDays: Set<DateComponents> = []
        var result: [WeightEntry] = []
        for entry in entries where entry.date >= lowerBound && entry.date < tomorrowStart {
            let key = calendar.dateComponents([.year, .month, .day], from: entry.date)
            if seenDays.insert(key).inserted {
                result.append(entry)
            }
        }
        return result
    }

    var change30Days: Double? {
        guard let latest = latestNonFuture else { return nil }
        // cutoff は **calendar 日ベース** で計算する。latest.date が時刻入りの
        // ままだと、cutoff 当日 (latest から 30 calendar 日前) の中で latest と
        // 時刻が前後するエントリが取りこぼされる (Codex round1 priority 1)。
        // startOfDay で正規化してから -30 日することで「当日のエントリは時刻に
        // 関わらず採用候補に入る」を保証。
        let latestDayStart = calendar.startOfDay(for: latest.date)
        let cutoffDayStart = calendar.date(byAdding: .day, value: -30, to: latestDayStart) ?? latestDayStart
        // cutoff 当日に複数件あれば、その日の最新時刻が選ばれる
        // (entries は date 降順なので一致条件下で最新時刻が先頭)。
        let earlier = entries.first { entry in
            let entryDayStart = self.calendar.startOfDay(for: entry.date)
            return entryDayStart <= cutoffDayStart
        }
        guard let earlier else { return nil }
        return latest.weightKilograms - earlier.weightKilograms
    }

    /// 7 日移動平均のトレンド点。Happy Scale 流の killer feature で、
    /// 水分変動による日々のノイズを smoothing して「実勢の動き」を可視化する。
    ///
    /// - `chartEntries(period:today:)` の daily-latest 系列を入力とする。
    /// - 各 anchor 点について「その calendar 日を含む trailing window 日」の
    ///   日内最新値を平均する (時刻情報は startOfDay で潰す)。
    /// - 窓内に `minSamples` 未満しかない点はスキップ (1 件しかない最初の方の
    ///   日でガクッと振れるのを避ける)。
    /// - 返り値は **古→新** (Chart で重ねやすい順)。
    func trendline(period: ChartPeriod,
                   window: Int = 7,
                   minSamples: Int = 2,
                   today: Date = Date()) -> [WeightTrendPoint] {
        precondition(window >= 1, "window must be >= 1")
        precondition(minSamples >= 1, "minSamples must be >= 1")
        // chartEntries は新→古。古→新に並べ替えてから走査。
        let daily = Array(chartEntries(period: period, today: today).reversed())
        // 高速ルックアップ用に (startOfDay → weight) の辞書を構築。
        let dayStarts = daily.map { calendar.startOfDay(for: $0.date) }
        let weights = daily.map(\.weightKilograms)

        var result: [WeightTrendPoint] = []
        for i in daily.indices {
            let anchorDay = dayStarts[i]
            guard let windowStartDay = calendar.date(byAdding: .day,
                                                     value: -(window - 1),
                                                     to: anchorDay) else { continue }
            var sum = 0.0
            var count = 0
            // i から後ろ向きに走査 (daily は古→新)。windowStartDay より古くなったら終了。
            var j = i
            while j >= 0 {
                if dayStarts[j] < windowStartDay { break }
                sum += weights[j]
                count += 1
                j -= 1
            }
            guard count >= minSamples else { continue }
            result.append(WeightTrendPoint(date: anchorDay,
                                           average: sum / Double(count)))
        }
        return result
    }

    /// 7 日移動平均トレンドから目標達成までの **おおよその日数** を線形外挿。
    /// nil を返すケース:
    ///   - 体重 / 目標 / 開始 のいずれかが未設定 (forecast 不能)
    ///   - trend が 2 点未満 (傾き計算不能)
    ///   - 傾きが目標方向と逆 or 0 付近 (絶対値 < 0.005 kg/日)
    ///   - 推定が 365 日を超える (実用上ノイズ。`maxDays` で調整可)
    /// 既に目標到達 (epsilon 内) なら 0。
    ///
    /// `analysisPeriod` で slope 計算に使う window を指定 (デフォルト .month = 30 日)。
    func forecastDaysToTarget(today: Date = Date(),
                              analysisPeriod: ChartPeriod = .month,
                              minSlopeKgPerDay: Double = 0.005,
                              maxDays: Int = 365) -> Int? {
        guard let target = healthPrefs.targetKilograms,
              let latestRaw = latestNonFuture?.weightKilograms else { return nil }

        // Trend 構築前に **raw latest** で「既に目標圏内」を早期判定する。
        // 1 件しか記録がなくて trend が組めないケースでも「圏内です」と返したい。
        if abs(target - latestRaw) < 0.05 { return 0 }

        let trend = trendline(period: analysisPeriod, window: 7, minSamples: 2, today: today)
        guard trend.count >= 2,
              let first = trend.first,
              let last = trend.last else { return nil }
        // baseline は **trend の最新値** (= 7 日移動平均) を使う。raw latest にすると
        // 水分変動などのスパイクで「あと N 日」がブレるが、平均化された値なら安定。
        // 表示している現在体重 (raw latest) とは数値が微妙に異なるが UX 上は問題なし。
        let baseline = last.average
        let delta = target - baseline // 正 = 増量必要 / 負 = 減量必要

        // baseline が trend 由来でも「目標圏内」を 0 扱いにする (slope が小さい
        // ときに days = 巨大値になるのを防ぐ二段ガード)。
        if abs(delta) < 0.05 { return 0 }

        let dayDiff = calendar.dateComponents([.day], from: first.date, to: last.date).day ?? 0
        guard dayDiff > 0 else { return nil }
        let slope = (last.average - first.average) / Double(dayDiff) // kg/day

        // 目標方向と slope の符号が一致していないと達成しない。
        // delta > 0 (増量必要) なら slope > 0
        // delta < 0 (減量必要) なら slope < 0
        if delta > 0, slope <= minSlopeKgPerDay { return nil }
        if delta < 0, slope >= -minSlopeKgPerDay { return nil }

        let days = delta / slope // 同符号で割るので必ず正
        guard days.isFinite, days > 0 else { return nil }
        // 残り日数の round で 0 になると UI 側で「圏内」表示になり誤解させる
        // (epsilon ガードと意味が衝突する)。残りがある場合は **最低 1 日** に
        // ceiling する (Codex round1 priority 2)。
        let rounded = max(1, Int(days.rounded()))
        guard rounded <= maxDays else { return nil }
        return rounded
    }

    // MARK: - Internals

    private func startOfTomorrow(reference: Date = Date()) -> Date {
        let todayStart = calendar.startOfDay(for: reference)
        return calendar.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart
    }

    @discardableResult
    private func save() -> Bool {
        do {
            try context.save()
            fetchEntries()
            lastErrorMessage = nil
            return true
        } catch {
            lastErrorMessage = "保存に失敗しました"
            return false
        }
    }
}
