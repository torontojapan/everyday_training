import SwiftData
import XCTest
@testable import GOExercise

@MainActor
final class DemoDataSeederTests: XCTestCase {
    private var container: ModelContainer?

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: WorkoutRecord.self, configurations: config)
    }

    override func tearDown() async throws {
        container = nil
    }

    private func context() throws -> ModelContext {
        let container = try XCTUnwrap(container)
        return ModelContext(container)
    }

    private func fetchAll(_ context: ModelContext) -> [WorkoutRecord] {
        let descriptor = FetchDescriptor<WorkoutRecord>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func testBasicScenarioInserts12Records() throws {
        let context = try context()
        let today = Date()
        DemoDataSeeder.seed(context: context, today: today, scenario: .basic)
        XCTAssertEqual(fetchAll(context).count, 12)
    }

    func testBasicScenarioProducesStreakAtLeast12() throws {
        let context = try context()
        let today = Calendar.mondayFirst.startOfDay(for: Date())
        DemoDataSeeder.seed(context: context, today: today, scenario: .basic)
        let records = fetchAll(context)
        let streak = StreakCalculator.currentStreak(records: records, today: today)
        // The 12 inserted days all count, and any earlier missed days in the
        // preceding week that fall within the weekly rest limit also extend
        // the streak. So the streak is >= 12.
        XCTAssertGreaterThanOrEqual(streak, 12)
    }

    func testStreakBrokenScenarioProducesStreak0() throws {
        let context = try context()
        let today = Calendar.mondayFirst.startOfDay(for: Date())
        DemoDataSeeder.seed(context: context, today: today, scenario: .streakBroken)
        let records = fetchAll(context)
        let streak = StreakCalculator.currentStreak(records: records, today: today)
        XCTAssertEqual(streak, 0, "Past streak should be broken by current week's misses")
    }

    func testLongStreakScenarioProducesStreak30() throws {
        let context = try context()
        let today = Calendar.mondayFirst.startOfDay(for: Date())
        DemoDataSeeder.seed(context: context, today: today, scenario: .longStreak)
        let records = fetchAll(context)
        let streak = StreakCalculator.currentStreak(records: records, today: today)
        XCTAssertEqual(streak, 30)
    }

    func testEmptyScenarioInsertsNoRecords() throws {
        let context = try context()
        DemoDataSeeder.seed(context: context, today: Date(), scenario: .empty)
        XCTAssertEqual(fetchAll(context).count, 0)
    }

    func testEdgeMinuteScenarioAchievesBothTodayAnd59SecYesterday() throws {
        let context = try context()
        let today = Calendar.mondayFirst.startOfDay(for: Date())
        DemoDataSeeder.seed(context: context, today: today, scenario: .edgeMinute)
        let records = fetchAll(context)
        XCTAssertEqual(records.count, 2)
        for record in records {
            XCTAssertTrue(AchievementEvaluator.isAchieved(record: record))
        }
    }

    func testSeedIsIdempotent() throws {
        let context = try context()
        let today = Date()
        DemoDataSeeder.seed(context: context, today: today, scenario: .basic)
        DemoDataSeeder.seed(context: context, today: today, scenario: .longStreak)
        // Second call should skip because data already exists.
        XCTAssertEqual(fetchAll(context).count, 12)
    }
}
