import XCTest
@testable import InOffice

final class BackupReminderManagerTests: XCTestCase {
    func testNoRecordsDoesNotCreateAnchorOrPrompt() {
        let (manager, _, _, cleanup) = makeManager(now: TestSupport.date(2026, 1, 15))
        defer { cleanup() }

        XCTAssertNil(manager.reminderToPresent(hasRecords: false))
        XCTAssertNil(manager.anchorDate)
        XCTAssertEqual(manager.timesPresented, 0)
    }

    func testExistingUsersWithDataPromptImmediatelyWhenNoStateExists() {
        let (manager, _, now, cleanup) = makeManager(now: TestSupport.date(2026, 1, 15))
        defer { cleanup() }

        let reminder = manager.reminderToPresent(hasRecords: true)

        XCTAssertEqual(reminder, BackupReminderPresentation(scheduledIndex: 0))
        XCTAssertEqual(manager.anchorDate, TestSupport.calendar.startOfDay(for: now))
        XCTAssertEqual(manager.timesPresented, 0)
    }

    func testReminderScheduleFollowsConfiguredMonthOffsets() throws {
        let (manager, setNow, _, cleanup) = makeManager(now: TestSupport.date(2026, 1, 15))
        defer { cleanup() }

        let firstReminder = try XCTUnwrap(manager.reminderToPresent(hasRecords: true))
        manager.markReminderHandled(firstReminder)
        XCTAssertNil(manager.reminderToPresent(hasRecords: true))

        setNow(TestSupport.date(2026, 2, 14))
        XCTAssertNil(manager.reminderToPresent(hasRecords: true))

        setNow(TestSupport.date(2026, 2, 15))
        let secondReminder = try XCTUnwrap(manager.reminderToPresent(hasRecords: true))
        XCTAssertEqual(secondReminder, BackupReminderPresentation(scheduledIndex: 1))
        manager.markReminderHandled(secondReminder)

        setNow(TestSupport.date(2026, 4, 14))
        XCTAssertNil(manager.reminderToPresent(hasRecords: true))

        setNow(TestSupport.date(2026, 4, 15))
        let thirdReminder = try XCTUnwrap(manager.reminderToPresent(hasRecords: true))
        XCTAssertEqual(thirdReminder, BackupReminderPresentation(scheduledIndex: 2))
        manager.markReminderHandled(thirdReminder)

        setNow(TestSupport.date(2026, 7, 15))
        let fourthReminder = try XCTUnwrap(manager.reminderToPresent(hasRecords: true))
        XCTAssertEqual(fourthReminder, BackupReminderPresentation(scheduledIndex: 3))
        manager.markReminderHandled(fourthReminder)

        setNow(TestSupport.date(2027, 1, 14))
        XCTAssertNil(manager.reminderToPresent(hasRecords: true))

        setNow(TestSupport.date(2027, 1, 15))
        let fifthReminder = try XCTUnwrap(manager.reminderToPresent(hasRecords: true))
        XCTAssertEqual(fifthReminder, BackupReminderPresentation(scheduledIndex: 4))
    }

    func testHandlingReminderConsumesCurrentScheduledPrompt() {
        let (manager, _, _, cleanup) = makeManager(now: TestSupport.date(2026, 1, 15))
        defer { cleanup() }

        let reminder = try? XCTUnwrap(manager.reminderToPresent(hasRecords: true))
        XCTAssertNotNil(reminder)

        if let reminder {
            manager.markReminderHandled(reminder)
            manager.markReminderHandled(reminder)
        }

        XCTAssertEqual(manager.timesPresented, 1)
        XCTAssertNil(manager.reminderToPresent(hasRecords: true))
    }

    func testNeverRemindMeSuppressesAllFutureReminders() {
        let (manager, setNow, _, cleanup) = makeManager(now: TestSupport.date(2026, 1, 15))
        defer { cleanup() }

        XCTAssertNotNil(manager.reminderToPresent(hasRecords: true))
        manager.disableReminders()

        XCTAssertTrue(manager.dismissedPermanently)
        XCTAssertNil(manager.reminderToPresent(hasRecords: true))

        setNow(TestSupport.date(2028, 1, 15))
        XCTAssertNil(manager.reminderToPresent(hasRecords: true))
    }

    private func makeManager(now initialNow: Date) -> (BackupReminderManager, (Date) -> Void, Date, () -> Void) {
        let suiteName = "InOfficeTests.BackupReminder.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName) ?? .standard
        userDefaults.removePersistentDomain(forName: suiteName)

        var currentNow = initialNow
        let manager = BackupReminderManager(
            userDefaults: userDefaults,
            calendar: TestSupport.calendar,
            nowProvider: { currentNow }
        )

        let cleanup = {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        return (manager, { currentNow = $0 }, initialNow, cleanup)
    }
}

final class AppNavigationStateTests: XCTestCase {
    func testShowBackupExportFlowSelectsSettingsAndSetsFocus() {
        let navigationState = AppNavigationState()

        navigationState.showBackupExportFlow()

        XCTAssertEqual(navigationState.selectedTab, .settings)
        XCTAssertEqual(navigationState.settingsFocus, .backup)
    }

    func testClearSettingsFocusClearsPendingDestination() {
        let navigationState = AppNavigationState()
        navigationState.settingsFocus = .backup

        navigationState.clearSettingsFocus()

        XCTAssertNil(navigationState.settingsFocus)
    }
}
