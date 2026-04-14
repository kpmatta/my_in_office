import Foundation
import SwiftData
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

    // MARK: - SwiftData

    private let modelContext: ModelContext
    private let calendar = Calendar.current

    // MARK: - Init (reads persisted values from UserDefaults)

    init(modelContext: ModelContext) {
        self.modelContext = modelContext

        let ud = UserDefaults.standard
        let storedWeekly  = ud.integer(forKey: "weeklyInOfficeGoal")
        let storedMonthly = ud.integer(forKey: "monthlyInOfficeGoal")
        let storedYearly  = ud.integer(forKey: "yearlyInOfficeGoal")
        let storedMode    = ud.string(forKey: "goalLockMode") ?? GoalLockMode.none.rawValue

        self.weeklyGoal  = storedWeekly  == 0 ? 4   : storedWeekly
        self.monthlyGoal = storedMonthly == 0 ? 18  : storedMonthly
        self.yearlyGoal  = storedYearly  == 0 ? 200 : storedYearly
        self.lockMode    = GoalLockMode(rawValue: storedMode) ?? .none
    }

    // MARK: - Logged days helpers

    var loggedThisWeek: Int {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: Date()) else { return 0 }
        return fetchInOfficeDays(from: interval.start, to: interval.end)
    }

    var loggedThisMonth: Int {
        guard let interval = calendar.dateInterval(of: .month, for: Date()) else { return 0 }
        return fetchInOfficeDays(from: interval.start, to: interval.end)
    }

    var loggedThisYear: Int {
        guard let interval = calendar.dateInterval(of: .year, for: Date()) else { return 0 }
        return fetchInOfficeDays(from: interval.start, to: interval.end)
    }

    // MARK: - Calendar helpers

    /// Remaining full + partial weeks from today to end of the current month.
    var remainingWeeksInMonth: Int {
        let now = Date()
        guard let monthInterval = calendar.dateInterval(of: .month, for: now) else { return 1 }
        var count = 0
        var cursor = now
        while cursor < monthInterval.end {
            count += 1
            cursor = calendar.date(byAdding: .weekOfYear, value: 1, to: cursor) ?? monthInterval.end
        }
        return max(1, count)
    }

    /// Remaining full + partial months from this month to end of the current year.
    var remainingMonthsInYear: Int {
        let currentMonth = calendar.component(.month, from: Date())
        return max(1, 13 - currentMonth)
    }

    /// Remaining full + partial weeks from today to end of the current year.
    var remainingWeeksInYear: Int {
        let now = Date()
        guard let yearInterval = calendar.dateInterval(of: .year, for: now) else { return 1 }
        var count = 0
        var cursor = now
        while cursor < yearInterval.end {
            count += 1
            cursor = calendar.date(byAdding: .weekOfYear, value: 1, to: cursor) ?? yearInterval.end
        }
        return max(1, count)
    }

    // MARK: - Effective goals

    var effectiveWeeklyGoal: Int {
        switch lockMode {
        case .none, .weekly:
            return weeklyGoal

        case .monthly:
            let remainingMonthTarget = max(0, monthlyGoal - loggedThisMonth)
            guard remainingMonthTarget > 0 else { return 0 }
            return max(1, Int(ceil(Double(remainingMonthTarget) / Double(remainingWeeksInMonth))))

        case .yearly:
            let remainingYearTarget = max(0, yearlyGoal - loggedThisYear)
            guard remainingYearTarget > 0 else { return 0 }
            return max(1, Int(ceil(Double(remainingYearTarget) / Double(remainingWeeksInYear))))
        }
    }

    var effectiveMonthlyGoal: Int {
        switch lockMode {
        case .none, .monthly:
            return monthlyGoal

        case .weekly:
            // Project forward: already logged + what's left at weekly pace
            return loggedThisMonth + weeklyGoal * remainingWeeksInMonth

        case .yearly:
            let remainingYearTarget = max(0, yearlyGoal - loggedThisYear)
            guard remainingYearTarget > 0 else { return 0 }
            return max(1, Int(ceil(Double(remainingYearTarget) / Double(remainingMonthsInYear))))
        }
    }

    var effectiveYearlyGoal: Int {
        switch lockMode {
        case .none, .yearly:
            return yearlyGoal
        case .weekly:
            return weeklyGoal * 52
        case .monthly:
            return monthlyGoal * 12
        }
    }

    // MARK: - Private fetch

    private func fetchInOfficeDays(from start: Date, to end: Date) -> Int {
        let predicate = #Predicate<DayRecord> { record in
            record.date >= start && record.date < end && record.statusRaw == "In Office"
        }
        let descriptor = FetchDescriptor<DayRecord>(predicate: predicate)
        return (try? modelContext.fetch(descriptor))?.count ?? 0
    }
}
