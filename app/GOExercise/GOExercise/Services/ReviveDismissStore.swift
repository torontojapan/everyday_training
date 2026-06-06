import Foundation

/// 復活ポップを「処理済み(復活 or 見送り)」にした break を記録し、
/// 同じ break での再提示を抑止する(節度・ダークパターン回避)。
struct ReviveDismissStore {
    private let defaults: UserDefaults
    private let storeKey = "revive.handledBreakKeys"
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    /// break キー = 最古 missed 日(startOfDay)の epoch 秒(文字列)。
    static func breakKey(missedDates: [Date], calendar: Calendar = .mondayFirst) -> String? {
        guard let oldest = missedDates.map({ calendar.startOfDay(for: $0) }).min() else { return nil }
        return String(Int(oldest.timeIntervalSince1970))
    }
    func handled() -> [String] { defaults.array(forKey: storeKey) as? [String] ?? [] }
    func isHandled(_ breakKey: String) -> Bool { handled().contains(breakKey) }
    func markHandled(_ breakKey: String) {
        var all = handled()
        guard !all.contains(breakKey) else { return }
        all.append(breakKey)
        if all.count > 32 { all = Array(all.suffix(32)) } // 肥大化防止
        defaults.set(all, forKey: storeKey)
    }
}
