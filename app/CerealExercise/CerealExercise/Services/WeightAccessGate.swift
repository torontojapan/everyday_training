import Foundation

/// 体重タブのアクセス状態。
/// - `freeTrialActive(remainingDays)`: 体重タブを初めて開いた日から 30 日以内
/// - `freeTrialExpired`: 30 日経過 (subscription 未購入)
/// - `subscribed`: 体重 Pro subscription 有効
enum WeightAccess: Equatable {
    case freeTrialActive(remainingDays: Int)
    case freeTrialExpired
    case subscribed

    var isUnlocked: Bool {
        switch self {
        case .freeTrialActive, .subscribed: return true
        case .freeTrialExpired: return false
        }
    }
}

/// 体重タブの「初回起動日」を UserDefaults に保存し、現在のアクセス状態を返す。
///
/// 設計メモ:
/// - 初回起動日は **体重タブを開いた瞬間** に記録する (アプリ初回起動ではなく)。
///   そうしないと「ユーザーが体重に興味ないまま 30 日経過 → 興味出た時には課金壁」
///   になってしまう。
/// - StoreKitManager の `isWeightProActive` を渡して subscription 状態を反映。
/// - calendar / dateProvider は注入可能で test しやすく。
@MainActor
final class WeightAccessGate {
    static let firstOpenedKey = "weightTab.firstOpenedAt.v1"

    private let defaults: UserDefaults
    private let dateProvider: any DateProviding
    private let calendar: Calendar
    private let trialDays: Int

    init(defaults: UserDefaults = .standard,
         dateProvider: any DateProviding = SystemDateProvider(),
         calendar: Calendar = .mondayFirst,
         trialDays: Int = 30) {
        self.defaults = defaults
        self.dateProvider = dateProvider
        self.calendar = calendar
        self.trialDays = trialDays
    }

    /// 体重タブが開かれたタイミングで呼ぶ。まだ記録されていなければ「今日」を保存。
    /// 既に値があれば何もしない (再 seed 安全)。
    func markOpenedIfNeeded() {
        if defaults.object(forKey: Self.firstOpenedKey) == nil {
            defaults.set(dateProvider.currentDate().timeIntervalSince1970, forKey: Self.firstOpenedKey)
        }
    }

    /// 現在のアクセス状態。`isSubscribed` を呼び出し側が渡すことで
    /// StoreKitManager 依存を外し、test もしやすくする。
    func currentAccess(isSubscribed: Bool) -> WeightAccess {
        if isSubscribed { return .subscribed }
        let now = dateProvider.currentDate()
        guard let firstOpened = firstOpenedDate() else {
            // まだ体重タブを開いていない = trial 開始前。トライアル満日数で返す。
            return .freeTrialActive(remainingDays: trialDays)
        }
        let daysSince = daysSinceOpen(from: firstOpened, to: now)
        let remaining = trialDays - daysSince
        return remaining > 0 ? .freeTrialActive(remainingDays: remaining) : .freeTrialExpired
    }

    /// 体重タブ初回起動日 (start-of-day)。未設定なら nil。
    func firstOpenedDate() -> Date? {
        guard let ts = defaults.object(forKey: Self.firstOpenedKey) as? Double else { return nil }
        return calendar.startOfDay(for: Date(timeIntervalSince1970: ts))
    }

    /// テスト用に初回起動日をリセット。
    func clear() {
        defaults.removeObject(forKey: Self.firstOpenedKey)
    }

    private func daysSinceOpen(from start: Date, to now: Date) -> Int {
        let startDay = calendar.startOfDay(for: start)
        let nowDay = calendar.startOfDay(for: now)
        return calendar.dateComponents([.day], from: startDay, to: nowDay).day ?? 0
    }
}
