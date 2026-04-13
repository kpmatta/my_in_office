import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query private var records: [DayRecord]
    
    // In-Office Goals from Settings
    @AppStorage("yearlyInOfficeGoal") private var yearlyInOfficeGoal: Int = 200
    @AppStorage("monthlyInOfficeGoal") private var monthlyInOfficeGoal: Int = 18
    @AppStorage("weeklyInOfficeGoal") private var weeklyInOfficeGoal: Int = 4
    
    private let calendar = Calendar.current
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: - In-Office Goal Progress
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 6) {
                            Image(systemName: "building.2.fill")
                                .font(.title3)
                                .foregroundColor(DayStatus.inOffice.color)
                            Text("In-Office Progress")
                                .font(.title2.bold())
                        }
                        .padding(.horizontal)
                        
                        // Three goal cards side by side
                        HStack(spacing: 10) {
                            GoalProgressCard(
                                label: "Week",
                                count: inOfficeCount(for: thisWeekRecords),
                                goal: weeklyInOfficeGoal,
                                color: DayStatus.inOffice.color
                            )
                            GoalProgressCard(
                                label: currentMonthShort,
                                count: inOfficeCount(for: thisMonthRecords),
                                goal: monthlyInOfficeGoal,
                                color: DayStatus.inOffice.color
                            )
                            GoalProgressCard(
                                label: currentYearName,
                                count: inOfficeCount(for: thisYearRecords),
                                goal: yearlyInOfficeGoal,
                                color: DayStatus.inOffice.color
                            )
                        }
                        .padding(.horizontal)
                    }
                    
                    // MARK: - All Categories Summary
                    VStack(alignment: .leading, spacing: 14) {
                        Text("All Categories")
                            .font(.title2.bold())
                            .padding(.horizontal)
                        
                        // This Week
                        periodRow(title: "This Week", icon: "calendar.day.timeline.left", records: thisWeekRecords)
                        
                        // This Month
                        periodRow(title: currentMonthName, icon: "calendar", records: thisMonthRecords)
                        
                        // This Year
                        periodRow(title: currentYearName, icon: "chart.bar.fill", records: thisYearRecords)
                    }
                    
                    // MARK: - Monthly In-Office Breakdown
                    monthlyBreakdownSection

                }
                .padding(.top, 8)
            }
            .navigationTitle("Dashboard")
        }
    }
    
    // MARK: - Monthly In-Office Breakdown
    
    private var monthlyBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.clock")
                    .font(.title3)
                    .foregroundColor(DayStatus.inOffice.color)
                Text("Monthly In-Office Breakdown")
                    .font(.title2.bold())
            }
            .padding(.horizontal)
            
            let monthlyData = monthlyInOfficeCounts
            let currentMonth = calendar.component(.month, from: Date())
            
            VStack(spacing: 0) {
                ForEach(Array(monthlyData.enumerated()), id: \.offset) { index, item in
                    let isCurrentMonth = item.month == currentMonth
                    let progress: Double = monthlyInOfficeGoal > 0
                        ? min(Double(item.count) / Double(monthlyInOfficeGoal), 1.0)
                        : 0
                    let barColor = monthBarColor(count: item.count, goal: monthlyInOfficeGoal, isFutureMonth: item.month > currentMonth)
                    
                    HStack(spacing: 12) {
                        // Month label
                        Text(item.name)
                            .font(.system(.headline, design: .rounded, weight: isCurrentMonth ? .bold : .medium))
                            .foregroundColor(isCurrentMonth ? .primary : .secondary)
                            .frame(width: 44, alignment: .leading)
                        
                        // Progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(.systemGray5))
                                    .frame(height: 8)
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(barColor.gradient)
                                    .frame(width: max(0, geo.size.width * progress), height: 8)
                            }
                            .frame(height: 8)
                            .frame(maxHeight: .infinity, alignment: .center)
                        }
                        .frame(height: 24)
                        
                        // Count badge
                        Text("\(item.count)")
                            .font(.system(.body, design: .rounded, weight: .bold))
                            .foregroundColor(barColor)
                            .frame(width: 32, alignment: .trailing)
                        
                        // Goal indicator
                        Text("/ \(monthlyInOfficeGoal)")
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(.secondary)
                            .frame(width: 32, alignment: .leading)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(
                        isCurrentMonth
                            ? RoundedRectangle(cornerRadius: 8)
                                .fill(DayStatus.inOffice.color.opacity(0.08))
                            : nil
                    )
                    
                    if index < monthlyData.count - 1 {
                        Divider()
                            .padding(.horizontal, 12)
                    }
                }
            }
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color(.systemGray5), lineWidth: 1)
            )
            .padding(.horizontal)
        }
    }
    
    /// Returns the appropriate color for a month's progress bar based on goal attainment.
    private func monthBarColor(count: Int, goal: Int, isFutureMonth: Bool) -> Color {
        if isFutureMonth || count == 0 {
            return Color(.systemGray4)
        }
        let ratio = Double(count) / Double(max(goal, 1))
        if ratio >= 1.0 {
            return DayStatus.inOffice.color                         // Green – goal met
        } else if ratio >= 0.6 {
            return Color(red: 0.95, green: 0.75, blue: 0.15)       // Amber – on track
        } else {
            return Color(red: 0.92, green: 0.34, blue: 0.34)       // Red – behind
        }
    }
    
    // MARK: - Period Summary Row
    
    private func periodRow(title: String, icon: String, records: [DayRecord]) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.headline.bold())
                Spacer()
            }
            
            LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 12) {
                ForEach(DayStatus.selectable) { status in
                    let count = records.filter { $0.status == status }.count
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(status.color)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Image(systemName: status.icon)
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                            )
                        
                        Text("\(count)")
                            .font(.system(.body, design: .rounded, weight: .bold))
                            .frame(minWidth: 24, alignment: .leading)
                        
                        Text(status.rawValue)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color(.systemGray5), lineWidth: 1)
        )
        .padding(.horizontal)
    }
    

    // MARK: - Helpers
    
    private func inOfficeCount(for filtered: [DayRecord]) -> Int {
        filtered.filter { $0.status == .inOffice }.count
    }
    
    /// Monthly in-office data for all 12 months of the current year.
    private var monthlyInOfficeCounts: [(month: Int, name: String, count: Int)] {
        guard let yearInterval = calendar.dateInterval(of: .year, for: Date()) else { return [] }
        let yearRecords = records.filter { $0.date >= yearInterval.start && $0.date < yearInterval.end && $0.status == .inOffice }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        
        return (1...12).map { month in
            let count = yearRecords.filter { calendar.component(.month, from: $0.date) == month }.count
            var components = DateComponents()
            components.year = calendar.component(.year, from: Date())
            components.month = month
            components.day = 1
            let monthDate = calendar.date(from: components) ?? Date()
            let name = formatter.string(from: monthDate)
            return (month: month, name: name, count: count)
        }
    }
    
    private var thisWeekRecords: [DayRecord] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: Date()) else { return [] }
        return records.filter { $0.date >= interval.start && $0.date < interval.end }
    }
    
    private var thisMonthRecords: [DayRecord] {
        guard let interval = calendar.dateInterval(of: .month, for: Date()) else { return [] }
        return records.filter { $0.date >= interval.start && $0.date < interval.end }
    }
    
    private var thisYearRecords: [DayRecord] {
        guard let interval = calendar.dateInterval(of: .year, for: Date()) else { return [] }
        return records.filter { $0.date >= interval.start && $0.date < interval.end }
    }
    
    private var currentMonthName: String {
        let f = DateFormatter(); f.dateFormat = "MMMM"; return f.string(from: Date())
    }
    
    private var currentMonthShort: String {
        let f = DateFormatter(); f.dateFormat = "MMM"; return f.string(from: Date())
    }
    
    private var currentYearName: String {
        let f = DateFormatter(); f.dateFormat = "yyyy"; return f.string(from: Date())
    }
}

// MARK: - Goal Progress Card

struct GoalProgressCard: View {
    let label: String
    let count: Int
    let goal: Int
    let color: Color
    
    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(count) / Double(goal), 1.0)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.caption.bold())
                .foregroundColor(.secondary)
            
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color.gradient, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 0) {
                    Text("\(count)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(color)
                    Text("/ \(goal)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 72, height: 72)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(color: color.opacity(0.12), radius: 6, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(color.opacity(0.15), lineWidth: 1)
        )
    }
}

#Preview {
    DashboardView()
}
