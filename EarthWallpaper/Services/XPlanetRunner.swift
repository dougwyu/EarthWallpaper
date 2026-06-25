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

    static func markerLine(for city: City, date: Date = Date()) -> String {
        let time = city.currentTime(for: date)
        // Replace any double-quotes in name to avoid breaking the marker file format
        let safeName = city.name.replacingOccurrences(of: "\"", with: "'")
        return "\(city.latitude) \(city.longitude) \"\(safeName) \(time)\" color=white fontsize=14"
    }

    static func writeMarkers(cities: [City], to url: URL) throws {
        let content = cities.map { markerLine(for: $0) }.joined(separator: "\n")
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Run

    static func run(cities: [City]) throws {
        guard let binaryPath = xplanetPath() else {
            throw XPlanetError.binaryNotFound
        }

        let dir = try supportDir()
        let outputURL = dir.appendingPathComponent("earth.png")
        let markersURL = dir.appendingPathComponent("markers.txt")

        try writeMarkers(cities: cities, to: markersURL)

        // NSScreen must be accessed on the main thread
        var w = 2560
        var h = 1440
        if Thread.isMainThread {
            let screen = NSScreen.main ?? NSScreen.screens[0]
            let scale = screen.backingScaleFactor
            w = Int(screen.frame.width * scale)
            h = Int(screen.frame.height * scale)
        } else {
            DispatchQueue.main.sync {
                let screen = NSScreen.main ?? NSScreen.screens[0]
                let scale = screen.backingScaleFactor
                w = Int(screen.frame.width * scale)
                h = Int(screen.frame.height * scale)
            }
        }

        var args = [
            "-num_times", "1",
            "-body", "earth",
            "-projection", "rectangular",
            "-geometry", "\(w)x\(h)",
            "-output", outputURL.path
        ]
        if !cities.isEmpty {
            args += ["-markerfile", markersURL.path]
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = args

        let errorPipe = Pipe()
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let msg = String(data: data, encoding: .utf8) ?? "exit code \(process.terminationStatus)"
            throw XPlanetError.processFailed(msg)
        }

        setWallpaper(imageURL: outputURL)
    }

    static func setWallpaper(imageURL: URL) {
        let block = {
            for screen in NSScreen.screens {
                try? NSWorkspace.shared.setDesktopImageURL(imageURL, for: screen, options: [:])
            }
        }
        if Thread.isMainThread { block() } else { DispatchQueue.main.sync { block() } }
    }
}
