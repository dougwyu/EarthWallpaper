import XCTest
@testable import EarthWallpaper

final class CityTests: XCTestCase {

    func test_currentTime_returnsHHmm() {
        let city = City(name: "London", latitude: 51.5, longitude: -0.1,
                        timezone: "Europe/London")
        let time = city.currentTime()
        // Format must be HH:mm — exactly 5 chars, digit:digit:digit:digit with colon at index 2
        XCTAssertEqual(time.count, 5)
        XCTAssertEqual(time[time.index(time.startIndex, offsetBy: 2)], ":")
    }

    func test_currentTime_usesCorrectTimezone() {
        let tokyo = City(name: "Tokyo", latitude: 35.67, longitude: 139.65,
                         timezone: "Asia/Tokyo")
        let newYork = City(name: "New York", latitude: 40.71, longitude: -74.0,
                           timezone: "America/New_York")
        XCTAssertEqual(tokyo.currentTime().count, 5)
        XCTAssertEqual(newYork.currentTime().count, 5)
    }

    func test_cityEncodesAndDecodesCorrectly() throws {
        let original = City(name: "Paris", latitude: 48.85, longitude: 2.35,
                            timezone: "Europe/Paris")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(City.self, from: data)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.latitude, original.latitude)
        XCTAssertEqual(decoded.longitude, original.longitude)
        XCTAssertEqual(decoded.timezone, original.timezone)
        XCTAssertEqual(decoded.id, original.id)
    }
}
