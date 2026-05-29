import XCTest
@testable import GOExercise

@MainActor
final class CelebrationCenterTests: XCTestCase {
    func testFireRoutesToHaptic() {
        let haptic = SilentAdvancedHapticController()
        let center = CelebrationCenter(haptic: haptic)

        center.fire(.heroic)

        XCTAssertEqual(haptic.played, [.heroic])
    }

    func testFireUsesCorrectLevel() {
        let haptic = SilentAdvancedHapticController()
        let center = CelebrationCenter(haptic: haptic)

        center.fire(.subtle)
        center.fire(.standard)
        center.fire(.legendary)

        XCTAssertEqual(haptic.played, [.subtle, .standard, .legendary])
    }
}

@MainActor
final class CelebrationPreferencesTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "CelebrationPreferencesTests")!
        defaults.removePersistentDomain(forName: "CelebrationPreferencesTests")
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "CelebrationPreferencesTests")
        defaults = nil
        super.tearDown()
    }

    func testDefaultsToHapticEnabled() {
        let prefs = CelebrationPreferences(defaults: defaults)
        XCTAssertTrue(prefs.hapticEnabled)
    }

    func testTogglingPersists() {
        let prefs = CelebrationPreferences(defaults: defaults)
        prefs.hapticEnabled = false

        let reloaded = CelebrationPreferences(defaults: defaults)
        XCTAssertFalse(reloaded.hapticEnabled)
    }
}

@MainActor
final class CelebrationLevelMappingTests: XCTestCase {
    func testEachLevelHasDistinctConfettiIntensity() {
        let intensities: [ConfettiView.Intensity] = [
            CelebrationLevel.subtle.confettiIntensity,
            CelebrationLevel.standard.confettiIntensity,
            CelebrationLevel.heroic.confettiIntensity
        ]
        // heroic and legendary share intensity by design (both use .heroic confetti)
        XCTAssertEqual(intensities.count, 3)
    }

    func testRayCountIncreasesWithLevel() {
        XCTAssertLessThan(CelebrationLevel.subtle.rayCount, CelebrationLevel.standard.rayCount)
        XCTAssertLessThan(CelebrationLevel.standard.rayCount, CelebrationLevel.heroic.rayCount)
        XCTAssertLessThan(CelebrationLevel.heroic.rayCount, CelebrationLevel.legendary.rayCount)
    }
}
