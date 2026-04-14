import SwiftUI
import SwiftData

// MARK: - Enums
enum TimePeriod: String, CaseIterable, Identifiable {
    case week = "Week"
    case month = "Month"
    case year = "Year"
    
    var id: Self { self }
}

enum CardMode {
    case hero
    case grid
}

struct DashboardView: View {
    @Query(sort: \DayRecord.date, order: .reverse) private var records: [DayRecord]
    
    // In-Office Goals from Settings
    @AppStorage("yearlyInOfficeGoal") private var yearlyInOfficeGoal: Int = 200
    @AppStorage("monthlyInOfficeGoal") private var monthlyInOfficeGoal: Int = 18
    @AppStorage("weeklyInOfficeGoal") private var weeklyInOfficeGoal: Int = 4
    
    @State private var selectedTimePeriod: TimePeriod = .week
    
    private let calendar = Calendar.current
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Top: Hero Card
                    GoalProgressCard(
                        mode: .hero,
                        timePeriod: selectedTimePeriod,
                        selectedTimePeriod: $selectedTimePeriod, // For the Menu to mutate
                        counts: getCounts(for: selectedTimePeriod),
                        goal: getGoal(for: selectedTimePeriod)
                    )
                    .padding(.horizontal)
                    
                    // Middle: Grid Cards
                    HStack(spacing: 16) {
                        ForEach(gridPeriods, id: \.self) { period in
                            GoalProgressCard(
                                mode: .grid,
                                timePeriod: period,
                                selectedTimePeriod: .constant(period), // Grid doesn't mutate
                                counts: getCounts(for: period),
                                goal: getGoal(for: period)
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    // MARK: - Monthly In-Office Breakdown
                    monthlyBreakdownSection
                    
                    // Bottom: Recent Logs List
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Recent Logs")
                            .font(.title3.bold())
                            .padding(.horizontal)
                        
                        let recentRecords = Array(records.prefix(5))
                        if recentRecords.isEmpty {
                            Text("No recent logs.")
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(recentRecords.enumerated()), id: \.offset) { index, record in
                                    HStack(spacing: 12) {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(record.status.color)
                                            .frame(width: 36, height: 36)
                                            .overlay(Image(systemName: record.status.icon).foregroundColor(.white).font(.system(size: 14, weight: .bold)))
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(record.date, style: .date)
                                                .font(.headline)
                                            Text(record.status.rawValue)
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 16)
                                    
                                    if index < recentRecords.count - 1 {
                                        Divider().padding(.leading, 64)
                                    }
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                            )
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Dashboard")
        }
    }
    
    // MARK: - Helpers
    
    private var gridPeriods: [TimePeriod] {
        TimePeriod.allCases.filter { $0 != selectedTimePeriod }
    }
    
    private func getGoal(for period: TimePeriod) -> Int {
        switch period {
        case .week: return weeklyInOfficeGoal
        case .month: return monthlyInOfficeGoal
        case .year: return yearlyInOfficeGoal
        }
    }
    
    private func getCounts(for period: TimePeriod) -> [DayStatus: Int] {
        let periodRecords: [DayRecord]
        let now = Date()
        
        switch period {
        case .week:
            guard let interval = calendar.dateInterval(of: .weekOfYear, for: now) else { return [:] }
            periodRecords = records.filter { $0.date >= interval.start && $0.date < interval.end }
        case .month:
            guard let interval = calendar.dateInterval(of: .month, for: now) else { return [:] }
            periodRecords = records.filter { $0.date >= interval.start && $0.date < interval.end }
        case .year:
            guard let interval = calendar.dateInterval(of: .year, for: now) else { return [:] }
            periodRecords = records.filter { $0.date >= interval.start && $0.date < interval.end }
        }
        
        var counts: [DayStatus: Int] = [.inOffice: 0, .remote: 0, .pto: 0, .holiday: 0]
        for status in DayStatus.selectable {
            counts[status] = periodRecords.filter { $0.status == status }.count
        }
        return counts
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
}

// MARK: - Components

struct DashboardCategoryBreakdownView: View {
    let mode: CardMode
    let counts: [DayStatus: Int]
    
    var body: some View {
        if mode == .hero {
            VStack(spacing: 8) {
                ForEach(DayStatus.selectable) { status in
                    HStack {
                        Circle()
                            .fill(status.color)
                            .frame(width: 10, height: 10)
                        
                        Text(status.rawValue)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(counts[status] ?? 0)")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    if status != DayStatus.selectable.last {
                        Divider()
                            .opacity(0.5)
                    }
                }
            }
        } else {
            // Minimized 2x2 grid for Grid mode
            let columns = [GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(DayStatus.selectable) { status in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(status.color)
                            .frame(width: 8, height: 8)
                        Text("\(counts[status] ?? 0)")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

struct GoalProgressCard: View {
    let mode: CardMode
    let timePeriod: TimePeriod
    @Binding var selectedTimePeriod: TimePeriod
    let counts: [DayStatus: Int]
    let goal: Int
    
    private var inOfficeCount: Int { counts[.inOffice] ?? 0 }
    
    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(inOfficeCount) / Double(goal), 1.0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: mode == .hero ? 16 : 12) {
            
            // Header Row
            if mode == .hero {
                HStack {
                    ZStack {
                        Circle()
                            .fill(DayStatus.inOffice.color.opacity(0.15))
                            .frame(width: 32, height: 32)
                        Image(systemName: "building.2.fill")
                            .foregroundColor(DayStatus.inOffice.color)
                            .font(.system(size: 14, weight: .bold))
                    }
                    Text("In-Office Progress")
                        .font(.title3.bold())
                    
                    Spacer()
                    
                    Menu {
                        ForEach(TimePeriod.allCases) { period in
                            Button(period.rawValue) {
                                selectedTimePeriod = period
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(selectedTimePeriod.rawValue)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .foregroundColor(.primary)
                    }
                }
            } else {
                Text(timePeriod.rawValue)
                    .font(.subheadline.bold())
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            
            // Content
            if mode == .hero {
                HStack(spacing: 24) {
                    chartView(size: 120, labelSize: 32, subLabelSize: 14, strokeWidth: 10)
                    
                    // Embedded Breakdown
                    DashboardCategoryBreakdownView(mode: .hero, counts: counts)
                }
            } else {
                VStack(spacing: 12) {
                    chartView(size: 72, labelSize: 22, subLabelSize: 11, strokeWidth: 6)
                    DashboardCategoryBreakdownView(mode: .grid, counts: counts)
                        .padding(.top, 4)
                }
            }
        }
        .padding(mode == .hero ? 20 : 16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
        )
    }
    
    @ViewBuilder
    private func chartView(size: CGFloat, labelSize: CGFloat, subLabelSize: CGFloat, strokeWidth: CGFloat) -> some View {
        let color = DayStatus.inOffice.color
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: strokeWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color.gradient, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            
            VStack(spacing: 0) {
                Text("\(inOfficeCount)")
                    .font(.system(size: labelSize, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                Text("/ \(goal)")
                    .font(.system(size: subLabelSize, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: size, height: size)
        .frame(maxWidth: mode == .grid ? .infinity : nil)
    }
}

#Preview {
    DashboardView()
}
