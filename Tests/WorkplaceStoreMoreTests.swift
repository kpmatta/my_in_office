import XCTest
import CoreLocation
@testable import InOffice

final class WorkplaceStoreMoreTests: XCTestCase {
    func testSaveAddressTrimsAndRejectsEmpty() {
        let (store, keychain, _) = makeStore()

        XCTAssertFalse(store.saveAddress("   "))
        XCTAssertNil(keychain.string(for: "office.address"))

        XCTAssertTrue(store.saveAddress("  My Office  "))
        XCTAssertEqual(keychain.string(for: "office.address"), "My Office")
    }

    func testSaveCoordinateAndLoadRoundTrip() throws {
        let (store, _, _) = makeStore()

        let coordinate = CLLocationCoordinate2D(latitude: 37.3318, longitude: -122.0312)
        XCTAssertTrue(store.saveCoordinate(coordinate))

        let loaded = store.loadWorkplace()
        let loadedCoordinate = try XCTUnwrap(loaded.coordinate)
        XCTAssertEqual(loadedCoordinate.latitude, 37.3318, accuracy: 0.0001)
        XCTAssertEqual(loadedCoordinate.longitude, -122.0312, accuracy: 0.0001)
    }

    func testClearWorkplaceRemovesAllValues() {
        let (store, keychain, userDefaults) = makeStore()
        userDefaults.set(1.0, forKey: "officeLatitude")
        userDefaults.set(2.0, forKey: "officeLongitude")
        userDefaults.set("Legacy", forKey: "officeAddress")
        _ = keychain.set("1.0", for: "office.latitude")
        _ = keychain.set("2.0", for: "office.longitude")
        _ = keychain.set("Office", for: "office.address")

        store.clearWorkplace()

        XCTAssertNil(userDefaults.object(forKey: "officeLatitude"))
        XCTAssertNil(userDefaults.object(forKey: "officeLongitude"))
        XCTAssertNil(userDefaults.object(forKey: "officeAddress"))
        XCTAssertNil(keychain.string(for: "office.latitude"))
        XCTAssertNil(keychain.string(for: "office.longitude"))
        XCTAssertNil(keychain.string(for: "office.address"))
    }

    private func makeStore() -> (WorkplaceStore, KeychainStore, UserDefaults) {
        let identifier = UUID().uuidString
        let defaultsSuiteName = "InOfficeTests.WorkplaceMore.\(identifier)"
        let serviceName = "InOfficeTests.WorkplaceMore.\(identifier)"
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
