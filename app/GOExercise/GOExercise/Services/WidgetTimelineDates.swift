import Foundation

enum WidgetTimelineDates {
    static func entryDates(from now: Date, calendar: Calendar = .current) -> [Date] {
        let oneHourLater = calendar.date(byAdding: .hour, value: 1, to: now) ?? now
        let endOfDay = endOfDayMinusOneMinute(from: now, calendar: calendar)
        // 翌日 0:00 の entry を加える。これと WidgetSnapshot.projected(to:) により、
        // タイムライン再生成が遅れても日付が変わった瞬間に「達成済み」表示が解け、
        // 記録誘導チップが翌朝に再表示される(監査 P1: 翌朝まで固着)。
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        // WidgetKit は時系列(厳密増加)のタイムラインを要求する。深夜生成だと oneHourLater が
        // 翌日へ回り endOfDay より後になるため、ソート+重複排除して必ず昇順・一意にする(Codex R2)。
        // さらに endOfDay は 23:59:00 固定で、now が 23:59:30 等のときに **now より過去**になり
        // 先頭が過去 entry になる。now 未満の候補は捨て、先頭を常に now にする(Codex R2/R3)。
        let candidates = [now, oneHourLater, endOfDay, startOfTomorrow].filter { $0 >= now }
        var seen = Set<Date>()
        return candidates.sorted().filter { seen.insert($0).inserted }
    }

    static func endOfDayMinusOneMinute(from date: Date, calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: date)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: start) ?? date
        return calendar.date(byAdding: .minute, value: -1, to: tomorrow) ?? date
    }
}
