import SwiftUI
import CoreLocation
import MapKit

struct SettingsView: View {
    @ObservedObject var locationManager: LocationManager
    @AppStorage("officeAddress") private var officeAddress: String = "One Apple Park Way, Cupertino, CA"
    
    // In-Office Goals
    @AppStorage("yearlyInOfficeGoal") private var yearlyInOfficeGoal: Int = 200
    @AppStorage("monthlyInOfficeGoal") private var monthlyInOfficeGoal: Int = 18
    @AppStorage("weeklyInOfficeGoal") private var weeklyInOfficeGoal: Int = 4
    
    @State private var addressInput: String = ""
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
                    GoalRow(label: "Yearly Goal", value: $yearlyInOfficeGoal)
                    GoalRow(label: "Monthly Goal", value: $monthlyInOfficeGoal)
                    GoalRow(label: "Weekly Goal", value: $weeklyInOfficeGoal)
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
                    
                    // Success feedback
                    if showSuccess {
                        Label("Location updated successfully", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.footnote)
                    }
                    
                    // Error feedback
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
    
    private func goalSectionHeader() -> some View {
        HStack(spacing: 6) {
            Image(systemName: DayStatus.inOffice.icon)
                .foregroundColor(DayStatus.inOffice.color)
            Text("In-Office Goals")
                .foregroundColor(DayStatus.inOffice.color)
        }
    }
    
    var authStatusText: String {
        switch locationManager.authorizationStatus {
        case .notDetermined: return "Not Determined"
        case .restricted: return "Restricted"
        case .denied: return "Denied"
        case .authorizedAlways: return "Always"
        case .authorizedWhenInUse: return "When in Use"
        @unknown default: return "Unknown"
        }
    }
}

struct GoalRow: View {
    let label: String
    @Binding var value: Int
    
    var body: some View {
        Stepper(value: $value, in: 0...365) {
            HStack {
                Text(label)
                Spacer()
                Text("\(value) days")
                    .foregroundColor(.secondary)
            }
        }
    }
}
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

struct LocationSearchView: View {
    @StateObject private var viewModel = LocationSearchViewModel()
    @Environment(\.dismiss) private var dismiss
    
    // Callback when a location is successfully geocoded
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
