import XCTest
@testable import EarthWallpaper

final class CityTests: XCTestCase {

    func test_currentTime_returnsHHmm() {
        let city = City(name: "London", latitude: 51.5, longitude: -0.1,
                        timezone: "Europe/London")
        // Use a fixed date so the test is deterministic
        var components = DateComponents()
        components.year = 2024; components.month = 6; components.day = 15
        components.hour = 14; components.minute = 30; components.second = 0
        components.timeZone = TimeZone(identifier: "Europe/London")
        let fixedDate = Calendar.current.date(from: components)!

        let time = city.currentTime(for: fixedDate)
        XCTAssertEqual(time, "14:30")
        XCTAssertEqual(time.count, 5)
        XCTAssertEqual(time[time.index(time.startIndex, offsetBy: 2)], ":")
    }

    func test_currentTime_usesCorrectTimezone() {
        // Use a fixed date: 2024-01-15 12:00:00 UTC
        // Tokyo (UTC+9) → 21:00, New York (UTC-5) → 07:00
        var components = DateComponents()
        components.year = 2024; components.month = 1; components.day = 15
        components.hour = 12; components.minute = 0; components.second = 0
        components.timeZone = TimeZone(identifier: "UTC")
        let fixedDate = Calendar.current.date(from: components)!

        let tokyo = City(name: "Tokyo", latitude: 35.67, longitude: 139.65,
                         timezone: "Asia/Tokyo")
        let newYork = City(name: "New York", latitude: 40.71, longitude: -74.0,
                           timezone: "America/New_York")

        XCTAssertEqual(tokyo.currentTime(for: fixedDate), "21:00")
        XCTAssertEqual(newYork.currentTime(for: fixedDate), "07:00")
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
