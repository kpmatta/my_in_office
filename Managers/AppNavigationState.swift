import Foundation
import Observation

enum AppTab: Hashable {
    case dashboard
    case log
    case settings
}

enum SettingsFocus: Hashable {
    case backup
}

@Observable
final class AppNavigationState {
    var selectedTab: AppTab = .dashboard
    var pendingCalendarEntryDate: Date?
    var settingsFocus: SettingsFocus?

    func startFirstEntryFlow(on date: Date = Date()) {
        selectedTab = .log
        pendingCalendarEntryDate = Calendar.current.startOfDay(for: date)
    }

    func clearPendingCalendarEntry() {
        pendingCalendarEntryDate = nil
    }

    func showBackupExportFlow() {
        selectedTab = .settings
        settingsFocus = .backup
    }

    func clearSettingsFocus() {
        settingsFocus = nil
    }
}
