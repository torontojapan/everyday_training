import XCTest
@testable import GOExercise

@MainActor
final class HapticFeedbackTests: XCTestCase {
    func testSuccessRoutesToProvider() {
        let spy = HapticFeedbackProviderSpy()
        let feedback = HapticFeedbackController(provider: spy)

        feedback.success()

        XCTAssertEqual(spy.events, [.success])
    }

    func testWarningRoutesToProvider() {
        let spy = HapticFeedbackProviderSpy()
        let feedback = HapticFeedbackController(provider: spy)

        feedback.warning()

        XCTAssertEqual(spy.events, [.warning])
    }

    func testTapRoutesToProvider() {
        let spy = HapticFeedbackProviderSpy()
        let feedback = HapticFeedbackController(provider: spy)

        feedback.tap()

        XCTAssertEqual(spy.events, [.tap])
    }

    func testHeroicRoutesToProvider() {
        let spy = HapticFeedbackProviderSpy()
        let feedback = HapticFeedbackController(provider: spy)

        feedback.heroic()

        XCTAssertEqual(spy.events, [.heroic])
    }

    func testMilestoneRoutesToProvider() {
        let spy = HapticFeedbackProviderSpy()
        let feedback = HapticFeedbackController(provider: spy)

        feedback.milestone()

        XCTAssertEqual(spy.events, [.milestone])
    }
}

private final class HapticFeedbackProviderSpy: HapticFeedbackProviding {
    private(set) var events: [HapticFeedbackEvent] = []

    func success() {
        events.append(.success)
    }

    func warning() {
        events.append(.warning)
    }

    func tap() {
        events.append(.tap)
    }

    func heroic() {
        events.append(.heroic)
    }

    func milestone() {
        events.append(.milestone)
    }
}
