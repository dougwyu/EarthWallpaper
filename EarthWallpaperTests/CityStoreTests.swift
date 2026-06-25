import XCTest
@testable import EarthWallpaper

final class CityStoreTests: XCTestCase {

    var store: CityStore!
    let testKey = "cities_test_\(UUID().uuidString)"

    override func setUp() {
        store = CityStore(userDefaultsKey: testKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: testKey)
    }

    func test_startsEmpty() {
        XCTAssertTrue(store.cities.isEmpty)
    }

    func test_addCity_appendsToList() {
        let city = City(name: "Berlin", latitude: 52.5, longitude: 13.4,
                        timezone: "Europe/Berlin")
        store.add(city)
        XCTAssertEqual(store.cities.count, 1)
        XCTAssertEqual(store.cities[0].name, "Berlin")
    }

    func test_removeCity_removesFromList() {
        let city = City(name: "Sydney", latitude: -33.87, longitude: 151.21,
                        timezone: "Australia/Sydney")
        store.add(city)
        store.remove(at: IndexSet(integer: 0))
        XCTAssertTrue(store.cities.isEmpty)
    }

    func test_persistsAndLoadsFromUserDefaults() {
        let city = City(name: "Cairo", latitude: 30.04, longitude: 31.24,
                        timezone: "Africa/Cairo")
        store.add(city)

        let reloaded = CityStore(userDefaultsKey: testKey)
        XCTAssertEqual(reloaded.cities.count, 1)
        XCTAssertEqual(reloaded.cities[0].name, "Cairo")
    }
}
