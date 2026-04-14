import SwiftUI
import SwiftData

@main
struct InOfficeApp: App {
    let sharedModelContainer: ModelContainer
    @StateObject private var locationManager: LocationManager
    
    init() {
        let schema = Schema([
            DayRecord.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            self.sharedModelContainer = container
            self._locationManager = StateObject(wrappedValue: LocationManager(modelContainer: container))
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(locationManager: locationManager)
        }
        .modelContainer(sharedModelContainer)
    }
}
