import SwiftUI
import SwiftData

struct CalendarView: View {
    @State private var displayedMonth = Date()
    @State private var selectedDate: Date? = nil
    @State private var showingStatusPicker = false
    @State private var batchManager = CalendarBatchEditManager()
    
    private let calendar = Calendar.current
    private let daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Month navigation header
                    monthHeader
                    
                    // Calendar Card & Legend & Data Wrapper
                    CalendarMonthDataView(
                        displayedMonth: displayedMonth,
                        selectedDate: $selectedDate,
                        showingStatusPicker: $showingStatusPicker,
                        batchManager: batchManager,
                        daysOfWeek: daysOfWeek,
                        columns: columns
                    )
                }
                .padding(.vertical)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 40)
                        .onEnded { value in
                            let horizontalDrag = value.translation.width
                            let verticalDrag = value.translation.height
                            
                            // Ensure it's mostly a horizontal swipe so vertical scrolling isn't hijacked
                            guard abs(horizontalDrag) > abs(verticalDrag) else { return }
                            
                            let threshold: CGFloat = 50
                            if horizontalDrag > threshold {
                                // Swipe right -> previous month
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    changeMonth(by: -1)
                                }
                            } else if horizontalDrag < -threshold {
                                // Swipe left -> next month
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    changeMonth(by: 1)
                                }
                            }
                        }
                )
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Log")
            // Sheet lives on the root NavigationView — never inside a ForEach or child
            // subview — so SwiftUI manages exactly one sheet instance and state changes
            // are never swallowed by subview recreation.
            .sheet(isPresented: $showingStatusPicker) {
                DayStatusPickerSheet(date: selectedDate ?? Date(), isPresented: $showingStatusPicker)
            }
            .overlay(alignment: .bottom) {
                if batchManager.isBatchEditMode {
                    CalendarBatchEditPanel(batchManager: batchManager)
                }
            }
        }
    }
    
    // MARK: - Month Header
    private var monthHeader: some View {
        VStack(spacing: 4) {
            HStack {
                Button(action: { 
                    withAnimation(.easeInOut(duration: 0.25)) {
                        changeMonth(by: -1)
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(8)
                        .contentShape(Rectangle())
                }
                
                Spacer()
                
                Text(monthYearString(from: displayedMonth))
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .id(displayedMonth)
                    .transition(.opacity)
                
                Spacer()
                
                Button(action: { 
                    withAnimation(.easeInOut(duration: 0.25)) {
                        changeMonth(by: 1)
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(8)
                        .contentShape(Rectangle())
                }
            }
            .padding(.horizontal, 24)
            
            HStack(spacing: 6) {
                ForEach(-2...2, id: \.self) { offset in
                    let isCurrent = offset == 0
                    let size: CGFloat = isCurrent ? 8 : (abs(offset) == 2 ? 4 : 6)
                    let opacity: Double = isCurrent ? 1.0 : (abs(offset) == 2 ? 0.3 : 0.6)
                    
                    Circle()
                        .fill(Color.primary)
                        .opacity(opacity)
                        .frame(width: size, height: size)
                }
            }
        }
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

// MARK: - Isolated Data View

struct CalendarMonthDataView: View {
    let displayedMonth: Date
    @Binding var selectedDate: Date?
    @Binding var showingStatusPicker: Bool
    var batchManager: CalendarBatchEditManager
    
    let daysOfWeek: [String]
    let columns: [GridItem]
    
    @Environment(\.modelContext) private var modelContext
    @Query private var records: [DayRecord]
    
    private let calendar = Calendar.current
    
    init(displayedMonth: Date, selectedDate: Binding<Date?>, showingStatusPicker: Binding<Bool>, batchManager: CalendarBatchEditManager, daysOfWeek: [String], columns: [GridItem]) {
        self.displayedMonth = displayedMonth
        self._selectedDate = selectedDate
        self._showingStatusPicker = showingStatusPicker
        self.batchManager = batchManager
        self.daysOfWeek = daysOfWeek
        self.columns = columns
        
        let cal = Calendar.current
        let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: displayedMonth))!
        let startOfNextMonth = cal.date(byAdding: .month, value: 1, to: startOfMonth)!
        
        // Dynamically bounding the Query strictly to the displayed month!
        _records = Query(
            filter: #Predicate<DayRecord> { record in
                record.date >= startOfMonth && record.date < startOfNextMonth
            },
            sort: \DayRecord.date,
            order: .reverse
        )
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Calendar Card
            VStack(spacing: 12) {
                HStack {
                    Spacer()
                    Button(action: {
                        if batchManager.isBatchEditMode {
                            batchManager.exitBatchMode()
                        } else {
                            batchManager.enterBatchMode()
                        }
                    }) {
                        Text(batchManager.isBatchEditMode ? "Cancel" : "Select")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                }
                
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
        // Sheet has been intentionally moved to the root NavigationView in CalendarView.
    }
    
    // MARK: - Subcomponents
    
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
    
    private func dayCellView(for date: Date) -> some View {
        let status = statusFor(date: date)
        let isToday = calendar.isDateInToday(date)
        let isSelected = selectedDate != nil && calendar.isDate(date, inSameDayAs: selectedDate!)
        let isBatchSelected = batchManager.isBatchEditMode && batchManager.selectedDates.contains(calendar.startOfDay(for: date))
        
        return ZStack {
            // Background: soft gray for empty, solid color for status
            RoundedRectangle(cornerRadius: 12)
                .fill(status == .none ? Color(.secondarySystemBackground) : status.color.opacity(0.9))
            
            // Selected highlight ring
            if isBatchSelected {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.blue, lineWidth: 3)
            } else if isSelected && !batchManager.isBatchEditMode {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.primary, lineWidth: 3)
            } else if isToday && status == .none {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.accentColor.opacity(0.5), lineWidth: 2)
            }
            
            // Day number
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(.callout, design: .rounded, weight: (status != .none || isSelected || isBatchSelected) ? .bold : .medium))
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
        // Ensures the full 48pt cell area (including empty padding) is tappable,
        // not just the text/icon pixels.
        .contentShape(Rectangle())
        .scaleEffect((isSelected || isBatchSelected) ? 1.08 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .animation(.easeInOut(duration: 0.15), value: isBatchSelected)
        .onTapGesture {
            if batchManager.isBatchEditMode {
                batchManager.toggleSelection(for: date)
            } else {
                selectedDate = date
                showingStatusPicker = true
            }
        }
        .onLongPressGesture(minimumDuration: 0.4) {
            if !batchManager.isBatchEditMode {
                batchManager.enterBatchMode(initialDate: date)
            }
        }
    }
    
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
    

    // MARK: - Helper Methods
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }
    
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
}

// MARK: - DayStatusPickerSheet
// Standalone sheet view with its own @Query so it can live on the root NavigationView
// without depending on CalendarMonthDataView's state or modelContext.

struct DayStatusPickerSheet: View {
    let date: Date
    @Binding var isPresented: Bool

    @Environment(\.modelContext) private var modelContext
    @Query private var records: [DayRecord]

    private let calendar = Calendar.current

    init(date: Date, isPresented: Binding<Bool>) {
        self.date = date
        self._isPresented = isPresented

        // Query only records that fall on this specific day.
        let start = Calendar.current.startOfDay(for: date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        _records = Query(
            filter: #Predicate<DayRecord> { record in
                record.date >= start && record.date < end
            }
        )
    }

    private var currentStatus: DayStatus {
        records.first?.status ?? .none
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                ForEach(DayStatus.selectable) { status in
                    Button(action: {
                        save(status: status)
                        isPresented = false
                    }) {
                        HStack {
                            Image(systemName: status.icon)
                                .font(.title3)
                                .frame(width: 32)
                            Text(status.rawValue)
                                .font(.headline)
                            Spacer()
                            if currentStatus == status {
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

                Button(action: {
                    clear()
                    isPresented = false
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
            .padding(.horizontal)
            .navigationTitle(formattedDate(date))
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }

    private func save(status: DayStatus) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let dayDate = calendar.date(from: components) else { return }
        records.forEach { modelContext.delete($0) }
        modelContext.insert(DayRecord(date: dayDate, status: status, isAutoDetected: false))
    }

    private func clear() {
        records.forEach { modelContext.delete($0) }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }
}

// MARK: - CalendarBatchEditPanel
struct CalendarBatchEditPanel: View {
    var batchManager: CalendarBatchEditManager
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("\(batchManager.selectedDates.count) Selected")
                    .font(.headline)
                Spacer()
                Button(action: { batchManager.exitBatchMode() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(DayStatus.selectable) { status in
                        Button(action: {
                            batchManager.applyStatus(status, context: modelContext)
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: status.icon)
                                    .font(.title3)
                                Text(status.rawValue)
                                    .font(.caption)
                            }
                            .frame(width: 70, height: 60)
                            .background(status.color.opacity(0.85))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }
                    
                    Button(action: {
                        batchManager.applyStatus(.none, context: modelContext)
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "xmark")
                                .font(.title3)
                            Text("Clear")
                                .font(.caption)
                        }
                        .frame(width: 70, height: 60)
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
        )
        .padding()
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(), value: batchManager.isBatchEditMode)
    }
}
