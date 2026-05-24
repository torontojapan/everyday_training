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
            WidgetEntry(date: date, snapshot: snapshot)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}
