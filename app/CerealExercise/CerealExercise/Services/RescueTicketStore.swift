import Foundation

@MainActor
@Observable
final class RescueTicketStore {
    static let usedDatesKey = "rescue.usedDates"
    /// IAP で追加購入されたチケットの残数。月次配布枠とは独立してカウント。
    /// 月をまたいでも消えない (有効期限なし)。
    static let purchasedRemainingKey = "rescue.purchasedRemaining.v1"

    /// アプリ全体で共有する 1 インスタンス。View / VM が独立に new し直すと
    /// `addPurchasedTicket` 直後の表示更新が反映されないため。
    /// テストでは別 UserDefaults suite で個別 init して isolation を保つ。
    static let shared = RescueTicketStore()

    // SwiftUI Observation が確実に発火するよう、状態は **stored property** で持つ
    // (Codex 指摘: computed + UserDefaults だと Observation が変更を追跡できない)。
    // UserDefaults は永続化バックエンドとしてのみ使い、読み取りは in-memory から。
    /// 購入済 (有効期限なし) のチケット残数。
    private(set) var purchasedRemaining: Int
    /// 保険チケットを使った日付 (start-of-day) の集合。
    private(set) var usedDates: Set<Date>

    private let defaults: UserDefaults
    private let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .mondayFirst) {
        self.defaults = defaults
        self.calendar = calendar
        self.purchasedRemaining = defaults.integer(forKey: Self.purchasedRemainingKey)
        let raw = (defaults.array(forKey: Self.usedDatesKey) as? [Double]) ?? []
        self.usedDates = Set(raw.map { Date(timeIntervalSince1970: $0) })
    }

    /// IAP 完了時に呼ぶ。残数 += count。
    func addPurchasedTicket(count: Int = 1) {
        purchasedRemaining += count
        defaults.set(purchasedRemaining, forKey: Self.purchasedRemainingKey)
    }

    /// Returns true if the month for `today` still has a ticket left, given `allowance`.
    /// 月次配布の残数 か 購入済残数 のどちらかが残っていれば true。
    func hasTicketAvailable(today: Date, allowance: Int = 1) -> Bool {
        usedCount(inMonthOf: today) < allowance || purchasedRemaining > 0
    }

    func usedCount(inMonthOf date: Date) -> Int {
        let key = monthKey(for: date)
        return usedDates.filter { monthKey(for: $0) == key }.count
    }

    /// 月次配布枠の残数のみ (購入分は含まない)。UI で「今月 X/Y 残り」表記用。
    func remainingTickets(today: Date, allowance: Int = 1) -> Int {
        max(0, allowance - usedCount(inMonthOf: today))
    }

    /// 表示・残数判定用の総残数 (月次配布残 + 購入残)。
    func totalRemaining(today: Date, allowance: Int = 1) -> Int {
        remainingTickets(today: today, allowance: allowance) + purchasedRemaining
    }

    /// Returns the set of dates (start-of-day) on which a rescue ticket was used.
    func rescuedDates() -> Set<Date> { usedDates }

    /// 月次配布枠 を 購入残 より優先して消費する。
    /// 月次が残っているなら月次から、無ければ購入残から減らす。
    /// - Returns: 消費できれば true、両方とも 0 / または同日に既に消費済みなら false。
    @discardableResult
    func useTicket(on date: Date, allowance: Int = 1) -> Bool {
        let dayStart = calendar.startOfDay(for: date)
        guard hasTicketAvailable(today: dayStart, allowance: allowance) else { return false }
        // 同日二重 useTicket は no-op で false を返す。
        // Set.insert は冪等なので insert.inserted が false なら既に消費済み。
        guard usedDates.insert(dayStart).inserted else { return false }
        defaults.set(usedDates.map(\.timeIntervalSince1970), forKey: Self.usedDatesKey)
        // 月次配布枠が無く購入残から消費した場合だけ counter を減らす。
        if usedCount(inMonthOf: dayStart) > allowance && purchasedRemaining > 0 {
            purchasedRemaining -= 1
            defaults.set(purchasedRemaining, forKey: Self.purchasedRemainingKey)
        }
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
}

@MainActor
enum RescueTicketAllowance {
    /// Cycle tracking グラント: ONなら 2 枚、OFFなら 1 枚。
    static func current(cycleSettings: CycleTrackingSettings = CycleTrackingSettings()) -> Int {
        cycleSettings.isEnabled ? 2 : 1
    }
}
