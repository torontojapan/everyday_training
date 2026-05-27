import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class WeightStore {
    private let context: ModelContext
    private let calendar: Calendar

    private(set) var entries: [WeightEntry] = []
    private(set) var lastErrorMessage: String?

    init(context: ModelContext, calendar: Calendar = .mondayFirst) {
        self.context = context
        self.calendar = calendar
        fetchEntries()
    }

    func fetchEntries() {
        let descriptor = FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        do {
            entries = try context.fetch(descriptor)
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = "体重記録の読み込みに失敗しました"
            entries = []
        }
    }

    @discardableResult
    func add(date: Date, weightKilograms: Double, memo: String? = nil) -> WeightEntry {
        let normalizedDate = calendar.startOfDay(for: date)
        // If a record for the same day already exists, update it.
        if let existing = entries.first(where: { calendar.isDate($0.date, inSameDayAs: normalizedDate) }) {
            existing.weightKilograms = weightKilograms
            existing.memo = memo
            existing.updatedAt = Date()
            save()
            return existing
        }
        let entry = WeightEntry(date: normalizedDate, weightKilograms: weightKilograms, memo: memo, calendar: calendar)
        context.insert(entry)
        save()
        return entry
    }

    func delete(_ entry: WeightEntry) {
        context.delete(entry)
        save()
    }

    var latest: WeightEntry? { entries.first }

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

    /// 指定期間内のエントリ (新→古)。`.all` は全件 (ただし未来日は除外)。
    /// "直近N日" は **今日を含めた N 日間** を意味するため cutoff = 今日 - (N-1)。
    /// 例: week (7日) なら今日とその前 6 日 = 計 7 カレンダー日。
    /// 未来日エントリ (時計ズレやインポートで紛れ込み得る) は上限で除外。
    func chartEntries(period: ChartPeriod, today: Date = Date()) -> [WeightEntry] {
        let todayStart = calendar.startOfDay(for: today)
        guard let days = period.days else {
            return entries.filter { (entry: WeightEntry) in entry.date <= todayStart }
        }
        let cutoff = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) ?? Date.distantPast
        return entries.filter { (entry: WeightEntry) in entry.date >= cutoff && entry.date <= todayStart }
    }

    var change30Days: Double? {
        guard let latest else { return nil }
        let cutoff = calendar.date(byAdding: .day, value: -30, to: latest.date) ?? latest.date
        let earlier = entries.first { $0.date <= cutoff }
        guard let earlier else { return nil }
        return latest.weightKilograms - earlier.weightKilograms
    }

    private func save() {
        do {
            try context.save()
            fetchEntries()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = "保存に失敗しました"
        }
    }
}
