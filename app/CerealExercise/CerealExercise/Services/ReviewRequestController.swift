import Foundation

/// App Store のレビュー依頼を「成功体験の直後」に、控えめな頻度で出すための
/// 判定ロジック。実際の依頼表示は `@Environment(\.requestReview)` 経由で View
/// 側が行い、本型は「今出すべきか」の判断と「出した記録」だけを担う
/// (純粋ロジックなのでテストしやすい)。
///
/// 設計方針:
/// - 連続記録の節目 (1週 / 1ヶ月 / 100日) という明確な達成時だけ出す
/// - 一度出したら最低 90 日は出さない (OS 側も年 3 回に制限するが二重で抑制)
/// - 同じ節目では二度と出さない (再達成での重複を防ぐ)
struct ReviewRequestController {
    /// レビュー依頼を出す連続記録の節目 (日数)。
    static let milestones: Set<Int> = [7, 30, 100]
    /// 前回依頼からの最小間隔 (日)。
    static let minIntervalDays = 90

    private let defaults: UserDefaults
    private static let lastRequestKey = "review.lastRequestDate.v1"
    private static let promptedMilestonesKey = "review.promptedMilestones.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// この連続記録日数でレビュー依頼を出すべきか。
    func shouldRequestReview(streak: Int, now: Date = Date()) -> Bool {
        guard Self.milestones.contains(streak) else { return false }
        guard !promptedMilestones.contains(streak) else { return false }
        if let last = defaults.object(forKey: Self.lastRequestKey) as? Date {
            let days = Calendar.current.dateComponents([.day], from: last, to: now).day ?? 0
            if days < Self.minIntervalDays { return false }
        }
        return true
    }

    /// 依頼を出したことを記録する (節目と日時)。
    func markRequested(streak: Int, now: Date = Date()) {
        defaults.set(now, forKey: Self.lastRequestKey)
        var prompted = promptedMilestones
        prompted.insert(streak)
        defaults.set(Array(prompted), forKey: Self.promptedMilestonesKey)
    }

    private var promptedMilestones: Set<Int> {
        Set(defaults.array(forKey: Self.promptedMilestonesKey) as? [Int] ?? [])
    }
}
