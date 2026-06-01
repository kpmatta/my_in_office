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
    @Environment(\.scenePhase) private var scenePhase

    let container: ModelContainer
    private let backupReminderManager = BackupReminderManager()

    @State private var activeAlert: AppAlertInfo?
    @StateObject private var locationManager: LocationManager
    @State private var goalManager: GoalManager
    @State private var navigationState = AppNavigationState()
    @State private var activeBackupReminder: BackupReminderPresentation?
    @State private var isShowingBackupReminder = false
    @State private var handledBackupReminder = false

    init(container: ModelContainer, launchAlert: AppAlertInfo?) {
        self.container = container
        self._activeAlert = State(initialValue: launchAlert)
        self._locationManager = StateObject(wrappedValue: LocationManager(modelContainer: container))
        self._goalManager = State(initialValue: GoalManager())
    }

    var body: some View {
        ContentView(locationManager: locationManager)
            .modelContainer(container)
            .environment(navigationState)
            .environment(goalManager)
            .alert(item: $activeAlert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("OK"))
                )
            }
            .sheet(isPresented: $isShowingBackupReminder, onDismiss: handleBackupReminderDismissed) {
                if activeBackupReminder != nil {
                    BackupReminderSheet(
                        onOpenSettings: openBackupSettings,
                        onDismissForNow: dismissBackupReminderForNow,
                        onNeverRemindMe: disableBackupReminders
                    )
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                }
            }
            .onAppear {
                evaluateBackupReminderIfNeeded()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    evaluateBackupReminderIfNeeded()
                }
            }
    }

    private func evaluateBackupReminderIfNeeded() {
        guard !isShowingBackupReminder, activeBackupReminder == nil else { return }
        guard let hasRecords = hasStoredRecords() else { return }
        guard let reminder = backupReminderManager.reminderToPresent(hasRecords: hasRecords) else { return }

        handledBackupReminder = false
        activeBackupReminder = reminder
        isShowingBackupReminder = true
    }

    private func hasStoredRecords() -> Bool? {
        var descriptor = FetchDescriptor<DayRecord>(sortBy: [SortDescriptor(\DayRecord.date, order: .reverse)])
        descriptor.fetchLimit = 1

        do {
            let context = ModelContext(container)
            return try !context.fetch(descriptor).isEmpty
        } catch {
            AppDiagnostics.error("Backup reminder record check failed", error: error)
            return nil
        }
    }

    private func openBackupSettings() {
        guard let reminder = activeBackupReminder else { return }

        backupReminderManager.markReminderHandled(reminder)
        handledBackupReminder = true
        navigationState.showBackupExportFlow()
        isShowingBackupReminder = false
    }

    private func dismissBackupReminderForNow() {
        guard let reminder = activeBackupReminder else { return }

        backupReminderManager.markReminderHandled(reminder)
        handledBackupReminder = true
        isShowingBackupReminder = false
    }

    private func disableBackupReminders() {
        handledBackupReminder = true
        backupReminderManager.disableReminders()
        isShowingBackupReminder = false
    }

    private func handleBackupReminderDismissed() {
        if let reminder = activeBackupReminder, !handledBackupReminder {
            backupReminderManager.markReminderHandled(reminder)
        }

        activeBackupReminder = nil
        handledBackupReminder = false
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
