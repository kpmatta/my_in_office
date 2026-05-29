import Foundation
import Observation

// MARK: - GoalLockMode

enum GoalLockMode: String {
    case none    = "none"
    case weekly  = "weekly"
    case monthly = "monthly"
    case yearly  = "yearly"
}

// MARK: - GoalManager

@Observable
final class GoalManager {

    // MARK: - Stored properties (tracked by @Observable)
    // These are real stored vars so the observation system picks up every mutation.
    // didSet handlers persist each value to UserDefaults.

    var weeklyGoal: Int {
        didSet { UserDefaults.standard.set(weeklyGoal, forKey: "weeklyInOfficeGoal") }
    }

    var monthlyGoal: Int {
        didSet { UserDefaults.standard.set(monthlyGoal, forKey: "monthlyInOfficeGoal") }
    }

    var yearlyGoal: Int {
        didSet { UserDefaults.standard.set(yearlyGoal, forKey: "yearlyInOfficeGoal") }
    }

    var lockMode: GoalLockMode {
        didSet { UserDefaults.standard.set(lockMode.rawValue, forKey: "goalLockMode") }
    }

    private let calendar = Calendar.current

    // MARK: - Init (reads persisted values from UserDefaults)

    init(userDefaults: UserDefaults = .standard) {
        let ud = userDefaults
        let storedWeekly  = ud.integer(forKey: "weeklyInOfficeGoal")
        let storedMonthly = ud.integer(forKey: "monthlyInOfficeGoal")
        let storedYearly  = ud.integer(forKey: "yearlyInOfficeGoal")
        let storedMode    = ud.string(forKey: "goalLockMode") ?? GoalLockMode.none.rawValue

        self.weeklyGoal  = storedWeekly  == 0 ? 4   : storedWeekly
        self.monthlyGoal = storedMonthly == 0 ? 18  : storedMonthly
        self.yearlyGoal  = storedYearly  == 0 ? 200 : storedYearly
        self.lockMode    = GoalLockMode(rawValue: storedMode) ?? .none
    }

    // MARK: - Dynamic Goals

    func effectiveGoal(for period: TimePeriod, metrics: DashboardMetrics, now: Date = Date()) -> Int {
        switch period {
        case .week:
            return effectiveWeeklyGoal(metrics: metrics, now: now)
        case .month:
            return effectiveMonthlyGoal(metrics: metrics, now: now)
        case .year:
            return effectiveYearlyGoal
        }
    }

    private func effectiveWeeklyGoal(metrics: DashboardMetrics, now: Date) -> Int {
        switch lockMode {
        case .none, .weekly:
            return weeklyGoal
        case .monthly:
            let remainingMonthTarget = max(0, monthlyGoal - metrics.inOfficeCount(for: .month))
            guard remainingMonthTarget > 0 else { return 0 }
            return max(1, Int(ceil(Double(remainingMonthTarget) / Double(remainingWeeksInMonth(from: now)))))
        case .yearly:
            let remainingYearTarget = max(0, yearlyGoal - metrics.inOfficeCount(for: .year))
            guard remainingYearTarget > 0 else { return 0 }
            return max(1, Int(ceil(Double(remainingYearTarget) / Double(remainingWeeksInYear(from: now)))))
        }
    }

    private func effectiveMonthlyGoal(metrics: DashboardMetrics, now: Date) -> Int {
        switch lockMode {
        case .none, .monthly:
            return monthlyGoal
        case .weekly:
            return metrics.inOfficeCount(for: .month) + weeklyGoal * remainingWeeksInMonth(from: now)
        case .yearly:
            let remainingYearTarget = max(0, yearlyGoal - metrics.inOfficeCount(for: .year))
            guard remainingYearTarget > 0 else { return 0 }
            return max(1, Int(ceil(Double(remainingYearTarget) / Double(remainingMonthsInYear(from: now)))))
        }
    }

    private var effectiveYearlyGoal: Int {
        switch lockMode {
        case .none, .yearly:
            return yearlyGoal
        case .weekly:
            return weeklyGoal * 52
        case .monthly:
            return monthlyGoal * 12
        }
    }

    // MARK: - Calendar helpers

    private func remainingWeeksInMonth(from now: Date) -> Int {
        guard let monthInterval = calendar.dateInterval(of: .month, for: now) else { return 1 }
        var count = 0
        var cursor = now
        while cursor < monthInterval.end {
            count += 1
            cursor = calendar.date(byAdding: .weekOfYear, value: 1, to: cursor) ?? monthInterval.end
        }
        return max(1, count)
    }

    private func remainingMonthsInYear(from now: Date) -> Int {
        let currentMonth = calendar.component(.month, from: now)
        return max(1, 13 - currentMonth)
    }

    private func remainingWeeksInYear(from now: Date) -> Int {
        guard let yearInterval = calendar.dateInterval(of: .year, for: now) else { return 1 }
        var count = 0
        var cursor = now
        while cursor < yearInterval.end {
            count += 1
            cursor = calendar.date(byAdding: .weekOfYear, value: 1, to: cursor) ?? yearInterval.end
        }
        return max(1, count)
    }

    // MARK: - Static goals (For Settings Display)

    var staticWeeklyGoal: Int {
        switch lockMode {
        case .none, .weekly:
            return weeklyGoal
        case .monthly:
            return max(1, Int(round(Double(monthlyGoal) * 12.0 / 52.0)))
        case .yearly:
            return max(1, Int(round(Double(yearlyGoal) / 52.0)))
        }
    }

    var staticMonthlyGoal: Int {
        switch lockMode {
        case .none, .monthly:
            return monthlyGoal
        case .weekly:
            return max(1, Int(round(Double(weeklyGoal) * 52.0 / 12.0)))
        case .yearly:
            return max(1, Int(round(Double(yearlyGoal) / 12.0)))
        }
    }

    var staticYearlyGoal: Int {
        switch lockMode {
        case .none, .yearly:
            return yearlyGoal
        case .weekly:
            return weeklyGoal * 52
        case .monthly:
            return monthlyGoal * 12
        }
    }

}
