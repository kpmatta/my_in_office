import CoreLocation
import Foundation

struct StoredWorkplace {
    let coordinate: CLLocationCoordinate2D?
    let address: String?
}

final class WorkplaceStore {
    private static let officeLatitudeKey = "officeLatitude"
    private static let officeLongitudeKey = "officeLongitude"
    private static let officeAddressKey = "officeAddress"
    private static let officeLatitudeKeychainKey = "office.latitude"
    private static let officeLongitudeKeychainKey = "office.longitude"
    private static let officeAddressKeychainKey = "office.address"

    private let keychain: KeychainStore
    private let userDefaults: UserDefaults

    init(
        keychain: KeychainStore = KeychainStore(),
        userDefaults: UserDefaults = .standard
    ) {
        self.keychain = keychain
        self.userDefaults = userDefaults
    }

    @discardableResult
    func migrateLegacyValuesIfNeeded() -> StoredWorkplace {
        var stored = loadWorkplace()

        if stored.coordinate == nil {
            let latitude = userDefaults.double(forKey: Self.officeLatitudeKey)
            let longitude = userDefaults.double(forKey: Self.officeLongitudeKey)
            let hasStoredLatitude = userDefaults.object(forKey: Self.officeLatitudeKey) != nil
            let hasStoredLongitude = userDefaults.object(forKey: Self.officeLongitudeKey) != nil

            if hasStoredLatitude, hasStoredLongitude {
                let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                if saveCoordinate(coordinate) {
                    userDefaults.removeObject(forKey: Self.officeLatitudeKey)
                    userDefaults.removeObject(forKey: Self.officeLongitudeKey)
                    stored = StoredWorkplace(coordinate: coordinate, address: stored.address)
                }
            }
        } else {
            userDefaults.removeObject(forKey: Self.officeLatitudeKey)
            userDefaults.removeObject(forKey: Self.officeLongitudeKey)
        }

        if stored.address == nil,
           let legacyAddress = userDefaults.string(forKey: Self.officeAddressKey),
           saveAddress(legacyAddress) {
            userDefaults.removeObject(forKey: Self.officeAddressKey)
            stored = StoredWorkplace(coordinate: stored.coordinate, address: legacyAddress)
        } else if stored.address != nil {
            userDefaults.removeObject(forKey: Self.officeAddressKey)
        }

        return stored
    }

    func loadWorkplace() -> StoredWorkplace {
        StoredWorkplace(
            coordinate: loadStoredOfficeCoordinate(),
            address: loadStoredOfficeAddress()
        )
    }

    @discardableResult
    func saveCoordinate(_ coordinate: CLLocationCoordinate2D) -> Bool {
        let latitudeStatus = keychain.set(
            String(coordinate.latitude),
            for: Self.officeLatitudeKeychainKey
        )
        let longitudeStatus = keychain.set(
            String(coordinate.longitude),
            for: Self.officeLongitudeKeychainKey
        )

        let didSave = latitudeStatus == errSecSuccess && longitudeStatus == errSecSuccess
        if !didSave {
            AppDiagnostics.error("Saving office coordinate to Keychain failed")
        }
        return didSave
    }

    @discardableResult
    func saveAddress(_ address: String) -> Bool {
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAddress.isEmpty else {
            return false
        }

        let status = keychain.set(trimmedAddress, for: Self.officeAddressKeychainKey)
        if status != errSecSuccess {
            AppDiagnostics.error("Saving office address to Keychain failed")
        }
        return status == errSecSuccess
    }

    func clearWorkplace() {
        _ = keychain.deleteValue(for: Self.officeLatitudeKeychainKey)
        _ = keychain.deleteValue(for: Self.officeLongitudeKeychainKey)
        _ = keychain.deleteValue(for: Self.officeAddressKeychainKey)
        userDefaults.removeObject(forKey: Self.officeLatitudeKey)
        userDefaults.removeObject(forKey: Self.officeLongitudeKey)
        userDefaults.removeObject(forKey: Self.officeAddressKey)
    }

    private func loadStoredOfficeCoordinate() -> CLLocationCoordinate2D? {
        guard let latString = keychain.string(for: Self.officeLatitudeKeychainKey),
              let lonString = keychain.string(for: Self.officeLongitudeKeychainKey),
              let latitude = Double(latString),
              let longitude = Double(lonString) else {
            return nil
        }

        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private func loadStoredOfficeAddress() -> String? {
        keychain.string(for: Self.officeAddressKeychainKey)
    }
}
