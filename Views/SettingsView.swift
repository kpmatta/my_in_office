import SwiftUI
import CoreLocation
import MapKit

struct SettingsView: View {
    @ObservedObject var locationManager: LocationManager
    @Environment(GoalManager.self) private var goalManager

    @AppStorage("officeAddress") private var officeAddress: String = "One Apple Park Way, Cupertino, CA"

    @State private var showSuccess: Bool = false
    @State private var showingLocationSearch: Bool = false

    var body: some View {
        NavigationView {
            Form {
                // MARK: - Current Workplace
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current Workplace")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        let currentAddress = locationManager.resolvedAddress ?? officeAddress
                        if currentAddress.isEmpty {
                            Text("No location set")
                                .font(.headline)
                                .foregroundColor(.gray)
                        } else {
                            Text(currentAddress)
                                .font(.headline)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // MARK: - In-Office Goals
                Section(header: goalSectionHeader()) {
                    // Yearly
                    GoalLockRow(
                        label: "Yearly Goal",
                        rawValue: Binding(
                            get: { goalManager.yearlyGoal },
                            set: { goalManager.yearlyGoal = $0 }
                        ),
                        effectiveValue: goalManager.effectiveYearlyGoal,
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
                        effectiveValue: goalManager.effectiveMonthlyGoal,
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
                        effectiveValue: goalManager.effectiveWeeklyGoal,
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

                // MARK: - Location Permissions
                Section(header: Text("Location Permissions")) {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(authStatusText)
                            .foregroundColor(.secondary)
                    }
                    Button("Request Permissions") {
                        locationManager.requestPermissions()
                    }
                }

                // MARK: - Work Location
                Section(header: Text("Work Location"), footer: Text("Search for your office address or use current GPS location for automatic in-office tracking.")) {

                    Button(action: {
                        showingLocationSearch = true
                    }) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text("Search for Workplace Address")
                        }
                    }

                    Button(action: {
                        showSuccess = false
                        locationManager.setCurrentLocationAsOffice { success, newAddress in
                            if success, let address = newAddress {
                                officeAddress = address
                                showSuccess = true
                            }
                        }
                    }) {
                        HStack {
                            if locationManager.isFetchingCurrentLocation {
                                ProgressView().padding(.trailing, 2)
                            } else {
                                Image(systemName: "location.fill")
                            }
                            Text("Use Current Location")
                        }
                    }
                    .disabled(locationManager.isFetchingCurrentLocation)

                    if showSuccess {
                        Label("Location updated successfully", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.footnote)
                    }

                    if let error = locationManager.geocodingError {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.footnote)
                    }
                }

                // MARK: - Background Status
                Section(header: Text("Background Status")) {
                    HStack {
                        Text("Inside Office Geofence?")
                        Spacer()
                        Text(locationManager.isInsideOffice ? "Yes" : "No")
                            .foregroundColor(locationManager.isInsideOffice ? .green : .red)
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingLocationSearch) {
                LocationSearchView { coordinate, address in
                    officeAddress = address
                    locationManager.setOfficeLocation(coordinate: coordinate, address: address)
                    showSuccess = true
                }
            }
        }
    }

    // MARK: - Helpers

    private func toggleLock(_ mode: GoalLockMode) {
        if goalManager.lockMode == mode {
            goalManager.lockMode = .none
        } else {
            goalManager.lockMode = mode
        }
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

    var authStatusText: String {
        switch locationManager.authorizationStatus {
        case .notDetermined: return "Not Determined"
        case .restricted:    return "Restricted"
        case .denied:        return "Denied"
        case .authorizedAlways:    return "Always"
        case .authorizedWhenInUse: return "When in Use"
        @unknown default:    return "Unknown"
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
            if searchQuery.isEmpty {
                completions = []
            } else {
                completer.queryFragment = searchQuery
            }
        }
    }

    @Published var completions: [MKLocalSearchCompletion] = []

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        self.completions = completer.results
    }

    func geocodeCompletion(_ completion: MKLocalSearchCompletion, completionHandler: @escaping (CLLocationCoordinate2D?, String?) -> Void) {
        let searchRequest = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: searchRequest)
        search.start { response, error in
            guard let mapItem = response?.mapItems.first,
                  let coordinate = mapItem.placemark.location?.coordinate else {
                completionHandler(nil, nil)
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
            completionHandler(coordinate, finalAddress)
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
    }

    private func selectCompletion(_ completion: MKLocalSearchCompletion) {
        viewModel.geocodeCompletion(completion) { coordinate, address in
            if let coordinate = coordinate, let address = address {
                onSelect(coordinate, address)
                dismiss()
            }
        }
    }
}
