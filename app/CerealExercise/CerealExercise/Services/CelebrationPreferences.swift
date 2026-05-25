import Foundation
import Observation

/// User-controlled toggle for sensory celebration (advanced haptics).
/// Defaults to ON — most users will want the full effect.
@MainActor
@Observable
final class CelebrationPreferences {
    static let hapticKey = "celebration.haptic.enabled"
    static let shared = CelebrationPreferences()

    private let defaults: UserDefaults

    var hapticEnabled: Bool {
        didSet { defaults.set(hapticEnabled, forKey: Self.hapticKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.object(forKey: Self.hapticKey) == nil {
            defaults.set(true, forKey: Self.hapticKey)
        }
        self.hapticEnabled = defaults.bool(forKey: Self.hapticKey)
    }
}
