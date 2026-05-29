import SwiftUI
import SwiftData

struct ContentView: View {
    @ObservedObject var locationManager: LocationManager
    @State private var navigationState = AppNavigationState()

    var body: some View {
        TabView(selection: Binding(
            get: { navigationState.selectedTab },
            set: { navigationState.selectedTab = $0 }
        )) {
            DashboardView()
                .tag(AppTab.dashboard)
                .tabItem {
                    Label("Dashboard", systemImage: "chart.pie")
                }

            CalendarView()
                .tag(AppTab.log)
                .tabItem {
                    Label("Log", systemImage: "calendar")
                }

            SettingsView(locationManager: locationManager)
                .tag(AppTab.settings)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .environment(navigationState)
        .onAppear {
            AppHaptics.prepare()
        }
    }
}

#Preview {
    if let container = try? ModelContainer(for: DayRecord.self) {
        ContentView(locationManager: LocationManager(modelContainer: container))
            .modelContainer(container)
            .environment(GoalManager())
    } else {
        ContentUnavailableView(
            "Preview unavailable",
            systemImage: "exclamationmark.triangle",
            description: Text("The sample data store couldn't be created.")
        )
    }
}
