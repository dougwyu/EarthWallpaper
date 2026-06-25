import XCTest
@testable import EarthWallpaper

final class XPlanetRunnerTests: XCTestCase {

    func test_markerLine_format() {
        let city = City(name: "Tokyo", latitude: 35.6762, longitude: 139.6503,
                        timezone: "Asia/Tokyo")
        let line = XPlanetRunner.markerLine(for: city)

        XCTAssertTrue(line.hasPrefix("35.6762 139.6503 "))
        XCTAssertTrue(line.contains("\"Tokyo "))
        let pattern = #""Tokyo \d{2}:\d{2}""#
        XCTAssertTrue(line.range(of: pattern, options: .regularExpression) != nil,
                      "Expected pattern '\(pattern)' in: \(line)")
    }

    func test_markerLine_escapesDoubleQuotesInName() {
        let city = City(name: "San \"Paolo\"", latitude: -23.55, longitude: -46.63,
                        timezone: "America/Sao_Paulo")
        let line = XPlanetRunner.markerLine(for: city)
        XCTAssertFalse(line.contains("\"San \"Paolo\""),
                       "Unescaped double-quotes in city name break xplanet's marker format")
        XCTAssertTrue(line.contains("San 'Paolo'"),
                      "Double-quotes in name should be replaced with apostrophes")
    }

    func test_writeMarkers_createsFile() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_markers_\(UUID().uuidString).txt")

        let cities = [
            City(name: "London", latitude: 51.5, longitude: -0.1, timezone: "Europe/London"),
            City(name: "Sydney", latitude: -33.87, longitude: 151.21, timezone: "Australia/Sydney")
        ]
        try XPlanetRunner.writeMarkers(cities: cities, to: tmp)

        let content = try String(contentsOf: tmp)
        XCTAssertTrue(content.contains("51.5"))
        XCTAssertTrue(content.contains("London"))
        XCTAssertTrue(content.contains("-33.87"))
        XCTAssertTrue(content.contains("Sydney"))

        try? FileManager.default.removeItem(at: tmp)
    }

    func test_writeMarkers_emptyCity_writesEmptyFile() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_empty_\(UUID().uuidString).txt")
        try XPlanetRunner.writeMarkers(cities: [], to: tmp)
        let content = try String(contentsOf: tmp)
        XCTAssertEqual(content, "")
        try? FileManager.default.removeItem(at: tmp)
    }
}
