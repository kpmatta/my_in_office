import XCTest
@testable import InOffice

final class CalendarMonthSnapshotTests: XCTestCase {
    func testSnapshotBuildsStatusLookupAndCounts() {
        let records = [
            TestSupport.record(2026, 7, 4, status: .inOffice),
            TestSupport.record(2026, 7, 5, status: .remote),
            TestSupport.record(2026, 7, 6, status: .remote),
            TestSupport.record(2026, 7, 7, status: .holiday)
        ]

        let snapshot = CalendarMonthSnapshot(records: records, calendar: TestSupport.calendar)

        XCTAssertEqual(snapshot.status(for: TestSupport.calendar.startOfDay(for: TestSupport.date(2026, 7, 4))), .inOffice)
        XCTAssertEqual(snapshot.status(for: TestSupport.calendar.startOfDay(for: TestSupport.date(2026, 7, 5))), .remote)
        XCTAssertEqual(snapshot.status(for: TestSupport.calendar.startOfDay(for: TestSupport.date(2026, 7, 6))), .remote)
        XCTAssertEqual(snapshot.status(for: TestSupport.calendar.startOfDay(for: TestSupport.date(2026, 7, 8))), .none)

        XCTAssertEqual(snapshot.count(for: .inOffice), 1)
        XCTAssertEqual(snapshot.count(for: .remote), 2)
        XCTAssertEqual(snapshot.count(for: .holiday), 1)
        XCTAssertEqual(snapshot.count(for: .pto), 0)
    }
}
