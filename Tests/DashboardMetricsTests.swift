import XCTest
@testable import InOffice

final class DashboardMetricsTests: XCTestCase {
    func testEmptyMetricsAreZeroed() {
        let metrics = DashboardMetrics(records: [], calendar: TestSupport.calendar, now: TestSupport.date(2026, 5, 15))

        XCTAssertFalse(metrics.hasRecords)
        XCTAssertTrue(metrics.recentRecords.isEmpty)
        XCTAssertEqual(metrics.inOfficeCount(for: .week), 0)
        XCTAssertEqual(metrics.inOfficeCount(for: .month), 0)
        XCTAssertEqual(metrics.inOfficeCount(for: .year), 0)
        XCTAssertEqual(metrics.monthlyInOfficeCounts[1], 0)
        XCTAssertEqual(metrics.monthlyInOfficeCounts[12], 0)
    }

    func testMetricsAggregateCurrentWeekMonthAndYear() {
        let records = [
            TestSupport.record(2026, 5, 14, status: .inOffice),
            TestSupport.record(2026, 5, 13, status: .remote),
            TestSupport.record(2026, 5, 10, status: .pto),
            TestSupport.record(2026, 5, 1, status: .holiday),
            TestSupport.record(2026, 2, 2, status: .inOffice),
            TestSupport.record(2026, 1, 20, status: .inOffice),
            TestSupport.record(2025, 12, 30, status: .inOffice)
        ]

        let metrics = DashboardMetrics(
            records: records,
            calendar: TestSupport.calendar,
            now: TestSupport.date(2026, 5, 15)
        )

        let weekCounts = metrics.counts(for: .week)
        XCTAssertEqual(weekCounts[.inOffice], 1)
        XCTAssertEqual(weekCounts[.remote], 1)
        XCTAssertEqual(weekCounts[.pto], 1)
        XCTAssertEqual(weekCounts[.holiday], 0)

        let monthCounts = metrics.counts(for: .month)
        XCTAssertEqual(monthCounts[.inOffice], 1)
        XCTAssertEqual(monthCounts[.remote], 1)
        XCTAssertEqual(monthCounts[.pto], 1)
        XCTAssertEqual(monthCounts[.holiday], 1)

        let yearCounts = metrics.counts(for: .year)
        XCTAssertEqual(yearCounts[.inOffice], 3)
        XCTAssertEqual(yearCounts[.remote], 1)
        XCTAssertEqual(yearCounts[.pto], 1)
        XCTAssertEqual(yearCounts[.holiday], 1)

        XCTAssertEqual(metrics.monthlyInOfficeCounts[1], 1)
        XCTAssertEqual(metrics.monthlyInOfficeCounts[2], 1)
        XCTAssertEqual(metrics.monthlyInOfficeCounts[5], 1)
        XCTAssertEqual(metrics.monthlyInOfficeCounts[12], 0)
        XCTAssertEqual(metrics.recentRecords.count, 5)
    }
}
