import Foundation
import Observation

@MainActor
@Observable
final class ThemeStore {
    static let key = "app.theme"
    static let shared = ThemeStore()

    var theme: AppTheme {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: Self.key)
        }
    }

    init(defaults: UserDefaults = .standard) {
        let raw = defaults.string(forKey: Self.key) ?? AppTheme.peach.rawValue
        self.theme = AppTheme(rawValue: raw) ?? .peach
    }
}
