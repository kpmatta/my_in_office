import SwiftUI
import SwiftData

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.pie")
                }
            
            CalendarView()
                .tabItem {
                    Label("Log", systemImage: "calendar")
                }
            
            SettingsView(locationManager: locationManager)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("EnteredOffice"))) { _ in
            logInOfficeForToday()
        }
    }
    
    private func logInOfficeForToday() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        let descriptor = FetchDescriptor<DayRecord>()
        do {
            let records = try modelContext.fetch(descriptor)
            if let existing = records.first(where: { calendar.isDate($0.date, inSameDayAs: today) }) {
                // Only overwrite if it's not already inOffice
                if existing.status != .inOffice {
                    existing.status = .inOffice
                    existing.isAutoDetected = true
                }
            } else {
                let newRecord = DayRecord(date: today, status: .inOffice, isAutoDetected: true)
                modelContext.insert(newRecord)
            }
        } catch {
            print("Failed to auto-log in-office time: \(error)")
        }
    }
}

#Preview {
    ContentView()
}
