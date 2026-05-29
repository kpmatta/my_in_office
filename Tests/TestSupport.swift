import Foundation
import SwiftData
@testable import InOffice

enum TestSupport {
    static let timeZone = TimeZone(secondsFromGMT: 0)!

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        let components = DateComponents(
            calendar: calendar,
            timeZone: timeZone,
            year: year,
            month: month,
            day: day,
            hour: 12
        )

        return components.date ?? Date(timeIntervalSince1970: 0)
    }

    static func record(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        status: DayStatus,
        isAutoDetected: Bool = false,
        notes: String? = nil
    ) -> DayRecord {
        DayRecord(
            date: date(year, month, day),
            status: status,
            isAutoDetected: isAutoDetected,
            notes: notes
        )
    }

    static func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([DayRecord.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
