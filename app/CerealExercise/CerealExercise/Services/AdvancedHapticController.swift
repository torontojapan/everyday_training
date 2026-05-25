import CoreHaptics
import Foundation
import UIKit

@MainActor
protocol AdvancedHapticPlaying: AnyObject {
    func play(_ level: CelebrationLevel)
}

/// Uses CoreHaptics for rich, multi-event patterns (continuous rumble + sharp
/// transients) when the device supports it; falls back to the basic
/// UIFeedbackGenerator stack otherwise. Honors CelebrationPreferences.hapticEnabled.
@MainActor
final class AdvancedHapticController: AdvancedHapticPlaying {
    static let shared = AdvancedHapticController()

    private var engine: CHHapticEngine?
    private let supportsHaptics: Bool
    private let preferences: CelebrationPreferences
    private let fallback: HapticFeedbackController

    init(preferences: CelebrationPreferences = .shared,
         fallback: HapticFeedbackController = HapticFeedbackController()) {
        self.preferences = preferences
        self.fallback = fallback
        self.supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        if supportsHaptics {
            do {
                let engine = try CHHapticEngine()
                engine.stoppedHandler = { _ in }
                engine.resetHandler = { [weak self] in
                    try? self?.engine?.start()
                }
                try engine.start()
                self.engine = engine
            } catch {
                self.engine = nil
            }
        }
    }

    func play(_ level: CelebrationLevel) {
        guard preferences.hapticEnabled else { return }
        guard supportsHaptics, let engine else {
            playFallback(level)
            return
        }
        do {
            let pattern = try pattern(for: level)
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            playFallback(level)
        }
    }

    private func playFallback(_ level: CelebrationLevel) {
        switch level {
        case .subtle: fallback.success()
        case .standard: fallback.heroic()
        case .heroic, .legendary: fallback.milestone()
        }
    }

    private func pattern(for level: CelebrationLevel) throws -> CHHapticPattern {
        switch level {
        case .subtle:
            return try CHHapticPattern(events: [
                transient(time: 0, intensity: 0.65, sharpness: 0.55)
            ], parameters: [])

        case .standard:
            return try CHHapticPattern(events: [
                continuous(start: 0, duration: 0.25, intensity: 0.55, sharpness: 0.4),
                transient(time: 0.28, intensity: 0.9, sharpness: 0.7),
                transient(time: 0.46, intensity: 1.0, sharpness: 0.85)
            ], parameters: [])

        case .heroic:
            return try CHHapticPattern(events: [
                continuous(start: 0, duration: 0.45, intensity: 0.7, sharpness: 0.5),
                transient(time: 0.10, intensity: 0.9, sharpness: 0.55),
                transient(time: 0.30, intensity: 1.0, sharpness: 0.75),
                continuous(start: 0.50, duration: 0.30, intensity: 0.5, sharpness: 0.35),
                transient(time: 0.62, intensity: 1.0, sharpness: 0.9),
                transient(time: 0.85, intensity: 1.0, sharpness: 1.0)
            ], parameters: [])

        case .legendary:
            // Crescendo: low rumble → ramp → triple shock → glitter trail
            return try CHHapticPattern(events: [
                continuous(start: 0,   duration: 0.60, intensity: 0.45, sharpness: 0.2),
                continuous(start: 0.55, duration: 0.40, intensity: 0.75, sharpness: 0.5),
                transient(time: 0.95, intensity: 1.0, sharpness: 0.7),
                transient(time: 1.15, intensity: 1.0, sharpness: 0.85),
                transient(time: 1.35, intensity: 1.0, sharpness: 1.0),
                transient(time: 1.55, intensity: 0.7, sharpness: 0.95),
                transient(time: 1.70, intensity: 0.55, sharpness: 1.0),
                transient(time: 1.82, intensity: 0.45, sharpness: 1.0)
            ], parameters: [])
        }
    }

    private func transient(time: TimeInterval, intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            ],
            relativeTime: time
        )
    }

    private func continuous(start: TimeInterval, duration: TimeInterval, intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            ],
            relativeTime: start,
            duration: duration
        )
    }
}

/// Silent no-op used in tests and previews.
@MainActor
final class SilentAdvancedHapticController: AdvancedHapticPlaying {
    private(set) var played: [CelebrationLevel] = []
    func play(_ level: CelebrationLevel) { played.append(level) }
}
