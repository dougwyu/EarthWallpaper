import AppKit
import Foundation

enum XPlanetError: LocalizedError {
    case binaryNotFound
    case processFailed(String)

    var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            return "xplanet not found. Install it with: brew install xplanet"
        case .processFailed(let msg):
            return "xplanet failed: \(msg)"
        }
    }
}

struct XPlanetRunner {

    // MARK: - Paths

    private static func supportDir() throws -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("EarthWallpaper")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func xplanetPath() -> String? {
        ["/opt/homebrew/bin/xplanet", "/usr/local/bin/xplanet"]
            .first { FileManager.default.fileExists(atPath: $0) }
    }

    // MARK: - Marker file

    static func markerLine(for city: City) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: city.timezone) ?? .current
        let time = formatter.string(from: Date())
        // Replace any double-quotes in name to avoid breaking the marker file format
        let safeName = city.name.replacingOccurrences(of: "\"", with: "'")
        return "\(city.latitude) \(city.longitude) \"\(safeName) \(time)\" color=white fontsize=14"
    }

    static func writeMarkers(cities: [City], to url: URL) throws {
        let content = cities.map { markerLine(for: $0) }.joined(separator: "\n")
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Run (added in Task 6)
}
