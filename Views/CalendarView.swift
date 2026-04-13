import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DayRecord.date, order: .reverse) private var records: [DayRecord]
    
    @State private var displayedMonth = Date()
    @State private var selectedDate: Date? = nil
    @State private var showingStatusPicker = false
    
    private let calendar = Calendar.current
    private let daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Month navigation header
                    monthHeader
                    
                    // Calendar Card
                    VStack(spacing: 12) {
                        dayOfWeekHeader
                        calendarGrid
                    }
                    .padding(.vertical, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
                    )
                    .padding(.horizontal)
                    
                    // Color legend
                    colorLegend
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Log")
            .sheet(isPresented: $showingStatusPicker) {
                statusPickerSheet
            }
        }
    }
    
    // MARK: - Month Header
    
    private var monthHeader: some View {
        HStack {
            Button(action: { changeMonth(by: -1) }) {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
                    .background(Color(.systemBackground))
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            }
            
            Spacer()
            
            Text(monthYearString(from: displayedMonth))
                .font(.system(.title3, design: .rounded, weight: .bold))
            
            Spacer()
            
            Button(action: { changeMonth(by: 1) }) {
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
                    .background(Color(.systemBackground))
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Day of Week Header
    
    private var dayOfWeekHeader: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(daysOfWeek, id: \.self) { day in
                Text(day)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }
    
    // MARK: - Calendar Grid
    
    private var calendarGrid: some View {
        let days = daysInMonth()
        
        return LazyVGrid(columns: columns, spacing: 4) {
            // Leading empty cells for offset
            ForEach(0..<startingWeekday(), id: \.self) { _ in
                Text("")
                    .frame(height: 48)
            }
            
            // Day cells
            ForEach(days, id: \.self) { date in
                dayCellView(for: date)
            }
        }
        .padding(.horizontal, 8)
    }
    
    // MARK: - Day Cell
    
    private func dayCellView(for date: Date) -> some View {
        let status = statusFor(date: date)
        let isToday = calendar.isDateInToday(date)
        let isSelected = selectedDate != nil && calendar.isDate(date, inSameDayAs: selectedDate!)
        
        return Button(action: {
            selectedDate = date
            showingStatusPicker = true
        }) {
            ZStack {
                // Background: soft gray for empty, solid color for status
                RoundedRectangle(cornerRadius: 12)
                    .fill(status == .none ? Color(.secondarySystemBackground) : status.color.opacity(0.9))
                
                // Selected highlight ring
                if isSelected {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.primary, lineWidth: 3)
                } else if isToday && status == .none {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.accentColor.opacity(0.5), lineWidth: 2)
                }
                
                // Day number
                VStack(spacing: 2) {
                    Text("\(calendar.component(.day, from: date))")
                        .font(.system(.callout, design: .rounded, weight: (status != .none || isSelected) ? .bold : .medium))
                        .foregroundColor(status != .none ? .white : (isToday ? .accentColor : .primary))
                    
                    // Tiny icon if status is set
                    if status != .none {
                        Image(systemName: status.icon)
                            .font(.system(size: 8))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
            }
            .frame(height: 48)
            .scaleEffect(isSelected ? 1.08 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Category Counts
    
    private var colorLegend: some View {
        let monthDays = daysInMonth()
        let legendColumns = [GridItem(.adaptive(minimum: 140, maximum: .infinity), spacing: 16)]
        
        return VStack(spacing: 16) {
            Text("Monthly Summary")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: legendColumns, alignment: .leading, spacing: 16) {
                ForEach(DayStatus.selectable) { status in
                    let count = monthDays.filter { statusFor(date: $0) == status }.count
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(status.color.gradient)
                            .frame(width: 36, height: 36)
                            .overlay(
                                Text("\(count)")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            )
                        Text(status.rawValue)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(14)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
        )
        .padding(.horizontal)
    }
    
    // MARK: - Status Picker Sheet
    
    private var statusPickerSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let date = selectedDate {
                    Text(date, style: .date)
                        .font(.title3.bold())
                        .padding(.top)
                    
                    ForEach(DayStatus.selectable) { status in
                        Button(action: {
                            saveEntry(date: date, status: status)
                            showingStatusPicker = false
                        }) {
                            HStack {
                                Image(systemName: status.icon)
                                    .font(.title3)
                                    .frame(width: 32)
                                
                                Text(status.rawValue)
                                    .font(.headline)
                                
                                Spacer()
                                
                                if statusFor(date: date) == status {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.white)
                                }
                            }
                            .padding()
                            .background(status.color.opacity(0.85))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }
                    
                    // Clear button
                    Button(action: {
                        clearEntry(date: date)
                        showingStatusPicker = false
                    }) {
                        HStack {
                            Image(systemName: "xmark.circle")
                                .font(.title3)
                                .frame(width: 32)
                            Text("Clear")
                                .font(.headline)
                            Spacer()
                        }
                        .padding()
                        .background(Color.gray.opacity(0.15))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                    }
                    
                    Spacer()
                }
            }
            .padding(.horizontal)
            .navigationTitle("Set Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingStatusPicker = false }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Helpers
    
    private func statusFor(date: Date) -> DayStatus {
        if let record = records.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
            return record.status
        }
        return .none
    }
    
    private func saveEntry(date: Date, status: DayStatus) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let dayDate = calendar.date(from: components) else { return }
        
        // Remove existing record for that day
        if let existing = records.first(where: { calendar.isDate($0.date, inSameDayAs: dayDate) }) {
            modelContext.delete(existing)
        }
        
        let newRecord = DayRecord(date: dayDate, status: status, isAutoDetected: false)
        modelContext.insert(newRecord)
    }
    
    private func clearEntry(date: Date) {
        if let existing = records.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
            modelContext.delete(existing)
        }
    }
    
    private func daysInMonth() -> [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))
        else { return [] }
        
        return range.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth)
        }
    }
    
    private func startingWeekday() -> Int {
        guard let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))
        else { return 0 }
        return calendar.component(.weekday, from: firstOfMonth) - 1
    }
    
    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }
    
    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
}
