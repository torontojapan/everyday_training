import Foundation

/// 通知の「性格」モード (Codex UX 提案 #6)。
/// 毎日同じ文面・同じ頻度の通知は通知疲れを生む。猫キャラと一貫した
/// 「待ち方」をユーザーに選んでもらうことで疲れ回避 + パーソナライズ感を出す。
enum NotificationPersonality: String, CaseIterable, Sendable, Codable {
    /// 静かに待つ: 通知を最小化 (夕方 1 通のみ、しかも streak が危険なときだけ)。
    case quiet
    /// ひとこと呼ぶ: 既存挙動 (朝・夕の 2 通、現状の最も典型的なトーン)。
    case voice
    /// 友達動向で: 友達 push が来たときだけ通知。日常リマインダーは抑制。
    /// 現状は CloudKit + push 基盤未完成のため `quiet` 相当に degrade する。
    case friendDriven

    var displayName: String {
        switch self {
        case .quiet:        return "静かに待つ"
        case .voice:        return "ひとこと呼ぶ"
        case .friendDriven: return "友達が動いた時だけ"
        }
    }

    var hint: String {
        switch self {
        case .quiet:        return "通知は最小限。週末の最後の砦だけ。"
        case .voice:        return "朝と夕方、猫からひとこと呼ぶ (デフォルト)"
        case .friendDriven: return "友達が達成したときだけ反応する"
        }
    }
}

/// `NotificationPersonality` の永続化 (UserDefaults)。デフォルトは voice。
@MainActor
final class NotificationPersonalityPreferences {
    static let storageKey = "notifications.personality"
    static let shared = NotificationPersonalityPreferences()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var current: NotificationPersonality {
        get {
            guard let raw = defaults.string(forKey: Self.storageKey),
                  let value = NotificationPersonality(rawValue: raw) else {
                return .voice
            }
            return value
        }
        set { defaults.set(newValue.rawValue, forKey: Self.storageKey) }
    }
}
