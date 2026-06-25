import AppKit
import CoreText
import Foundation
import UniformTypeIdentifiers

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

    // MARK: - Coordinate mapping

    // xplanet's rectangular projection stretches the full equirectangular map
    // to fill the entire output frame (longitude -180..+180 across the full
    // width, latitude +90..-90 down the full height). The uniform bright/dark
    // rows at the very top and bottom are the polar regions (Arctic ice /
    // Antarctic interior), which are real map content — NOT letterbox fill, so
    // no aspect-ratio correction is needed. Verified empirically by rendering a
    // coordinate grid and checking known cities (London, Shanghai) land exactly.
    //
    // CGContext has y=0 at the bottom, so we flip: cg_y = height - image_y.
    static func pixelPosition(latitude: Double, longitude: Double, size: CGSize) -> CGPoint {
        let x = CGFloat((longitude + 180.0) / 360.0) * size.width
        let imageY = CGFloat((90.0 - latitude) / 180.0) * size.height
        let y = size.height - imageY   // flip for CGContext
        return CGPoint(x: x, y: y)
    }

    // MARK: - Core Graphics annotation

    // Draws city dots and time labels onto the xplanet base image.
    // Runs on whatever thread calls it — uses only CGContext and Core Text (thread-safe).
    static func annotateImage(at url: URL, with cities: [City]) throws -> URL {
        guard let dataProvider = CGDataProvider(url: url as CFURL),
              let cgImage = CGImage(pngDataProviderSource: dataProvider, decode: nil,
                                   shouldInterpolate: false, intent: .defaultIntent) else {
            throw XPlanetError.processFailed("Cannot load xplanet output for annotation")
        }

        let w = cgImage.width
        let h = cgImage.height
        let size = CGSize(width: w, height: h)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: w, height: h,
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: colorSpace,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw XPlanetError.processFailed("Cannot create annotation context")
        }

        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))

        if !cities.isEmpty {
            let date = Date()
            let fontSize = max(8, CGFloat(w) / 160)
            let dotRadius = max(4, fontSize * 0.28)
            let font = CTFontCreateWithName("Helvetica-Bold" as CFString, fontSize, nil)
            let yellow = CGColor(red: 1, green: 1, blue: 0, alpha: 1)   // bright yellow
            let ink    = CGColor(red: 0, green: 0, blue: 0, alpha: 0.85)

            for city in cities {
                let pt = pixelPosition(latitude: city.latitude, longitude: city.longitude, size: size)

                // Dot
                ctx.setFillColor(yellow)
                ctx.setStrokeColor(ink)
                ctx.setLineWidth(max(1.5, dotRadius * 0.4))
                let dotRect = CGRect(x: pt.x - dotRadius, y: pt.y - dotRadius,
                                     width: dotRadius * 2, height: dotRadius * 2)
                ctx.fillEllipse(in: dotRect)
                ctx.strokeEllipse(in: dotRect)

                // Label: "City Name  HH:MM"
                let label = "\(city.name)  \(city.currentTime(for: date))"
                drawText(label,
                         at: CGPoint(x: pt.x + dotRadius + 5, y: pt.y - fontSize * 0.38),
                         font: font, textColor: yellow, shadowColor: ink, in: ctx)
            }
        }

        guard let result = ctx.makeImage() else {
            throw XPlanetError.processFailed("Cannot render annotated image")
        }

        // Double-buffer between two stable files (A / B), alternating each render.
        //
        // Two macOS constraints pull in opposite directions:
        //  1. setDesktopImageURL with the SAME path that's already set is a no-op
        //     — overwriting one fixed file leaves the stale image on screen.
        //  2. On macOS 14+ the new wallpaper system keeps a live reference to the
        //     file; DELETING it (as a unique-filename scheme must, to avoid
        //     unbounded growth) leaves a dangling reference — the desktop shows a
        //     black "?" placeholder and freezes.
        //
        // Alternating between two persistent files satisfies both: the path
        // changes every update (forces a repaint) and neither file is ever
        // deleted (no dangling reference). Picking the buffer that is NOT
        // currently on the desktop means we never overwrite the live file.
        let dir = url.deletingLastPathComponent()
        let bufferA = dir.appendingPathComponent("wallpaper-a.png")
        let bufferB = dir.appendingPathComponent("wallpaper-b.png")

        // Alternate strictly via our OWN persisted flag — do NOT ask macOS which
        // image is current. On macOS 14+, NSWorkspace.desktopImageURL does not
        // reliably return the file we set, so deciding the buffer from it makes
        // us pick the same buffer every time, overwrite one fixed path, and hit
        // the same-path repaint no-op (the desktop freezes on the first render).
        let key = "com.earthwallpaper.lastBuffer"
        let useA = UserDefaults.standard.string(forKey: key) != "a"
        let outURL = useA ? bufferA : bufferB

        guard let dest = CGImageDestinationCreateWithURL(
            outURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw XPlanetError.processFailed("Cannot create image destination")
        }
        CGImageDestinationAddImage(dest, result, nil)
        guard CGImageDestinationFinalize(dest) else {
            throw XPlanetError.processFailed("Cannot write annotated image")
        }
        UserDefaults.standard.set(useA ? "a" : "b", forKey: key)
        return outURL
    }

    private static func drawText(_ text: String, at point: CGPoint,
                                 font: CTFont, textColor: CGColor, shadowColor: CGColor,
                                 in ctx: CGContext) {
        let fontKey  = kCTFontAttributeName as NSAttributedString.Key
        let colorKey = kCTForegroundColorAttributeName as NSAttributedString.Key

        let shadowAttrs: [NSAttributedString.Key: Any] = [fontKey: font, colorKey: shadowColor]
        let mainAttrs:   [NSAttributedString.Key: Any] = [fontKey: font, colorKey: textColor]

        let shadowLine = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: shadowAttrs))
        let mainLine   = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: mainAttrs))

        ctx.saveGState()
        for (dx, dy): (CGFloat, CGFloat) in [(-1, -1), (1, -1), (-1, 1), (1, 1), (0, -1), (0, 1)] {
            ctx.textPosition = CGPoint(x: point.x + dx, y: point.y + dy)
            CTLineDraw(shadowLine, ctx)
        }
        ctx.textPosition = point
        CTLineDraw(mainLine, ctx)
        ctx.restoreGState()
    }

    // MARK: - Run

    static func run(cities: [City]) throws {
        guard let binaryPath = xplanetPath() else {
            throw XPlanetError.binaryNotFound
        }

        let dir = try supportDir()
        let outputURL = dir.appendingPathComponent("earth.png")

        var w = 2560, h = 1440
        if Thread.isMainThread {
            let screen = NSScreen.main ?? NSScreen.screens.first
            let scale = screen?.backingScaleFactor ?? 2.0
            w = Int((screen?.frame.width ?? 1280) * scale)
            h = Int((screen?.frame.height ?? 800) * scale)
        } else {
            DispatchQueue.main.sync {
                let screen = NSScreen.main ?? NSScreen.screens.first
                let scale = screen?.backingScaleFactor ?? 2.0
                w = Int((screen?.frame.width ?? 1280) * scale)
                h = Int((screen?.frame.height ?? 800) * scale)
            }
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = [
            "-num_times", "1",
            "-body", "earth",
            "-projection", "rectangular",
            "-geometry", "\(w)x\(h)",
            "-output", outputURL.path
        ]

        let errorPipe = Pipe()
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let msg = String(data: data, encoding: .utf8) ?? "exit code \(process.terminationStatus)"
            throw XPlanetError.processFailed(msg)
        }

        let finalURL = try annotateImage(at: outputURL, with: cities)
        setWallpaper(imageURL: finalURL)
    }

    static func setWallpaper(imageURL: URL) {
        // On macOS 14+ (and notably macOS 26), NSWorkspace.setDesktopImageURL
        // updates the stored setting but does NOT force the WindowServer to
        // redraw — the desktop stays frozen on the previously-painted image even
        // as the underlying file changes. Driving it through System Events
        // (AppleScript) does trigger an actual repaint. Combined with the
        // alternating-buffer paths, this reliably refreshes the desktop.
        //
        // The first call prompts the user to allow controlling System Events
        // (see NSAppleEventsUsageDescription in Info.plist); thereafter silent.
        let escaped = imageURL.path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = "tell application \"System Events\" to set picture of every desktop to \"\(escaped)\""

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", source]
        let errPipe = Pipe()
        process.standardError = errPipe
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            // Fall back to the legacy API if osascript can't be launched.
            let block = {
                for screen in NSScreen.screens {
                    try? NSWorkspace.shared.setDesktopImageURL(imageURL, for: screen, options: [:])
                }
            }
            if Thread.isMainThread { block() } else { DispatchQueue.main.sync { block() } }
        }
    }
}
