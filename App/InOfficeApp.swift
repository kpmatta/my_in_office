import SwiftUI
import SwiftData

@main
struct InOfficeApp: App {
    private let bootstrapResult: BootstrapResult
    
    init() {
        SensitiveDataMigration.runIfNeeded()

        let schema = Schema([
            DayRecord.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            self.bootstrapResult = .ready(container: container, launchAlert: nil)
        } catch {
            AppDiagnostics.error("Model container initialization failed", error: error)
            self.bootstrapResult = .failed(alert: AppUserFeedback.appStorageUnavailable)
        }
    }

    var body: some Scene {
        WindowGroup {
            switch bootstrapResult {
            case .ready(let container, let launchAlert):
                ConfiguredAppView(
                    container: container,
                    launchAlert: launchAlert
                )

            case .failed(let alert):
                AppLaunchFailureView(alert: alert)
            }
        }
    }
}

private enum BootstrapResult {
    case ready(container: ModelContainer, launchAlert: AppAlertInfo?)
    case failed(alert: AppAlertInfo)
}

private struct ConfiguredAppView: View {
    let container: ModelContainer
    @State private var activeAlert: AppAlertInfo?
    @StateObject private var locationManager: LocationManager
    @State private var goalManager: GoalManager

    init(container: ModelContainer, launchAlert: AppAlertInfo?) {
        self.container = container
        self._activeAlert = State(initialValue: launchAlert)
        self._locationManager = StateObject(wrappedValue: LocationManager(modelContainer: container))
        self._goalManager = State(initialValue: GoalManager())
    }

    var body: some View {
        ContentView(locationManager: locationManager)
            .modelContainer(container)
            .environment(goalManager)
            .alert(item: $activeAlert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("OK"))
                )
            }
    }
}

private struct AppLaunchFailureView: View {
    let alert: AppAlertInfo

    var body: some View {
        ContentUnavailableView {
            Label(alert.title, systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text(alert.message)
        }
    }
}
