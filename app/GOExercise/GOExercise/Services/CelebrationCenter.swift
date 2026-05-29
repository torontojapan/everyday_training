import Foundation

/// Single entry point used by views to trigger the celebration haptic.
/// Wire-up: call `CelebrationCenter.shared.fire(.heroic)` from any view's
/// onAppear / completion callback. Honors CelebrationPreferences.
@MainActor
final class CelebrationCenter {
    static let shared = CelebrationCenter()

    private let haptic: any AdvancedHapticPlaying

    init(haptic: any AdvancedHapticPlaying = AdvancedHapticController.shared) {
        self.haptic = haptic
    }

    func fire(_ level: CelebrationLevel) {
        haptic.play(level)
    }
}
