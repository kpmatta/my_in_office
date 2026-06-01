import SwiftUI
import CoreLocation
import MapKit

struct SettingsView: View {
    @ObservedObject var locationManager: LocationManager
    @Environment(GoalManager.self) private var goalManager
    @Environment(AppNavigationState.self) private var navigationState
    @State private var showsBackupRecommendation = false
    @State private var backupFocusTask: Task<Void, Never>?

    var body: some View {
        NavigationView {
            ScrollViewReader { proxy in
                Form {
                    WorkplaceSettingsSection(locationManager: locationManager)

                    // MARK: - In-Office Goals
                    Section(header: goalSectionHeader()) {
                        // Yearly
                        GoalLockRow(
                            label: "Yearly Goal",
                            rawValue: Binding(
                                get: { goalManager.yearlyGoal },
                                set: { goalManager.yearlyGoal = $0 }
                            ),
                            effectiveValue: goalManager.staticYearlyGoal,
                            unit: "days",
                            range: 0...366,
                            isLocked: goalManager.lockMode == .yearly,
                            isDisabled: goalManager.lockMode != .none && goalManager.lockMode != .yearly,
                            onToggleLock: { toggleLock(.yearly) }
                        )

                        // Monthly
                        GoalLockRow(
                            label: "Monthly Goal",
                            rawValue: Binding(
                                get: { goalManager.monthlyGoal },
                                set: { goalManager.monthlyGoal = $0 }
                            ),
                            effectiveValue: goalManager.staticMonthlyGoal,
                            unit: "days",
                            range: 0...31,
                            isLocked: goalManager.lockMode == .monthly,
                            isDisabled: goalManager.lockMode != .none && goalManager.lockMode != .monthly,
                            onToggleLock: { toggleLock(.monthly) }
                        )

                        // Weekly
                        GoalLockRow(
                            label: "Weekly Goal",
                            rawValue: Binding(
                                get: { goalManager.weeklyGoal },
                                set: { goalManager.weeklyGoal = $0 }
                            ),
                            effectiveValue: goalManager.staticWeeklyGoal,
                            unit: "days",
                            range: 0...7,
                            isLocked: goalManager.lockMode == .weekly,
                            isDisabled: goalManager.lockMode != .none && goalManager.lockMode != .weekly,
                            onToggleLock: { toggleLock(.weekly) }
                        )

                        // Mode description
                        if goalManager.lockMode != .none {
                            HStack(spacing: 6) {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.accentColor)
                                    .font(.caption)
                                Text(lockModeDescription)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 4)
                        }
                    }
                    
                    DataManagementSection(
                        showsBackupRecommendation: showsBackupRecommendation,
                        onDismissBackupRecommendation: dismissBackupRecommendation
                    )
                        .id(SettingsFocus.backup)
                }
                .navigationTitle("Settings")
                .onChange(of: navigationState.settingsFocus, initial: true) { _, focus in
                    handleSettingsFocus(focus, proxy: proxy)
                }
            }
        }
        .onDisappear {
            backupFocusTask?.cancel()
            backupFocusTask = nil
        }
    }

    // MARK: - Helpers

    private func toggleLock(_ mode: GoalLockMode) {
        if goalManager.lockMode == mode {
            goalManager.lockMode = .none
        } else {
            goalManager.lockMode = mode
        }

        AppHaptics.emphasizedSelection()
    }

    private var lockModeDescription: String {
        switch goalManager.lockMode {
        case .none:    return ""
        case .weekly:  return "Monthly & yearly goals are derived from your weekly target."
        case .monthly: return "Weekly & yearly goals are derived from your monthly target."
        case .yearly:  return "Weekly & monthly goals are derived from your yearly target."
        }
    }

    private func goalSectionHeader() -> some View {
        HStack(spacing: 6) {
            Image(systemName: DayStatus.inOffice.icon)
                .foregroundColor(DayStatus.inOffice.color)
            Text("In-Office Goals")
                .foregroundColor(DayStatus.inOffice.color)
            Spacer()
            if goalManager.lockMode == .none {
                Text("Free Mode")
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray5))
                .clipShape(Capsule())
            }
        }
    }

    private func handleSettingsFocus(_ focus: SettingsFocus?, proxy: ScrollViewProxy) {
        guard focus == .backup else { return }

        backupFocusTask?.cancel()
        navigationState.clearSettingsFocus()

        backupFocusTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled else { return }

            withAnimation(.easeInOut(duration: 0.25)) {
                proxy.scrollTo(SettingsFocus.backup, anchor: .center)
                showsBackupRecommendation = true
            }
        }
    }

    private func dismissBackupRecommendation() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showsBackupRecommendation = false
        }
    }


}

// MARK: - GoalLockRow

struct GoalLockRow: View {
    let label: String
    @Binding var rawValue: Int
    let effectiveValue: Int
    let unit: String
    let range: ClosedRange<Int>
    let isLocked: Bool
    let isDisabled: Bool
    let onToggleLock: () -> Void

    private var displayValue: Int { isDisabled ? effectiveValue : rawValue }

    var body: some View {
        HStack(spacing: 8) {
            // Lock toggle button
            Button(action: onToggleLock) {
                Image(systemName: isLocked ? "lock.fill" : "lock.open")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isLocked ? .accentColor : Color(.tertiaryLabel))
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(isLocked ? Color.accentColor.opacity(0.12) : Color(.systemGray6))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isLocked ? "Unlock \(label)" : "Lock \(label)")

            Stepper(value: $rawValue, in: range) {
                HStack {
                    Text(label)
                        .foregroundColor(isDisabled ? .secondary : .primary)

                    Spacer()

                    Text("\(displayValue) \(unit)")
                        .foregroundColor(isDisabled ? .secondary : .primary)
                        .font(isDisabled ? .subheadline : .body)
                        .italic(isDisabled)
                }
            }
            .disabled(isDisabled)
        }
    }
}

// MARK: - LocationSearchViewModel

class LocationSearchViewModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var searchQuery = "" {
        didSet {
            if trimmedQuery.isEmpty {
                completions = []
                isSearching = false
                isSearchServiceUnavailable = false
            } else {
                isSearching = true
                isSearchServiceUnavailable = false
                completer.queryFragment = trimmedQuery
            }
        }
    }

    @Published var completions: [MKLocalSearchCompletion] = []
    @Published var isSearching = false
    @Published var isSearchServiceUnavailable = false
    @Published var activeAlert: AppAlertInfo?

    private let completer = MKLocalSearchCompleter()

    var trimmedQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var shouldShowNoResultsState: Bool {
        !trimmedQuery.isEmpty && completions.isEmpty && !isSearching && !isSearchServiceUnavailable
    }

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        isSearching = false
        isSearchServiceUnavailable = false
        activeAlert = nil
        self.completions = completer.results
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        AppDiagnostics.error("Location search suggestions failed", error: error)

        DispatchQueue.main.async {
            self.isSearching = false
            self.completions = []
            self.isSearchServiceUnavailable = true
            self.activeAlert = AppUserFeedback.locationSearchUnavailable
        }
    }

    func retrySearch() {
        guard !trimmedQuery.isEmpty else { return }

        activeAlert = nil
        isSearching = true
        isSearchServiceUnavailable = false
        completer.queryFragment = trimmedQuery
    }

    func geocodeCompletion(
        _ completion: MKLocalSearchCompletion,
        completionHandler: @escaping (Result<(CLLocationCoordinate2D, String), AppAlertInfo>) -> Void
    ) {
        let searchRequest = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: searchRequest)
        search.start { response, error in
            if let error {
                AppDiagnostics.error("Location selection lookup failed", error: error)
                DispatchQueue.main.async {
                    completionHandler(.failure(AppUserFeedback.locationSelectionUnavailable(for: error)))
                }
                return
            }

            guard let mapItem = response?.mapItems.first,
                  let coordinate = mapItem.placemark.location?.coordinate else {
                DispatchQueue.main.async {
                    completionHandler(.failure(AppUserFeedback.addressNotFound))
                }
                return
            }

            let placemark = mapItem.placemark
            let validName = mapItem.name ?? placemark.name ?? ""
            let displayString: String

            if !validName.isEmpty {
                displayString = validName
            } else {
                let street = placemark.thoroughfare ?? ""
                let city = placemark.locality ?? ""
                displayString = [street, city].filter { !$0.isEmpty }.joined(separator: ", ")
            }

            let finalAddress = displayString.isEmpty ? completion.title : displayString
            DispatchQueue.main.async {
                completionHandler(.success((coordinate, finalAddress)))
            }
        }
    }
}

// MARK: - LocationSearchView

struct LocationSearchView: View {
    @StateObject private var viewModel = LocationSearchViewModel()
    @Environment(\.dismiss) private var dismiss

    let onSelect: (CLLocationCoordinate2D, String) -> Void

    var body: some View {
        NavigationView {
            Group {
                if viewModel.trimmedQuery.isEmpty {
                    ContentUnavailableView(
                        "Search for a workplace",
                        systemImage: "mappin.and.ellipse",
                        description: Text("Enter an address or office name to choose your workplace.")
                    )
                } else if viewModel.isSearchServiceUnavailable {
                    ContentUnavailableView {
                        Label("Search is unavailable right now", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text("Check your connection, then try searching again.")
                    } actions: {
                        Button("Try Again") {
                            viewModel.retrySearch()
                        }
                    }
                } else if viewModel.isSearching && viewModel.completions.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Looking up places...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.shouldShowNoResultsState {
                    ContentUnavailableView.search(text: viewModel.trimmedQuery)
                } else {
                    List(viewModel.completions, id: \.self) { completion in
                        Button(action: {
                            selectCompletion(completion)
                        }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(completion.title)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                if !completion.subtitle.isEmpty {
                                    Text(completion.subtitle)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .searchable(text: $viewModel.searchQuery, prompt: "Search for address...")
            .navigationTitle("Find Workplace")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .alert(item: $viewModel.activeAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func selectCompletion(_ completion: MKLocalSearchCompletion) {
        viewModel.geocodeCompletion(completion) { result in
            switch result {
            case .success(let selection):
                let (coordinate, address) = selection
                onSelect(coordinate, address)
                dismiss()
            case .failure(let alert):
                viewModel.activeAlert = alert
                AppHaptics.error()
            }
        }
    }
}
