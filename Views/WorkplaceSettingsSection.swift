import SwiftUI
import CoreLocation

struct WorkplaceSettingsSection: View {
    @ObservedObject var locationManager: LocationManager
    
    @State private var showingLocationSearch: Bool = false
    @State private var showSuccess: Bool = false
    
    var body: some View {
        Section(header: Text("Workplace Settings"), footer: Text("Set your office location and geofence radius for automatic tracking.")) {
            // MARK: - Current Workplace
            VStack(alignment: .leading, spacing: 4) {
                Text("Current Workplace")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                let currentAddress = locationManager.resolvedAddress ?? ""
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
            
            // MARK: - Geofence Radius
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Geofence Radius")
                    Spacer()
                    Text("\(Int(locationManager.officeRadius))m")
                        .foregroundColor(.secondary)
                }
                Slider(value: $locationManager.officeRadius, in: 50...500, step: 10)
            }
            .padding(.vertical, 4)
            
            // MARK: - Change Workplace
            Button(action: {
                showingLocationSearch = true
                AppHaptics.selection()
            }) {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text("Search for Workplace Address")
                }
            }
            
            Button(action: {
                showSuccess = false
                locationManager.setCurrentLocationAsOffice { result in
                    switch result {
                    case .success:
                        showSuccess = true
                        AppHaptics.success()
                    case .failure:
                        AppHaptics.error()
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
            
            if let message = locationManager.statusMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.footnote)
            }
            
            // MARK: - Status
            HStack {
                Text("Permission Status")
                Spacer()
                Text(authStatusText)
                    .foregroundColor(.secondary)
            }
            
            if locationManager.authorizationStatus == .notDetermined {
                Button("Request Permissions") {
                    locationManager.requestPermissions()
                    AppHaptics.selection()
                }
            }
            
            HStack {
                Text("Inside Geofence?")
                Spacer()
                Text(locationManager.isInsideOffice ? "Yes" : "No")
                    .foregroundColor(locationManager.isInsideOffice ? .green : .red)
            }
        }
        .sheet(isPresented: $showingLocationSearch) {
            LocationSearchView { coordinate, address in
                locationManager.setOfficeLocation(coordinate: coordinate, address: address)
                showSuccess = true
                AppHaptics.success()
            }
        }
        .alert(
            item: Binding(
                get: { locationManager.activeAlert },
                set: { locationManager.activeAlert = $0 }
            )
        ) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
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
