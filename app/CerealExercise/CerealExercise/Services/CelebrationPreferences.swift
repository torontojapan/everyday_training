import Foundation
import Observation

/// User-controlled toggles for sensory celebration (sound + advanced haptics).
/// Defaults to both ON — most users will want the full effect.
@MainActor
@Observable
final class CelebrationPreferences {
    static let soundKey = "celebration.sound.enabled"
    static let hapticKey = "celebration.haptic.enabled"
    static let shared = CelebrationPreferences()

    private let defaults: UserDefaults

    var soundEnabled: Bool {
        didSet { defaults.set(soundEnabled, forKey: Self.soundKey) }
    }
    var hapticEnabled: Bool {
        didSet { defaults.set(hapticEnabled, forKey: Self.hapticKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.object(forKey: Self.soundKey) == nil {
            defaults.set(true, forKey: Self.soundKey)
        }
        if defaults.object(forKey: Self.hapticKey) == nil {
            defaults.set(true, forKey: Self.hapticKey)
        }
        self.soundEnabled = defaults.bool(forKey: Self.soundKey)
        self.hapticEnabled = defaults.bool(forKey: Self.hapticKey)
    }
}
