import Foundation
import CoreLocation
import Combine
import SwiftData
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    
    @Published var lastLocation: CLLocation?
    @Published var isInsideOffice: Bool = false
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isGeocoding: Bool = false
    @Published var geocodingError: String?
    @Published var resolvedAddress: String?
    @Published var isFetchingCurrentLocation: Bool = false
    private var locationCompletion: ((Bool, String?) -> Void)?
    
    // Default office coordinates (Example: Replace with user settings later)
    // 37.3346, -122.0090 is Apple Park in Cupertino
    @Published var officeCoordinate = CLLocationCoordinate2D(latitude: 37.3346, longitude: -122.0090)
    
    @Published var officeRadius: CLLocationDistance = {
        let stored = UserDefaults.standard.double(forKey: "officeRadius")
        return stored > 0 ? stored : 200.0
    }() {
        didSet {
            UserDefaults.standard.set(officeRadius, forKey: "officeRadius")
            if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
                setupGeofence(for: officeCoordinate)
            }
        }
    }
    
    private let geocoder = CLGeocoder()
    
    /// Geocode an address string and set up the geofence at the resolved location.
    func geocodeAddress(_ address: String, completion: ((Bool) -> Void)? = nil) {
        isGeocoding = true
        geocodingError = nil
        
        geocoder.geocodeAddressString(address) { [weak self] placemarks, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isGeocoding = false
                
                if let error = error {
                    self.geocodingError = error.localizedDescription
                    completion?(false)
                    return
                }
                
                guard let placemark = placemarks?.first,
                      let location = placemark.location else {
                    self.geocodingError = "No location found for this address."
                    completion?(false)
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
                
                // Persist the coordinates
                UserDefaults.standard.set(location.coordinate.latitude, forKey: "officeLatitude")
                UserDefaults.standard.set(location.coordinate.longitude, forKey: "officeLongitude")
                
                self.setupGeofence(for: location.coordinate)
                completion?(true)
            }
        }
    }
    
    /// Get the current location and reverse geocode it to set the office location.
    func setCurrentLocationAsOffice(completion: @escaping (Bool, String?) -> Void) {
        if authorizationStatus == .notDetermined {
            requestPermissions()
            geocodingError = "Please wait for permissions, then tap 'Current Location' again."
            completion(false, nil)
            return
        }
        
        isFetchingCurrentLocation = true
        geocodingError = nil
        locationCompletion = completion
        manager.requestLocation()
    }
    
    let modelContainer: ModelContainer
    
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        super.init()
        manager.delegate = self
        authorizationStatus = manager.authorizationStatus
    }
    
    func requestPermissions() {
        manager.requestAlwaysAuthorization()
    }
    
    func setupGeofence(for coordinate: CLLocationCoordinate2D) {
        self.officeCoordinate = coordinate
        
        let region = CLCircularRegion(center: coordinate, radius: officeRadius, identifier: "OfficeRegion")
        region.notifyOnEntry = true
        region.notifyOnExit = true
        
        manager.startMonitoring(for: region)
        manager.requestState(for: region)
    }
    
    func setOfficeLocation(coordinate: CLLocationCoordinate2D, address: String) {
        self.officeCoordinate = coordinate
        self.resolvedAddress = address
        
        UserDefaults.standard.set(coordinate.latitude, forKey: "officeLatitude")
        UserDefaults.standard.set(coordinate.longitude, forKey: "officeLongitude")
        
        setupGeofence(for: coordinate)
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
            setupGeofence(for: officeCoordinate)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if region.identifier == "OfficeRegion" {
            DispatchQueue.main.async {
                self.isInsideOffice = true
            }
            logInOfficeForToday()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        if region.identifier == "OfficeRegion" {
            DispatchQueue.main.async {
                self.isInsideOffice = false
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        if region.identifier == "OfficeRegion" {
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
                print("LocationManager Background Persistence Error: \(error.localizedDescription)")
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
                        var addressString = "Current Location (\(location.coordinate.latitude), \(location.coordinate.longitude))"
                        
                        if let error = error {
                            self.geocodingError = error.localizedDescription
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
                        
                        UserDefaults.standard.set(location.coordinate.latitude, forKey: "officeLatitude")
                        UserDefaults.standard.set(location.coordinate.longitude, forKey: "officeLongitude")
                        
                        self.setupGeofence(for: location.coordinate)
                        
                        self.locationCompletion?(true, addressString)
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
                self.geocodingError = "Failed to get location: \(error.localizedDescription)"
                self.locationCompletion?(false, nil)
                self.locationCompletion = nil
            }
        }
    }
}
