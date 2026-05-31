import XCTest
@testable import GOExercise

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

@MainActor
final class FriendSharedActivityTests: XCTestCase {
    private let cal = Calendar.mondayFirst
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d))!
    }
    private func rec(_ date: Date, _ cat: WorkoutCategory, _ items: [ExerciseItem]) -> WorkoutRecord {
        WorkoutRecord(date: date, category: cat, exercises: items, calendar: cal)
    }

    func testTodayCategoryAndNamesAlwaysShared() {
        let day = date(2026, 3, 15)
        let records = [
            rec(day, .strength, [ExerciseItem(name: "スクワット", reps: 20, sets: 3),
                                 ExerciseItem(name: "腕立て伏せ", reps: 10, sets: 2)]),
            rec(day, .cardio, [ExerciseItem(name: "ジョギング", durationSeconds: 1200)])
        ]
        let snap = FriendSharedActivity.build(records: records, today: day, calendar: cal, includeDetail: false)
        XCTAssertEqual(snap.todayCategoryName, "筋トレ・有酸素")
        XCTAssertEqual(snap.todayExerciseNames, ["スクワット", "腕立て伏せ", "ジョギング"])
        XCTAssertNil(snap.todayExerciseDetails, "詳細は opt-in OFF では共有しない")
    }

    func testDetailsSharedOnlyWhenOptIn() {
        let day = date(2026, 3, 15)
        let records = [rec(day, .strength, [ExerciseItem(name: "スクワット", durationSeconds: 600, reps: 20, sets: 3)])]
        let on = FriendSharedActivity.build(records: records, today: day, calendar: cal, includeDetail: true)
        XCTAssertEqual(on.todayExerciseDetails?.count, 1)
        XCTAssertEqual(on.todayExerciseDetails?.first?.reps, 20)
        XCTAssertEqual(on.todayExerciseDetails?.first?.sets, 3)
        XCTAssertEqual(on.todayExerciseDetails?.first?.durationMinutes, 10)
    }

    func testMonthlyAggregatesAndDayDedup() {
        let anchor = date(2026, 3, 15)
        let records = [
            rec(date(2026, 3, 15), .strength, [ExerciseItem(name: "A", durationSeconds: 600)]),   // 10分
            rec(date(2026, 3, 15), .cardio, [ExerciseItem(name: "B", durationSeconds: 600)]),     // 同日(別カテゴリ)
            rec(date(2026, 3, 20), .yoga, [ExerciseItem(name: "C", durationSeconds: 1200)]),      // 20分・別日
            rec(date(2026, 2, 28), .strength, [ExerciseItem(name: "D", durationSeconds: 6000)]),  // 別月→除外
            rec(date(2026, 4, 1), .cardio, [ExerciseItem(name: "E", durationSeconds: 6000)])      // 別月→除外
        ]
        let snap = FriendSharedActivity.build(records: records, today: anchor, calendar: cal, includeDetail: false)
        XCTAssertEqual(snap.monthlyTotalMinutes, 40, "今月分のみ合算 (10+10+20)")
        XCTAssertEqual(snap.monthlyAchievedDays, 2, "同日は1日に集約 (3/15, 3/20)")
    }

    func testEmptyWhenNoTodayRecords() {
        let snap = FriendSharedActivity.build(records: [], today: date(2026, 3, 15), calendar: cal, includeDetail: true)
        XCTAssertNil(snap.todayCategoryName)
        XCTAssertTrue(snap.todayExerciseNames.isEmpty)
        XCTAssertEqual(snap.monthlyAchievedDays, 0)
    }
}

@MainActor
final class FriendAvatarIdentityRingTests: XCTestCase {
    func testHueIsDeterministicAndInRange() {
        let h1 = FriendAvatarView.identityRingHue(for: "ABC234")
        let h2 = FriendAvatarView.identityRingHue(for: "ABC234")
        XCTAssertEqual(h1, h2, "同じコードは同じ色相 (決定論的)")
        XCTAssertTrue(h1 >= 0 && h1 < 1, "hue は 0..<1 の範囲")
    }

    func testDifferentCodesProduceDifferentHues() {
        let a = FriendAvatarView.identityRingHue(for: "AAAAAA")
        let b = FriendAvatarView.identityRingHue(for: "BBBBBB")
        XCTAssertNotEqual(a, b, "異なるコードは色相が分かれる(識別性)")
    }
}
