import Foundation
import CoreLocation
import Combine
import SwiftData

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let workplaceStore: WorkplaceStore
    private static let officeRegionIdentifier = "OfficeRegion"
    private static let officeRadiusKey = "officeRadius"
    
    @Published var lastLocation: CLLocation?
    @Published var isInsideOffice: Bool = false
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isGeocoding: Bool = false
    @Published var statusMessage: String?
    @Published var activeAlert: AppAlertInfo?
    @Published var resolvedAddress: String?
    @Published var isFetchingCurrentLocation: Bool = false
    private var locationCompletion: ((Result<String, AppAlertInfo>) -> Void)?
    
    @Published var officeCoordinate: CLLocationCoordinate2D?
    
    @Published var officeRadius: CLLocationDistance = {
        let stored = UserDefaults.standard.double(forKey: LocationManager.officeRadiusKey)
        return stored > 0 ? stored : 200.0
    }() {
        didSet {
            UserDefaults.standard.set(officeRadius, forKey: Self.officeRadiusKey)
            if (authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse),
               let officeCoordinate {
                setupGeofence(for: officeCoordinate)
            }
        }
    }
    
    private let geocoder = CLGeocoder()
    
    /// Geocode an address string and set up the geofence at the resolved location.
    func geocodeAddress(_ address: String, completion: ((Result<Void, AppAlertInfo>) -> Void)? = nil) {
        isGeocoding = true
        clearStatusMessage()
        
        geocoder.geocodeAddressString(address) { [weak self] placemarks, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isGeocoding = false
                
                if let error = error {
                    AppDiagnostics.error("Address lookup failed", error: error)
                    let alert = AppUserFeedback.addressLookupUnavailable(for: error)
                    self.presentIssue(alert)
                    completion?(.failure(alert))
                    return
                }
                
                guard let placemark = placemarks?.first,
                      let location = placemark.location else {
                    let alert = AppUserFeedback.addressNotFound
                    self.presentIssue(alert)
                    completion?(.failure(alert))
                    return
                }
                
                // Format a human-readable resolved address
                let parts = [
                    placemark.name,
                    placemark.locality,
                    placemark.administrativeArea,
                    placemark.postalCode
                ].compactMap { $0 }
                self.resolvedAddress = parts.joined(separator: ", ")
                
                // Persist the coordinates and address
                self.workplaceStore.saveCoordinate(location.coordinate)
                if let resolved = self.resolvedAddress {
                    self.workplaceStore.saveAddress(resolved)
                }
                
                self.setupGeofence(for: location.coordinate)
                self.clearStatusMessage()
                completion?(.success(()))
            }
        }
    }
    
    /// Get the current location and reverse geocode it to set the office location.
    func setCurrentLocationAsOffice(completion: @escaping (Result<String, AppAlertInfo>) -> Void) {
        if authorizationStatus == .notDetermined {
            requestPermissions()
            let alert = AppUserFeedback.locationPermissionNeeded
            statusMessage = alert.message
            completion(.failure(alert))
            return
        }

        if authorizationStatus == .denied || authorizationStatus == .restricted {
            let alert = AppUserFeedback.locationPermissionDenied
            presentIssue(alert)
            completion(.failure(alert))
            return
        }
        
        isFetchingCurrentLocation = true
        clearStatusMessage()
        locationCompletion = completion
        manager.requestLocation()
    }
    
    let modelContainer: ModelContainer
    
    init(
        modelContainer: ModelContainer,
        workplaceStore: WorkplaceStore = WorkplaceStore()
    ) {
        self.modelContainer = modelContainer
        self.workplaceStore = workplaceStore
        super.init()
        manager.delegate = self
        authorizationStatus = manager.authorizationStatus
        let storedWorkplace = workplaceStore.migrateLegacyValuesIfNeeded()
        officeCoordinate = storedWorkplace.coordinate
        resolvedAddress = storedWorkplace.address
    }
    
    func requestPermissions() {
        manager.requestAlwaysAuthorization()
    }
    
    func setupGeofence(for coordinate: CLLocationCoordinate2D) {
        self.officeCoordinate = coordinate

        manager.monitoredRegions
            .filter { $0.identifier == Self.officeRegionIdentifier }
            .forEach { manager.stopMonitoring(for: $0) }
        
        let region = CLCircularRegion(center: coordinate, radius: officeRadius, identifier: Self.officeRegionIdentifier)
        region.notifyOnEntry = true
        region.notifyOnExit = true
        
        manager.startMonitoring(for: region)
        manager.requestState(for: region)
    }
    
    func setOfficeLocation(coordinate: CLLocationCoordinate2D, address: String) {
        self.officeCoordinate = coordinate
        self.resolvedAddress = address
        clearStatusMessage()
        
        workplaceStore.saveCoordinate(coordinate)
        workplaceStore.saveAddress(address)
        
        setupGeofence(for: coordinate)
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
            clearStatusMessage()
            if let officeCoordinate {
                setupGeofence(for: officeCoordinate)
            }
        } else if authorizationStatus == .denied || authorizationStatus == .restricted {
            statusMessage = AppUserFeedback.locationPermissionDenied.message
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if region.identifier == Self.officeRegionIdentifier {
            DispatchQueue.main.async {
                self.isInsideOffice = true
            }
            logInOfficeForToday()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        if region.identifier == Self.officeRegionIdentifier {
            DispatchQueue.main.async {
                self.isInsideOffice = false
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        if region.identifier == Self.officeRegionIdentifier {
            let isNowInside = (state == .inside)
            
            DispatchQueue.main.async {
                self.isInsideOffice = isNowInside
            }
            
            if isNowInside {
                logInOfficeForToday()
            }
        }
    }
    
    private func logInOfficeForToday() {
        Task {
            let context = ModelContext(modelContainer)
            let calendar = Calendar.current
            let todayDate = Date()
            let todayStart = calendar.startOfDay(for: todayDate)
            guard let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart) else { return }
            
            var descriptor = FetchDescriptor<DayRecord>(
                predicate: #Predicate { $0.date >= todayStart && $0.date < tomorrowStart }
            )
            descriptor.fetchLimit = 1
            
            do {
                let records = try context.fetch(descriptor)
                if let existing = records.first {
                    if existing.statusRaw != DayStatus.inOffice.rawValue {
                        existing.statusRaw = DayStatus.inOffice.rawValue
                        existing.isAutoDetected = true
                        try context.save()
                    }
                } else {
                    let newRecord = DayRecord(date: todayStart, status: .inOffice, isAutoDetected: true)
                    context.insert(newRecord)
                    try context.save()
                }
            } catch {
                AppDiagnostics.error("Automatic office logging failed", error: error)
                await MainActor.run {
                    self.statusMessage = AppUserFeedback.autoLogFallbackNotice
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            self.lastLocation = location
            
            if isFetchingCurrentLocation {
                isFetchingCurrentLocation = false
                
                geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        var addressString = self.resolvedAddress ?? "Current Location"
                        
                        if let error = error {
                            AppDiagnostics.error("Reverse geocoding current location failed", error: error)
                            self.statusMessage = AppUserFeedback.addressFallbackNotice
                        } else if let placemark = placemarks?.first {
                            let parts = [
                                placemark.name,
                                placemark.locality,
                                placemark.administrativeArea,
                                placemark.postalCode
                            ].compactMap { $0 }
                            addressString = parts.joined(separator: ", ")
                            self.resolvedAddress = addressString
                        }

                        self.workplaceStore.saveCoordinate(location.coordinate)
                        self.workplaceStore.saveAddress(addressString)
                        
                        self.setupGeofence(for: location.coordinate)
                        
                        self.locationCompletion?(.success(addressString))
                        self.locationCompletion = nil
                    }
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if isFetchingCurrentLocation {
            DispatchQueue.main.async {
                self.isFetchingCurrentLocation = false
                AppDiagnostics.error("Current location request failed", error: error)
                let alert = AppUserFeedback.currentLocationUnavailable(for: error)
                self.presentIssue(alert)
                self.locationCompletion?(.failure(alert))
                self.locationCompletion = nil
            }
        }
    }

    private func presentIssue(_ alert: AppAlertInfo) {
        statusMessage = alert.message
        activeAlert = alert
    }

    private func clearStatusMessage() {
        statusMessage = nil
        activeAlert = nil
    }

    func clearStoredOfficeData() {
        workplaceStore.clearWorkplace()
        resolvedAddress = nil
        officeCoordinate = nil
        isInsideOffice = false

        manager.monitoredRegions
            .filter { $0.identifier == Self.officeRegionIdentifier }
            .forEach { manager.stopMonitoring(for: $0) }
    }
}
