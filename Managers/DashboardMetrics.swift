import Foundation

enum TimePeriod: String, CaseIterable, Identifiable {
    case week = "Week"
    case month = "Month"
    case year = "Year"

    var id: Self { self }
}

struct DashboardMetrics {
    let recentRecords: [DayRecord]
    let monthlyInOfficeCounts: [Int: Int]
    let hasRecords: Bool

    private let countsByPeriod: [TimePeriod: [DayStatus: Int]]

    init(records: [DayRecord], calendar: Calendar = .current, now: Date = Date()) {
        self.recentRecords = Array(records.prefix(5))
        self.hasRecords = !records.isEmpty

        let emptyCounts = DashboardMetrics.emptyCounts
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now),
              let monthInterval = calendar.dateInterval(of: .month, for: now),
              let yearInterval = calendar.dateInterval(of: .year, for: now) else {
            self.countsByPeriod = [.week: emptyCounts, .month: emptyCounts, .year: emptyCounts]
            self.monthlyInOfficeCounts = Dictionary(uniqueKeysWithValues: (1...12).map { ($0, 0) })
            return
        }

        var weekCounts = emptyCounts
        var monthCounts = emptyCounts
        var yearCounts = emptyCounts
        var inOfficePerMonth = Array(repeating: 0, count: 12)

        let selectable = Set(DayStatus.selectable)

        for record in records {
            let date = record.date
            let status = record.status
            guard selectable.contains(status) else { continue }

            if date >= weekInterval.start && date < weekInterval.end {
                weekCounts[status, default: 0] += 1
            }
            if date >= monthInterval.start && date < monthInterval.end {
                monthCounts[status, default: 0] += 1
            }
            if date >= yearInterval.start && date < yearInterval.end {
                yearCounts[status, default: 0] += 1
                if status == .inOffice {
                    let month = calendar.component(.month, from: date)
                    if (1...12).contains(month) {
                        inOfficePerMonth[month - 1] += 1
                    }
                }
            }
        }

        self.countsByPeriod = [.week: weekCounts, .month: monthCounts, .year: yearCounts]
        self.monthlyInOfficeCounts = Dictionary(
            uniqueKeysWithValues: (1...12).map { ($0, inOfficePerMonth[$0 - 1]) }
        )
    }

    func counts(for period: TimePeriod) -> [DayStatus: Int] {
        countsByPeriod[period] ?? DashboardMetrics.emptyCounts
    }

    func inOfficeCount(for period: TimePeriod) -> Int {
        counts(for: period)[.inOffice] ?? 0
    }

    private static var emptyCounts: [DayStatus: Int] {
        [.inOffice: 0, .remote: 0, .pto: 0, .holiday: 0]
    }
}
