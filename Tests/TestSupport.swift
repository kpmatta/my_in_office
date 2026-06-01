import Darwin
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
        let desiredDate = date(year, month, day)
        let record = DayRecord(
            date: desiredDate,
            status: status,
            isAutoDetected: isAutoDetected,
            notes: notes
        )

        // DayRecord normalizes using Calendar.current; for deterministic tests we force
        // the final stored value to our desired date.
        record.date = desiredDate
        return record
    }

    static func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([DayRecord.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    static func withDefaultTimeZone<T>(_ timeZone: TimeZone, _ work: () throws -> T) rethrows -> T {
        let restore = overrideProcessTimeZone(with: timeZone)
        defer { restore() }
        return try work()
    }

    static func withDefaultTimeZone<T>(_ timeZone: TimeZone, _ work: () async throws -> T) async rethrows -> T {
        let restore = overrideProcessTimeZone(with: timeZone)
        defer { restore() }
        return try await work()
    }

    private static func overrideProcessTimeZone(with timeZone: TimeZone) -> () -> Void {
        let previousDefault = NSTimeZone.default
        let previousTimeZoneIdentifier = ProcessInfo.processInfo.environment["TZ"]

        setenv("TZ", timeZone.identifier, 1)
        tzset()
        NSTimeZone.default = timeZone

        return {
            if let previousTimeZoneIdentifier {
                setenv("TZ", previousTimeZoneIdentifier, 1)
            } else {
                unsetenv("TZ")
            }
            tzset()
            NSTimeZone.default = previousDefault
        }
    }
}
