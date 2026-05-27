import Foundation
import Observation

/// 身長などの「体に関する一度入力すれば済む値」を保持する。BMI 計算等で利用。
/// 未入力なら nil。1〜2 度しか触らない値なので UserDefaults で十分。
@MainActor
@Observable
final class UserHealthPreferences {
    static let heightKey = "userHealth.heightCentimeters"
    static let shared = UserHealthPreferences()

    private let defaults: UserDefaults

    var heightCentimeters: Double? {
        didSet {
            if let value = heightCentimeters {
                defaults.set(value, forKey: Self.heightKey)
            } else {
                defaults.removeObject(forKey: Self.heightKey)
            }
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.object(forKey: Self.heightKey) as? Double
        self.heightCentimeters = stored
    }

    /// 身長 cm + 体重 kg → BMI。どちらか欠けたら nil。
    func bmi(weightKilograms: Double) -> Double? {
        guard let cm = heightCentimeters, cm > 0 else { return nil }
        let meters = cm / 100.0
        return weightKilograms / (meters * meters)
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
