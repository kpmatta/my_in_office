import SwiftUI
import CoreLocation

struct WorkplaceSettingsSection: View {
    @ObservedObject var locationManager: LocationManager
    @AppStorage("officeAddress") private var officeAddress: String = "One Apple Park Way, Cupertino, CA"
    
    @State private var showingLocationSearch: Bool = false
    @State private var showSuccess: Bool = false
    
    var body: some View {
        Section(header: Text("Workplace Settings"), footer: Text("Set your office location and geofence radius for automatic tracking.")) {
            // MARK: - Current Workplace
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
                officeAddress = address
                locationManager.setOfficeLocation(coordinate: coordinate, address: address)
                showSuccess = true
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
