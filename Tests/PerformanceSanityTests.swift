import XCTest
@testable import InOffice

final class PerformanceSanityTests: XCTestCase {
    func testDashboardMetricsComputationIsFastEnoughForFiveYears() {
        let calendar = TestSupport.calendar
        let now = TestSupport.date(2026, 5, 15)

        var records: [DayRecord] = []
        records.reserveCapacity(365 * 5)

        var cursor = TestSupport.date(2021, 1, 1)
        var dayIndex = 0
        while cursor < now {
            let status: DayStatus = (dayIndex % 2 == 0) ? .inOffice : .remote
            let record = DayRecord(date: cursor, status: status, isAutoDetected: false, notes: nil)
            record.date = cursor
            records.append(record)

            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? now
            dayIndex += 1
        }

        measure {
            _ = DashboardMetrics(records: records, calendar: calendar, now: now)
        }
    }
}

