import Foundation
import Testing
@testable import CerealExercise

struct ReviewRequestControllerTests {
    private func makeController() -> ReviewRequestController {
        let defaults = UserDefaults(suiteName: "review-test-\(UUID().uuidString)")!
        return ReviewRequestController(defaults: defaults)
    }

    @Test
    func requestsAtMilestoneStreaks() {
        let controller = makeController()
        #expect(controller.shouldRequestReview(streak: 7))
        #expect(controller.shouldRequestReview(streak: 30))
        #expect(controller.shouldRequestReview(streak: 100))
    }

    @Test
    func doesNotRequestAtNonMilestoneStreaks() {
        let controller = makeController()
        #expect(!controller.shouldRequestReview(streak: 1))
        #expect(!controller.shouldRequestReview(streak: 6))
        #expect(!controller.shouldRequestReview(streak: 8))
        #expect(!controller.shouldRequestReview(streak: 0))
    }

    @Test
    func sameMilestoneIsNotPromptedTwice() {
        let controller = makeController()
        let now = Date()
        #expect(controller.shouldRequestReview(streak: 7, now: now))
        controller.markRequested(streak: 7, now: now)
        // 同じ節目は再達成しても二度と出さない (90 日後でも)。
        let muchLater = Calendar.current.date(byAdding: .day, value: 200, to: now)!
        #expect(!controller.shouldRequestReview(streak: 7, now: muchLater))
    }

    @Test
    func respectsMinimumIntervalAcrossDifferentMilestones() {
        let controller = makeController()
        let now = Date()
        controller.markRequested(streak: 7, now: now)
        // 90 日未満では別の節目でも出さない。
        let soon = Calendar.current.date(byAdding: .day, value: 30, to: now)!
        #expect(!controller.shouldRequestReview(streak: 30, now: soon))
        // 90 日経過後は別の節目で出せる。
        let later = Calendar.current.date(byAdding: .day, value: 95, to: now)!
        #expect(controller.shouldRequestReview(streak: 30, now: later))
    }
}
