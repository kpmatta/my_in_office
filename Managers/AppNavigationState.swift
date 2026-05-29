import Foundation
import Observation

enum AppTab: Hashable {
    case dashboard
    case log
    case settings
}

@Observable
final class AppNavigationState {
    var selectedTab: AppTab = .dashboard
    var pendingCalendarEntryDate: Date?

    func startFirstEntryFlow(on date: Date = Date()) {
        selectedTab = .log
        pendingCalendarEntryDate = Calendar.current.startOfDay(for: date)
    }

    func clearPendingCalendarEntry() {
        pendingCalendarEntryDate = nil
    }
}
