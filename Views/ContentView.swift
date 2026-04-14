import SwiftUI
import SwiftData

struct ContentView: View {
    @ObservedObject var locationManager: LocationManager
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
    }
}

#Preview {
    ContentView(locationManager: LocationManager(modelContainer: try! ModelContainer(for: DayRecord.self)))
}
