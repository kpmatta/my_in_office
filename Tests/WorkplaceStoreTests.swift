import XCTest
@testable import InOffice

final class WorkplaceStoreTests: XCTestCase {
    func testMigratesLegacyDefaultsIntoKeychain() throws {
        let (store, keychain, userDefaults) = makeStore()
        userDefaults.set(40.7128, forKey: "officeLatitude")
        userDefaults.set(-74.0060, forKey: "officeLongitude")
        userDefaults.set("New York Office", forKey: "officeAddress")

        let workplace = store.migrateLegacyValuesIfNeeded()
        let coordinate = try XCTUnwrap(workplace.coordinate)
        let storedLatitude = try XCTUnwrap(keychain.string(for: "office.latitude").flatMap(Double.init))
        let storedLongitude = try XCTUnwrap(keychain.string(for: "office.longitude").flatMap(Double.init))

        XCTAssertEqual(coordinate.latitude, 40.7128, accuracy: 0.0001)
        XCTAssertEqual(coordinate.longitude, -74.0060, accuracy: 0.0001)
        XCTAssertEqual(workplace.address, "New York Office")
        XCTAssertNil(userDefaults.object(forKey: "officeLatitude"))
        XCTAssertNil(userDefaults.object(forKey: "officeLongitude"))
        XCTAssertNil(userDefaults.object(forKey: "officeAddress"))
        XCTAssertEqual(storedLatitude, 40.7128, accuracy: 0.0001)
        XCTAssertEqual(storedLongitude, -74.0060, accuracy: 0.0001)
        XCTAssertEqual(keychain.string(for: "office.address"), "New York Office")
    }

    func testExistingKeychainValuesWinAndLegacyDefaultsAreCleared() throws {
        let (store, keychain, userDefaults) = makeStore()
        _ = keychain.set("34.0522", for: "office.latitude")
        _ = keychain.set("-118.2437", for: "office.longitude")
        _ = keychain.set("Los Angeles Office", for: "office.address")

        userDefaults.set(51.5072, forKey: "officeLatitude")
        userDefaults.set(-0.1276, forKey: "officeLongitude")
        userDefaults.set("London Office", forKey: "officeAddress")

        let workplace = store.migrateLegacyValuesIfNeeded()
        let coordinate = try XCTUnwrap(workplace.coordinate)

        XCTAssertEqual(coordinate.latitude, 34.0522, accuracy: 0.0001)
        XCTAssertEqual(coordinate.longitude, -118.2437, accuracy: 0.0001)
        XCTAssertEqual(workplace.address, "Los Angeles Office")
        XCTAssertNil(userDefaults.object(forKey: "officeLatitude"))
        XCTAssertNil(userDefaults.object(forKey: "officeLongitude"))
        XCTAssertNil(userDefaults.object(forKey: "officeAddress"))
    }

    func testLoadWorkplaceReturnsEmptyWhenNothingStored() {
        let (store, _, _) = makeStore()
        let workplace = store.loadWorkplace()

        XCTAssertNil(workplace.coordinate)
        XCTAssertNil(workplace.address)
    }

    private func makeStore() -> (WorkplaceStore, KeychainStore, UserDefaults) {
        let identifier = UUID().uuidString
        let defaultsSuiteName = "InOfficeTests.\(identifier)"
        let serviceName = "InOfficeTests.\(identifier)"
        let userDefaults = UserDefaults(suiteName: defaultsSuiteName) ?? .standard
        userDefaults.removePersistentDomain(forName: defaultsSuiteName)

        let keychain = KeychainStore(service: serviceName)
        let store = WorkplaceStore(keychain: keychain, userDefaults: userDefaults)
        store.clearWorkplace()

        addTeardownBlock {
            store.clearWorkplace()
            userDefaults.removePersistentDomain(forName: defaultsSuiteName)
        }

        return (store, keychain, userDefaults)
    }
}
