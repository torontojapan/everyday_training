import Foundation

/// Single entry point used by views to trigger sound + haptic together.
/// Wire-up: call `CelebrationCenter.shared.fire(.heroic)` from any view's
/// onAppear / completion callback. Honors CelebrationPreferences.
@MainActor
final class CelebrationCenter {
    static let shared = CelebrationCenter()

    private let sound: any SoundPlaying
    private let haptic: any AdvancedHapticPlaying

    init(
        sound: any SoundPlaying = SoundController.shared,
        haptic: any AdvancedHapticPlaying = AdvancedHapticController.shared
    ) {
        self.sound = sound
        self.haptic = haptic
    }

    func fire(_ level: CelebrationLevel) {
        haptic.play(level)
        sound.play(level)
    }
}
