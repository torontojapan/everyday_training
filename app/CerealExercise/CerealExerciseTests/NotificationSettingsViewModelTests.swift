import XCTest
@testable import CerealExercise

@MainActor
final class NotificationSettingsViewModelTests: XCTestCase {
    func testLoadsDefaultValues() {
        let store = NotificationSettingsStore(defaults: makeDefaults())
        let viewModel = NotificationSettingsViewModel(store: store, scheduler: NotificationSettingsSchedulerSpy(), permissionManager: NotificationPermissionManagerSpy())

        XCTAssertTrue(viewModel.isEnabled)
        XCTAssertEqual(viewModel.notificationCount, 2)
        XCTAssertEqual(viewModel.firstTimeComponents.hour, 8)
        XCTAssertEqual(viewModel.firstTimeComponents.minute, 30)
        XCTAssertEqual(viewModel.secondTimeComponents.hour, 20)
        XCTAssertEqual(viewModel.secondTimeComponents.minute, 0)
    }

    func testTurningOffSavesAndReschedules() async {
        let store = NotificationSettingsStore(defaults: makeDefaults())
        let scheduler = NotificationSettingsSchedulerSpy()
        let viewModel = NotificationSettingsViewModel(store: store, scheduler: scheduler, permissionManager: NotificationPermissionManagerSpy())

        await viewModel.setEnabled(false)

        XCTAssertFalse(store.load().isEnabled)
        XCTAssertEqual(scheduler.scheduledSettings.last?.isEnabled, false)
    }

    func testTurningOnRequestsAuthorizationAndReschedules() async {
        let defaults = makeDefaults()
        NotificationSettingsStore(defaults: defaults).save(NotificationSettings(isEnabled: false))
        let permissionManager = NotificationPermissionManagerSpy()
        let scheduler = NotificationSettingsSchedulerSpy()
        let viewModel = NotificationSettingsViewModel(
            store: NotificationSettingsStore(defaults: defaults),
            scheduler: scheduler,
            permissionManager: permissionManager
        )

        await viewModel.setEnabled(true)

        XCTAssertEqual(permissionManager.requestCount, 1)
        XCTAssertEqual(scheduler.scheduledSettings.last?.isEnabled, true)
    }

    func testChangingFirstTimePersistsAndReschedules() async {
        let store = NotificationSettingsStore(defaults: makeDefaults())
        let scheduler = NotificationSettingsSchedulerSpy()
        let viewModel = NotificationSettingsViewModel(store: store, scheduler: scheduler, permissionManager: NotificationPermissionManagerSpy())

        await viewModel.setFirstTime(hour: 7, minute: 45)

        XCTAssertEqual(store.load().morning, NotificationTime(hour: 7, minute: 45))
        XCTAssertEqual(scheduler.scheduledSettings.last?.morning, NotificationTime(hour: 7, minute: 45))
    }

    func testChangingNotificationCountToOnePersistsAndReschedules() async {
        let store = NotificationSettingsStore(defaults: makeDefaults())
        let scheduler = NotificationSettingsSchedulerSpy()
        let viewModel = NotificationSettingsViewModel(store: store, scheduler: scheduler, permissionManager: NotificationPermissionManagerSpy())

        await viewModel.setNotificationCount(1)

        XCTAssertEqual(store.load().notificationCount, 1)
        XCTAssertEqual(scheduler.scheduledSettings.last?.notificationCount, 1)
    }

    func testChangingCountToZeroDisablesNotifications() async {
        let store = NotificationSettingsStore(defaults: makeDefaults())
        let scheduler = NotificationSettingsSchedulerSpy()
        let viewModel = NotificationSettingsViewModel(store: store, scheduler: scheduler, permissionManager: NotificationPermissionManagerSpy())

        await viewModel.setNotificationCount(0)

        XCTAssertFalse(store.load().isEnabled)
        XCTAssertEqual(scheduler.scheduledSettings.last?.notificationCount, 0)
    }

    private func makeDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: "NotificationSettingsViewModelTests.\(UUID().uuidString)")!
        return defaults
    }
}

private final class NotificationSettingsSchedulerSpy: NotificationSettingsScheduling {
    private(set) var scheduledSettings: [NotificationSettings] = []

    func apply(settings: NotificationSettings) async {
        scheduledSettings.append(settings)
    }
}

private final class NotificationPermissionManagerSpy: NotificationPermissionManaging {
    private(set) var requestCount = 0

    func requestAuthorizationIfNeeded() async {
        requestCount += 1
    }
}
