import SwiftUI
import CoreLocation

struct SettingsView: View {
    @ObservedObject var locationManager: LocationManager
    @AppStorage("officeAddress") private var officeAddress: String = "One Apple Park Way, Cupertino, CA"
    
    // In-Office Goals
    @AppStorage("yearlyInOfficeGoal") private var yearlyInOfficeGoal: Int = 200
    @AppStorage("monthlyInOfficeGoal") private var monthlyInOfficeGoal: Int = 18
    @AppStorage("weeklyInOfficeGoal") private var weeklyInOfficeGoal: Int = 4
    
    @State private var addressInput: String = ""
    @State private var showSuccess: Bool = false
    
    var body: some View {
        NavigationView {
            Form {
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
                Section(header: Text("Work Location"), footer: Text("Enter your office address. It will be converted to a geofence location for automatic in-office tracking.")) {
                    TextField("Office Address", text: $addressInput)
                        .textContentType(.fullStreetAddress)
                        .autocorrectionDisabled(false)
                    
                    HStack {
                        Button(action: {
                            showSuccess = false
                            locationManager.geocodeAddress(addressInput) { success in
                                if success {
                                    officeAddress = addressInput
                                    showSuccess = true
                                }
                            }
                        }) {
                            HStack {
                                if locationManager.isGeocoding {
                                    ProgressView().padding(.trailing, 2)
                                }
                                Text("Set by Address")
                            }
                        }
                        .disabled(addressInput.trimmingCharacters(in: .whitespaces).isEmpty || locationManager.isGeocoding || locationManager.isFetchingCurrentLocation)
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        Button(action: {
                            showSuccess = false
                            locationManager.setCurrentLocationAsOffice { success, newAddress in
                                if success, let address = newAddress {
                                    addressInput = address
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
                                Text("Current")
                            }
                        }
                        .disabled(locationManager.isGeocoding || locationManager.isFetchingCurrentLocation)
                        .buttonStyle(.borderedProminent)
                    }
                    
                    // Current saved address
                    HStack {
                        Text("Current")
                        Spacer()
                        Text(locationManager.resolvedAddress ?? officeAddress)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                    
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
            .onAppear {
                if addressInput.isEmpty {
                    addressInput = officeAddress
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
