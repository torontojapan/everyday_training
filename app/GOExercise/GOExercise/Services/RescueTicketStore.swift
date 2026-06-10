import Foundation

/// 連続記録フリーズ (旧「保険チケット」) の使用状況を管理する。
/// 月次の付与枠 (allowance) に対し、使った日付 (start-of-day) を記録する。
/// 付与枠は GOプレミアムなら月 4、無料なら月 1 ([[RescueTicketAllowance]])。
/// IAP の追加購入は廃止 (¥1,000 消耗型を撤廃) したため、残数は月次枠のみ。
@MainActor
@Observable
final class RescueTicketStore {
    static let usedDatesKey = "rescue.usedDates"

    /// アプリ全体で共有する 1 インスタンス。View / VM が独立に new し直すと
    /// 使用直後の表示更新が反映されないため。
    /// テストでは別 UserDefaults suite で個別 init して isolation を保つ。
    static let shared = RescueTicketStore()

    // SwiftUI Observation が確実に発火するよう、状態は **stored property** で持つ。
    /// フリーズを使った日付 (start-of-day) の集合。
    private(set) var usedDates: Set<Date>

    private let defaults: UserDefaults
    private let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .mondayFirst) {
        self.defaults = defaults
        self.calendar = calendar
        // 救済日は `yyyy-MM-dd` 文字列で永続化し、読み込み時に**現在のカレンダー**の startOfDay へ
        // 再構成する。旧実装は epoch 秒(使用時タイムゾーンの startOfDay)で保存しており、端末の
        // タイムゾーンが変わると保存値が新ゾーンの startOfDay と一致せず、救済済みの日が一斉に
        // 未達成へ戻る/月の課金がズレる(監査 F5)。文字列なら暦日の同一性が TZ 非依存で保たれる。
        if let dayStrings = defaults.array(forKey: Self.usedDatesKey) as? [String] {
            self.usedDates = Set(dayStrings.compactMap { Self.date(fromDayKey: $0, calendar: calendar) })
        } else {
            // 旧 epoch 秒形式 → 現在カレンダーの startOfDay に正規化(次行で y-m-d へ移行保存)。
            let raw = (defaults.array(forKey: Self.usedDatesKey) as? [Double]) ?? []
            self.usedDates = Set(raw.map { calendar.startOfDay(for: Date(timeIntervalSince1970: $0)) })
            if !raw.isEmpty { defaults.set(usedDates.map { Self.dayKey(for: $0, calendar: calendar) }, forKey: Self.usedDatesKey) }
        }
        // 旧「購入チケット残数」キーの掃除。¥1,000 消耗型は廃止済みで、本アプリは
        // 未リリース (購入者ゼロ) のため移行は不要。dev/test 残骸のみ除去する。
        defaults.removeObject(forKey: "rescue.purchasedRemaining.v1")
    }

    /// 指定日の月に、まだ付与枠が残っているか。
    func hasTicketAvailable(today: Date, allowance: Int) -> Bool {
        usedCount(inMonthOf: today) < allowance
    }

    func usedCount(inMonthOf date: Date) -> Int {
        let key = monthKey(for: date)
        return usedDates.filter { monthKey(for: $0) == key }.count
    }

    /// その月の残り枚数。UI で「今月 X/Y 残り」表記用。
    func remainingTickets(today: Date, allowance: Int) -> Int {
        max(0, allowance - usedCount(inMonthOf: today))
    }

    /// Returns the set of dates (start-of-day) on which a freeze was used.
    func rescuedDates() -> Set<Date> { usedDates }

    /// 指定日にフリーズを消費する。
    /// - Returns: 消費できれば true、枠切れ or 同日に既に消費済みなら false。
    @discardableResult
    func useTicket(on date: Date, allowance: Int) -> Bool {
        let dayStart = calendar.startOfDay(for: date)
        guard hasTicketAvailable(today: dayStart, allowance: allowance) else { return false }
        // 同日二重 useTicket は no-op で false を返す (Set.insert が冪等)。
        guard usedDates.insert(dayStart).inserted else { return false }
        defaults.set(usedDates.map { Self.dayKey(for: $0, calendar: calendar) }, forKey: Self.usedDatesKey)
        return true
    }

    func clear() {
        usedDates.removeAll()
        defaults.removeObject(forKey: Self.usedDatesKey)
    }

    // MARK: - Private

    private func monthKey(for date: Date) -> String {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return "\(comps.year ?? 0)-\(comps.month ?? 0)"
    }

    /// 永続化キー: `yyyy-MM-dd`(暦日の同一性を TZ 非依存で保つ)。
    private static func dayKey(for date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// `yyyy-MM-dd` を現在カレンダーの startOfDay へ復元。不正形式は nil。
    private static func date(fromDayKey key: String, calendar: Calendar) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var c = DateComponents()
        c.year = parts[0]; c.month = parts[1]; c.day = parts[2]
        return calendar.date(from: c).map { calendar.startOfDay(for: $0) }
    }
}

@MainActor
enum RescueTicketAllowance {
    /// 月次フリーズ上限(全員共通)。base(無料1/プレミアム4)に今月の紹介ボーナスを
    /// 加えても、ここを超えない。
    nonisolated static let monthlyCap = 5

    /// 後方互換: 紹介ボーナス無しの従来 API。
    nonisolated static func current(isPremium: Bool) -> Int {
        current(isPremium: isPremium, referralBonus: 0)
    }

    /// base + 今月の紹介ボーナスを `monthlyCap` でクリップした月次付与枚数。
    /// base = 無料1 / プレミアム4(現行不変)。ボーナスは負値を 0 に丸める。
    /// nonisolated: 純粋な算術なのでネイティブ実行/任意スレッドから呼べる。
    nonisolated static func current(isPremium: Bool, referralBonus: Int) -> Int {
        let base = isPremium ? 4 : 1
        return min(monthlyCap, base + max(0, referralBonus))
    }
}
