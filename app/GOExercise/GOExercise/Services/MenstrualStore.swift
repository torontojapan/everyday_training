import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class MenstrualStore {
    private let context: ModelContext
    private let calendar: Calendar

    private(set) var entries: [MenstrualEntry] = []
    /// 直近の保存失敗を表す。他ストア (WorkoutStore/WeightStore) と同様、save 失敗を
    /// 握り潰さず観測可能にする (Codex 指摘: 旧 `try?` は失敗時に成功表示のまま
    /// 永続化されず、再起動でデータ消失していた)。
    private(set) var lastErrorMessage: String?
    /// `@ObservationIgnored nonisolated(unsafe)`: deinit から removeObserver するため。
    @ObservationIgnored private nonisolated(unsafe) var resetObserver: NSObjectProtocol?

    init(context: ModelContext, calendar: Calendar = .mondayFirst) {
        self.context = context
        self.calendar = calendar
        fetchEntries()
        // 全記録削除後、保持され続けるストアが削除済み MenstrualEntry を
        // 掴んだままにならないよう再フェッチする (Codex 指摘)。
        resetObserver = NotificationCenter.default.addObserver(
            forName: .goDataDidReset, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.fetchEntries() }
        }
    }

    deinit {
        if let resetObserver {
            NotificationCenter.default.removeObserver(resetObserver)
        }
    }

    func fetchEntries() {
        let descriptor = FetchDescriptor<MenstrualEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        entries = (try? context.fetch(descriptor)) ?? []
    }

    func isMarked(_ date: Date) -> Bool {
        let day = calendar.startOfDay(for: date)
        return entries.contains { calendar.isDate($0.date, inSameDayAs: day) }
    }

    /// Idempotent: ensures (or removes) a record for the given day to match `isOn`.
    func set(_ isOn: Bool, on date: Date) {
        let day = calendar.startOfDay(for: date)
        if isOn {
            guard !isMarked(day) else { return }
            let entry = MenstrualEntry(date: day, calendar: calendar)
            context.insert(entry)
        } else {
            let toDelete = entries.filter { calendar.isDate($0.date, inSameDayAs: day) }
            for entry in toDelete {
                // クラウドバックアップ有効時は削除をサーバへも伝播(次回同期で論理削除)。
                RecordSyncTombstones.note(entry.id.uuidString.lowercased())
                context.delete(entry)
            }
        }
        do {
            try context.save()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = "生理日の保存に失敗しました"
        }
        fetchEntries()
    }

    func markedDates() -> Set<Date> {
        Set(entries.map { calendar.startOfDay(for: $0.date) })
    }
}

@MainActor
final class CycleTrackingSettings {
    static let isEnabledKey = "cycle.tracking.enabled"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isEnabled: Bool {
        get { defaults.bool(forKey: Self.isEnabledKey) }
        set { defaults.set(newValue, forKey: Self.isEnabledKey) }
    }
}
