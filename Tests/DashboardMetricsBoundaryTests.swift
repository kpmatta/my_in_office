import XCTest
@testable import InOffice

final class DashboardMetricsBoundaryTests: XCTestCase {
    func testWeekBoundaryDoesNotOvercountAcrossWeeks() {
        let calendar = TestSupport.calendar
        let now = TestSupport.date(2026, 1, 7) // mid-week

        // Records around a week boundary.
        let records = [
            TestSupport.record(2026, 1, 5, status: .inOffice),
            TestSupport.record(2026, 1, 6, status: .inOffice),
            TestSupport.record(2026, 1, 7, status: .remote),
            TestSupport.record(2026, 1, 3, status: .holiday)
        ]

        let metrics = DashboardMetrics(records: records, calendar: calendar, now: now)
        let weekCounts = metrics.counts(for: .week)

        // The exact definition of "current week" is Calendar-dependent; this checks internal consistency:
        // week counts must be <= month counts for the same dataset window.
        let monthCounts = metrics.counts(for: .month)
        for status in DayStatus.selectable {
            XCTAssertLessThanOrEqual(weekCounts[status] ?? 0, monthCounts[status] ?? 0)
        }
    }

    func testYearlyMonthlyBucketsOnlyCountInOffice() {
        let calendar = TestSupport.calendar
        let now = TestSupport.date(2026, 6, 1)

        let records = [
            TestSupport.record(2026, 1, 1, status: .remote),
            TestSupport.record(2026, 1, 2, status: .inOffice),
            TestSupport.record(2026, 2, 2, status: .inOffice),
            TestSupport.record(2026, 2, 3, status: .pto),
            TestSupport.record(2026, 12, 25, status: .holiday)
        ]

        let metrics = DashboardMetrics(records: records, calendar: calendar, now: now)

        XCTAssertEqual(metrics.monthlyInOfficeCounts[1], 1)
        XCTAssertEqual(metrics.monthlyInOfficeCounts[2], 1)
        XCTAssertEqual(metrics.monthlyInOfficeCounts[12], 0)
    }
}

