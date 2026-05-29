import Foundation
import Observation

/// 身長などの「体に関する一度入力すれば済む値」を保持する。BMI 計算等で利用。
/// 未入力なら nil。1〜2 度しか触らない値なので UserDefaults で十分。
@MainActor
@Observable
final class UserHealthPreferences {
    static let heightKey = "userHealth.heightCentimeters"
    static let targetKey = "userHealth.targetKilograms"
    static let startKey = "userHealth.startKilograms"
    static let shared = UserHealthPreferences()

    private let defaults: UserDefaults

    var heightCentimeters: Double? {
        didSet { writeOrRemove(heightCentimeters, key: Self.heightKey) }
    }

    /// 目標体重 (kg)。未設定なら nil。
    var targetKilograms: Double? {
        didSet { writeOrRemove(targetKilograms, key: Self.targetKey) }
    }

    /// 開始時体重 (kg)。初回入力時に自動キャプチャされる、進捗率の分母。
    /// ユーザーが目標を再設定したらリセットされる。
    var startKilograms: Double? {
        didSet { writeOrRemove(startKilograms, key: Self.startKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.heightCentimeters = defaults.object(forKey: Self.heightKey) as? Double
        self.targetKilograms = defaults.object(forKey: Self.targetKey) as? Double
        self.startKilograms = defaults.object(forKey: Self.startKey) as? Double
    }

    private func writeOrRemove(_ value: Double?, key: String) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    /// 身長 cm + 体重 kg → BMI。どちらか欠けたら nil。
    func bmi(weightKilograms: Double) -> Double? {
        guard let cm = heightCentimeters, cm > 0 else { return nil }
        let meters = cm / 100.0
        return weightKilograms / (meters * meters)
    }

    /// 目標達成までの残り kg (正=減量必要 / 負=既に達成・超過)。
    /// 目標未設定なら nil。
    func remainingToTarget(currentKilograms: Double) -> Double? {
        guard let target = targetKilograms else { return nil }
        return currentKilograms - target
    }

    /// 開始時から目標までの達成率 (0.0 〜 1.0、超過時は 1.0 で頭打ち)。
    /// 増量・減量どちらの方向にも対応。開始 = 目標の特殊ケースは nil。
    func progressRatio(currentKilograms: Double) -> Double? {
        guard let target = targetKilograms, let start = startKilograms else { return nil }
        let totalDelta = target - start
        guard abs(totalDelta) > 0.001 else { return nil } // start == target
        let achievedDelta = currentKilograms - start
        let raw = achievedDelta / totalDelta
        return min(max(raw, 0.0), 1.0)
    }

    /// 減量目標か (true) 増量目標か (false)。目標 or 開始未設定なら nil。
    /// 開始 == 目標 (差分なし) も nil。「目標達成」判定はこの場合
    /// `abs(current - target) < epsilon` で View 側が判断する。
    func isLossGoal() -> Bool? {
        guard let target = targetKilograms, let start = startKilograms else { return nil }
        guard abs(target - start) > 0.001 else { return nil }
        return target < start
    }
}

/// BMI 区分表示（WHO 基準ベース、日本肥満学会の閾値）。
enum BMICategory: String {
    case underweight   // < 18.5
    case normal        // 18.5 〜 24.9
    case overweight    // 25.0 〜 29.9
    case obese         // ≥ 30.0

    init(bmi: Double) {
        switch bmi {
        case ..<18.5: self = .underweight
        case 18.5..<25.0: self = .normal
        case 25.0..<30.0: self = .overweight
        default: self = .obese
        }
    }

    var displayName: String {
        switch self {
        case .underweight: return "やせ"
        case .normal: return "普通"
        case .overweight: return "肥満(1度)"
        case .obese: return "肥満(2度以上)"
        }
    }
}
