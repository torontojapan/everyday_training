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

    /// 小節目(minor)用。シート無しの軽量演出。ハプティクスのみ鳴らし、
    /// 視覚演出(さざ波/称号トースト)は呼び出し側の RankCelebrationOverlay が担う。
    func fireLight() {
        fire(.subtle)
    }
}
