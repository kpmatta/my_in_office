import XCTest
@testable import InOffice

final class GoalManagerTests: XCTestCase {
    func testNoneModeUsesStoredGoals() {
        let (manager, _) = makeManager()
        manager.weeklyGoal = 3
        manager.monthlyGoal = 12
        manager.yearlyGoal = 150
        manager.lockMode = .none

        let metrics = DashboardMetrics(
            records: [],
            calendar: TestSupport.calendar,
            now: TestSupport.date(2026, 5, 15)
        )

        XCTAssertEqual(manager.effectiveGoal(for: .week, metrics: metrics, now: TestSupport.date(2026, 5, 15)), 3)
        XCTAssertEqual(manager.effectiveGoal(for: .month, metrics: metrics, now: TestSupport.date(2026, 5, 15)), 12)
        XCTAssertEqual(manager.effectiveGoal(for: .year, metrics: metrics, now: TestSupport.date(2026, 5, 15)), 150)
    }

    func testWeeklyLockDerivesMonthlyGoalFromRemainingWeeks() {
        let (manager, _) = makeManager()
        manager.weeklyGoal = 4
        manager.monthlyGoal = 18
        manager.yearlyGoal = 200
        manager.lockMode = .weekly

        // Pretend 6 in-office days already logged this month.
        let now = TestSupport.date(2026, 5, 15)
        let records = (1...6).map { day in
            TestSupport.record(2026, 5, day, status: .inOffice)
        }
        let metrics = DashboardMetrics(records: records, calendar: TestSupport.calendar, now: now)

        let expectedRemainingWeeks = remainingWeeksInMonth(calendar: TestSupport.calendar, now: now)
        let expected = metrics.inOfficeCount(for: .month) + manager.weeklyGoal * expectedRemainingWeeks

        XCTAssertEqual(manager.effectiveGoal(for: .month, metrics: metrics, now: now), expected)
    }

    func testMonthlyLockDerivesWeeklyGoalFromRemainingMonthTarget() {
        let (manager, _) = makeManager()
        manager.weeklyGoal = 4
        manager.monthlyGoal = 10
        manager.yearlyGoal = 200
        manager.lockMode = .monthly

        let now = TestSupport.date(2026, 5, 15)
        let logged = 7
        let records = (1...logged).map { day in
            TestSupport.record(2026, 5, day, status: .inOffice)
        }
        let metrics = DashboardMetrics(records: records, calendar: TestSupport.calendar, now: now)

        let remainingTarget = max(0, manager.monthlyGoal - logged)
        let remainingWeeks = remainingWeeksInMonth(calendar: TestSupport.calendar, now: now)
        let expected = remainingTarget == 0 ? 0 : max(1, Int(ceil(Double(remainingTarget) / Double(remainingWeeks))))

        XCTAssertEqual(manager.effectiveGoal(for: .week, metrics: metrics, now: now), expected)
    }

    func testYearlyLockDerivesMonthlyGoalFromRemainingYearTarget() {
        let (manager, _) = makeManager()
        manager.weeklyGoal = 4
        manager.monthlyGoal = 18
        manager.yearlyGoal = 20
        manager.lockMode = .yearly

        let now = TestSupport.date(2026, 5, 15)
        let loggedThisYear = 8
        let records = (1...loggedThisYear).map { day in
            TestSupport.record(2026, 1, day, status: .inOffice)
        }
        let metrics = DashboardMetrics(records: records, calendar: TestSupport.calendar, now: now)

        let remainingTarget = max(0, manager.yearlyGoal - loggedThisYear)
        let remainingMonths = remainingMonthsInYear(calendar: TestSupport.calendar, now: now)
        let expected = remainingTarget == 0 ? 0 : max(1, Int(ceil(Double(remainingTarget) / Double(remainingMonths))))

        XCTAssertEqual(manager.effectiveGoal(for: .month, metrics: metrics, now: now), expected)
    }

    func testStaticGoalsMatchLockMode() {
        let (manager, _) = makeManager()
        manager.weeklyGoal = 5
        manager.monthlyGoal = 20
        manager.yearlyGoal = 240

        manager.lockMode = .weekly
        XCTAssertEqual(manager.staticWeeklyGoal, 5)
        XCTAssertEqual(manager.staticYearlyGoal, 5 * 52)

        manager.lockMode = .monthly
        XCTAssertEqual(manager.staticMonthlyGoal, 20)
        XCTAssertEqual(manager.staticYearlyGoal, 20 * 12)

        manager.lockMode = .yearly
        XCTAssertEqual(manager.staticYearlyGoal, 240)
        XCTAssertEqual(manager.staticMonthlyGoal, max(1, Int(round(Double(240) / 12.0))))
    }

    private func makeManager() -> (GoalManager, UserDefaults) {
        let suiteName = "InOfficeTests.GoalManager.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName) ?? .standard
        userDefaults.removePersistentDomain(forName: suiteName)

        let manager = GoalManager(userDefaults: userDefaults, calendar: TestSupport.calendar)
        addTeardownBlock {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        return (manager, userDefaults)
    }

    private func remainingWeeksInMonth(calendar: Calendar, now: Date) -> Int {
        var calendar = calendar
        calendar.timeZone = TestSupport.timeZone
        guard let monthInterval = calendar.dateInterval(of: .month, for: now) else { return 1 }
        var count = 0
        var cursor = now
        while cursor < monthInterval.end {
            count += 1
            cursor = calendar.date(byAdding: .weekOfYear, value: 1, to: cursor) ?? monthInterval.end
        }
        return max(1, count)
    }

    private func remainingMonthsInYear(calendar: Calendar, now: Date) -> Int {
        var calendar = calendar
        calendar.timeZone = TestSupport.timeZone
        let currentMonth = calendar.component(.month, from: now)
        return max(1, 13 - currentMonth)
    }
}

