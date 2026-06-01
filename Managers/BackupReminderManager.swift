import Foundation

struct BackupReminderPresentation: Equatable {
    let scheduledIndex: Int
}

struct BackupReminderManager {
    private enum Keys {
        static let anchorDate = "backupReminder.anchorDate"
        static let timesPresented = "backupReminder.timesPresented"
        static let dismissedPermanently = "backupReminder.dismissedPermanently"
    }

    private let userDefaults: UserDefaults
    private var calendar: Calendar
    private let nowProvider: () -> Date

    init(
        userDefaults: UserDefaults = .standard,
        calendar: Calendar = .current,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.userDefaults = userDefaults
        self.calendar = calendar
        self.nowProvider = nowProvider
    }

    var anchorDate: Date? {
        userDefaults.object(forKey: Keys.anchorDate) as? Date
    }

    var timesPresented: Int {
        userDefaults.integer(forKey: Keys.timesPresented)
    }

    var dismissedPermanently: Bool {
        userDefaults.bool(forKey: Keys.dismissedPermanently)
    }

    func reminderToPresent(hasRecords: Bool) -> BackupReminderPresentation? {
        guard hasRecords, !dismissedPermanently else {
            return nil
        }

        let anchorDate = anchorDate ?? establishAnchorDate()
        let scheduledIndex = timesPresented
        let dueDate = reminderDueDate(for: scheduledIndex, anchorDate: anchorDate)
        let today = calendar.startOfDay(for: nowProvider())

        guard today >= dueDate else {
            return nil
        }

        return BackupReminderPresentation(scheduledIndex: scheduledIndex)
    }

    func markReminderHandled(_ presentation: BackupReminderPresentation) {
        let nextCount = max(timesPresented, presentation.scheduledIndex + 1)
        userDefaults.set(nextCount, forKey: Keys.timesPresented)
    }

    func disableReminders() {
        userDefaults.set(true, forKey: Keys.dismissedPermanently)
    }

    private func establishAnchorDate() -> Date {
        let startOfToday = calendar.startOfDay(for: nowProvider())
        userDefaults.set(startOfToday, forKey: Keys.anchorDate)
        return startOfToday
    }

    private func reminderDueDate(for scheduledIndex: Int, anchorDate: Date) -> Date {
        let monthOffset = reminderMonthOffset(for: scheduledIndex)
        let startOfAnchorDay = calendar.startOfDay(for: anchorDate)
        let dueDate = calendar.date(byAdding: .month, value: monthOffset, to: startOfAnchorDay) ?? startOfAnchorDay
        return calendar.startOfDay(for: dueDate)
    }

    private func reminderMonthOffset(for scheduledIndex: Int) -> Int {
        switch scheduledIndex {
        case 0:
            return 0
        case 1:
            return 1
        case 2:
            return 3
        case 3:
            return 6
        default:
            return 6 + (scheduledIndex - 3) * 6
        }
    }
}
