import Foundation
import SwiftData

@Model
final class DayRecord {
    var date: Date
    var statusRaw: String
    var isAutoDetected: Bool
    
    // Computed property to safely handle the enum
    var status: DayStatus {
        get {
            DayStatus(rawValue: statusRaw) ?? .none
        }
        set {
            statusRaw = newValue.rawValue
        }
    }
    
    init(date: Date, status: DayStatus, isAutoDetected: Bool = false) {
        // Strip time components to store just the day
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        self.date = calendar.date(from: components) ?? date
        self.statusRaw = status.rawValue
        self.isAutoDetected = isAutoDetected
    }
}
