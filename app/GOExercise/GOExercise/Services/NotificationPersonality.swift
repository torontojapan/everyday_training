import Foundation

/// 通知の「性格」モード (Codex UX 提案 #6)。
/// 毎日同じ文面・同じ頻度の通知は通知疲れを生む。猫キャラと一貫した
/// 「待ち方」をユーザーに選んでもらうことで疲れ回避 + パーソナライズ感を出す。
enum NotificationPersonality: String, CaseIterable, Sendable, Codable {
    /// 静かに待つ: 通知を最小化 (夕方 1 通のみ、しかも streak が危険なときだけ)。
    case quiet
    /// ひとこと呼ぶ: 既存挙動 (朝・夕の 2 通、やさしい標準トーン)。
    case voice
    /// 元気いっぱい: 明るくテンション高めに応援する声掛け。
    case cheer
    /// スパルタ: 厳しめ・熱血に背中を押す声掛け。
    case spartan
    /// クール: 淡々と大人っぽく声をかける。
    case cool
    /// ツンデレ: 照れ隠し気味に気にかける。
    case tsundere
    /// 友達動向で: 友達 push が来たときだけ通知。日常リマインダーは抑制。
    /// 現状は CloudKit + push 基盤未完成のため `quiet` 相当に degrade する。
    case friendDriven

    var displayName: String {
        switch self {
        case .quiet:        return "静かに待つ"
        case .voice:        return "ひとこと呼ぶ"
        case .cheer:        return "元気いっぱい"
        case .spartan:      return "スパルタ"
        case .cool:         return "クール"
        case .tsundere:     return "ツンデレ"
        case .friendDriven: return "友達が動いた時だけ"
        }
    }

    var hint: String {
        switch self {
        case .quiet:        return "通知は最小限。週末の最後の砦だけ。"
        case .voice:        return "朝と夕方、相棒からやさしくひとこと (デフォルト)"
        case .cheer:        return "明るくテンション高めに応援してくれる"
        case .spartan:      return "厳しめ・熱血に背中を押してくれる"
        case .cool:         return "淡々と、大人っぽく声をかけてくれる"
        case .tsundere:     return "照れ隠し気味に、気にかけてくれる"
        case .friendDriven: return "友達が達成したときだけ反応する"
        }
    }

    /// 友達機能が無効 (v1 非表示) の間は `friendDriven` を選択肢から外す。
    /// 友達機能の存在が通知設定に漏れないようにするためのゲート。
    static func visibleCases(friendsEnabled: Bool) -> [NotificationPersonality] {
        friendsEnabled ? allCases : allCases.filter { $0 != .friendDriven }
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
            // 友達機能が無効な間は friendDriven を選べないため、保存値が
            // friendDriven でも voice に倒す (ピッカーの選択不整合と漏れ防止)。
            if value == .friendDriven, !AppFeatureFlags.friendsEnabled {
                return .voice
            }
            return value
        }
        set { defaults.set(newValue.rawValue, forKey: Self.storageKey) }
    }
}
