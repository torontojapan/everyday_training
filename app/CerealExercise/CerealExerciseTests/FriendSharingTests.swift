import XCTest
@testable import CerealExercise

@MainActor
final class FriendSharingPreferencesTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "FriendSharingPreferencesTests")!
        defaults.removePersistentDomain(forName: "FriendSharingPreferencesTests")
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "FriendSharingPreferencesTests")
        defaults = nil
        super.tearDown()
    }

    func testDefaultsToOptOut() {
        let prefs = FriendSharingPreferences(defaults: defaults)
        XCTAssertFalse(prefs.includeExerciseDetail, "detail sharing must default to OFF (opt-in)")
    }

    func testTogglingPersists() {
        let prefs = FriendSharingPreferences(defaults: defaults)
        prefs.includeExerciseDetail = true

        let reloaded = FriendSharingPreferences(defaults: defaults)
        XCTAssertTrue(reloaded.includeExerciseDetail)
    }
}

@MainActor
final class SharedExerciseDetailTests: XCTestCase {

    func testSummaryRepsAndSets() {
        let d = SharedExerciseDetail(name: "スクワット", reps: 20, sets: 3)
        XCTAssertEqual(d.summary, "20回 × 3セット")
    }

    func testSummaryDurationOnly() {
        let d = SharedExerciseDetail(name: "ジョギング", durationMinutes: 45)
        XCTAssertEqual(d.summary, "45分")
    }

    func testSummaryRepsAndDuration() {
        let d = SharedExerciseDetail(name: "プランク", durationMinutes: 2, sets: 3)
        XCTAssertEqual(d.summary, "3セット / 2分")
    }

    func testSummaryRepsOnly() {
        let d = SharedExerciseDetail(name: "腹筋", reps: 50)
        XCTAssertEqual(d.summary, "50回")
    }

    func testSummaryEmptyForBareName() {
        let d = SharedExerciseDetail(name: "ストレッチ")
        XCTAssertEqual(d.summary, "")
    }

    func testCodableRoundTrip() throws {
        let original = SharedExerciseDetail(name: "ベンチプレス", durationMinutes: 30, reps: 8, sets: 5)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SharedExerciseDetail.self, from: data)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.reps, original.reps)
        XCTAssertEqual(decoded.sets, original.sets)
        XCTAssertEqual(decoded.durationMinutes, original.durationMinutes)
    }
}

@MainActor
final class FriendProfileSharingTests: XCTestCase {

    func testTodayExerciseDetailsIsOptional() {
        let withDetails = FriendProfile(
            id: "A", friendCode: "A", username: "a", displayName: "A",
            currentStreak: 1, totalAchievedDays: 1, todayAchieved: true,
            todayCategoryName: "筋トレ", todayExerciseNames: ["スクワット"],
            decorationTier: 0, lastUpdated: Date(),
            weeklyAchievements: nil, connectedSince: nil,
            todayExerciseDetails: [SharedExerciseDetail(name: "スクワット", reps: 20, sets: 3)]
        )
        XCTAssertEqual(withDetails.todayExerciseDetails?.count, 1)

        let withoutDetails = FriendProfile(
            id: "B", friendCode: "B", username: "b", displayName: "B",
            currentStreak: 1, totalAchievedDays: 1, todayAchieved: true,
            todayCategoryName: "ヨガ", todayExerciseNames: ["太陽礼拝"],
            decorationTier: 0, lastUpdated: Date(),
            weeklyAchievements: nil, connectedSince: nil,
            todayExerciseDetails: nil
        )
        XCTAssertNil(withoutDetails.todayExerciseDetails)
    }
}
