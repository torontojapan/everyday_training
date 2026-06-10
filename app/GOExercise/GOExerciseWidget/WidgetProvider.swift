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
        let entries = WidgetTimelineDates.entryDates(from: now, calendar: calendar).map { date in
            // 日付が変わった entry は当日状態(達成/締切)を投影し直す(翌朝の固着回避)。
            WidgetEntry(date: date, snapshot: snapshot.projected(to: date, calendar: calendar))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}
