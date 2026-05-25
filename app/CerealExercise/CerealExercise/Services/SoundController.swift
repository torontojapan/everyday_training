import AudioToolbox
import Foundation

@MainActor
protocol SoundPlaying: AnyObject {
    func play(_ level: CelebrationLevel)
}

/// Plays system sounds (no bundled audio assets required) layered by celebration
/// level. AudioServices respects silent mode, which is the right behavior here —
/// users on silent shouldn't be blasted by a fanfare.
@MainActor
final class SoundController: SoundPlaying {
    static let shared = SoundController()

    private let preferences: CelebrationPreferences

    init(preferences: CelebrationPreferences = .shared) {
        self.preferences = preferences
    }

    func play(_ level: CelebrationLevel) {
        guard preferences.soundEnabled else { return }
        switch level {
        case .subtle:
            playSequence([(1054, 0)])                       // soft bloom
        case .standard:
            playSequence([(1407, 0), (1075, 0.20)])         // ping + chime
        case .heroic:
            playSequence([(1336, 0), (1407, 0.18), (1023, 0.36)])  // alert → ping → tweet-sent
        case .legendary:
            playSequence([
                (1336, 0), (1407, 0.16), (1023, 0.32),
                (1054, 0.50), (1335, 0.70)
            ])
        }
    }

    private func playSequence(_ items: [(SystemSoundID, Double)]) {
        for (sound, delay) in items {
            if delay <= 0 {
                AudioServicesPlaySystemSound(sound)
            } else {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(delay))
                    AudioServicesPlaySystemSound(sound)
                }
            }
        }
    }
}

/// Silent no-op used in tests and previews.
@MainActor
final class SilentSoundController: SoundPlaying {
    private(set) var played: [CelebrationLevel] = []
    func play(_ level: CelebrationLevel) { played.append(level) }
}
