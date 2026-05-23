import WidgetKit

struct WidgetProvider: TimelineProvider {
    private let store = SharedSnapshotStore()
    private let calendar = Calendar.current

    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), snapshot: SharedSnapshotStore.fallbackSnapshot())
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        completion(WidgetEntry(date: Date(), snapshot: store.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        let now = Date()
        let snapshot = store.read()
        let oneHourLater = calendar.date(byAdding: .hour, value: 1, to: now) ?? now
        let endOfDay = endOfDayMinusOneMinute(from: now)
        let entries = [now, oneHourLater, endOfDay].map { date in
            WidgetEntry(date: date, snapshot: snapshot)
        }

        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func endOfDayMinusOneMinute(from date: Date) -> Date {
        let start = calendar.startOfDay(for: date)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: start) ?? date
        return calendar.date(byAdding: .minute, value: -1, to: tomorrow) ?? date
    }
}
