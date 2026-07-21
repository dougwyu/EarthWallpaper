import AppKit
import CoreText
import Foundation
import ImageIO

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

    /// How long a rendered base map stays valid. The day/night terminator moves
    /// only ~1–2 px per minute at screen resolution, so re-running xplanet every
    /// tick is wasted work: the base map is cached and only the annotation layer
    /// (city clocks, moon phase) is redrawn each cycle.
    static let baseMapMaxAge: TimeInterval = 10 * 60

    // MARK: - Label style

    private static let labelYellow = CGColor(red: 1, green: 1, blue: 0, alpha: 1)
    private static let labelInk    = CGColor(red: 0, green: 0, blue: 0, alpha: 0.85)

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

    // MARK: - Screen geometry

    private static func screenPixelSize() -> (width: Int, height: Int) {
        var w = 2560, h = 1440
        let block = {   // NSScreen must be accessed on the main thread
            let screen = NSScreen.main ?? NSScreen.screens.first
            let scale = screen?.backingScaleFactor ?? 2.0
            w = Int((screen?.frame.width ?? 1280) * scale)
            h = Int((screen?.frame.height ?? 800) * scale)
        }
        if Thread.isMainThread { block() } else { DispatchQueue.main.sync { block() } }
        return (w, h)
    }

    // MARK: - Base map (xplanet)

    /// Returns the base-map PNG for the current screen size, re-rendering with
    /// xplanet only when it is missing, stale, the wrong size, or forced.
    static func baseMap(forceRefresh: Bool = false) throws -> URL {
        let (w, h) = screenPixelSize()
        let url = try supportDir().appendingPathComponent("earth.png")
        if !forceRefresh, baseMapIsUsable(at: url, width: w, height: h) {
            return url
        }
        try renderBaseMap(width: w, height: h, to: url)
        return url
    }

    private static func baseMapIsUsable(at url: URL, width: Int, height: Int) -> Bool {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let mtime = attrs[.modificationDate] as? Date,
              Date().timeIntervalSince(mtime) < baseMapMaxAge,
              let size = imagePixelSize(at: url),
              size.width == width, size.height == height else {
            return false
        }
        return true
    }

    /// Pixel dimensions from the image header — no full decode.
    static func imagePixelSize(at url: URL) -> (width: Int, height: Int)? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int,
              let h = props[kCGImagePropertyPixelHeight] as? Int else {
            return nil
        }
        return (w, h)
    }

    private static func renderBaseMap(width: Int, height: Int, to url: URL) throws {
        guard let binaryPath = xplanetPath() else {
            throw XPlanetError.binaryNotFound
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = [
            "-num_times", "1",
            "-body", "earth",
            "-projection", "rectangular",
            "-geometry", "\(width)x\(height)",
            "-output", url.path
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
    }

    // MARK: - Coordinate mapping

    // xplanet's rectangular projection stretches the full equirectangular map
    // to fill the entire output frame (longitude -180..+180 across the full
    // width, latitude +90..-90 down the full height). The uniform bright/dark
    // rows at the very top and bottom are the polar regions (Arctic ice /
    // Antarctic interior), which are real map content — NOT letterbox fill, so
    // no aspect-ratio correction is needed. Verified empirically by checking
    // known cities (London, Shanghai) land exactly.
    //
    // CGContext has y=0 at the bottom, so we flip: cg_y = height - image_y.
    static func pixelPosition(latitude: Double, longitude: Double, size: CGSize) -> CGPoint {
        let x = CGFloat((longitude + 180.0) / 360.0) * size.width
        let imageY = CGFloat((90.0 - latitude) / 180.0) * size.height
        let y = size.height - imageY   // flip for CGContext
        return CGPoint(x: x, y: y)
    }

    // MARK: - Annotation (Core Graphics)

    /// Draws city dots, time labels, and the moon-phase inset onto the cached
    /// base map and returns the composited image. No files are written — the
    /// caller hands the CGImage straight to the overlay window.
    static func annotate(baseMapAt url: URL, cities: [City], date: Date = Date()) throws -> CGImage {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
            throw XPlanetError.processFailed("Cannot load base map for annotation")
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

        let fontSize = max(8, CGFloat(w) / 160)
        let font = CTFontCreateWithName("Helvetica-Bold" as CFString, fontSize, nil)

        if !cities.isEmpty {
            let dotRadius = max(4, fontSize * 0.28)

            for city in cities {
                let pt = pixelPosition(latitude: city.latitude, longitude: city.longitude, size: size)

                // Dot
                ctx.setFillColor(labelYellow)
                ctx.setStrokeColor(labelInk)
                ctx.setLineWidth(max(1.5, dotRadius * 0.4))
                let dotRect = CGRect(x: pt.x - dotRadius, y: pt.y - dotRadius,
                                     width: dotRadius * 2, height: dotRadius * 2)
                ctx.fillEllipse(in: dotRect)
                ctx.strokeEllipse(in: dotRect)

                // Label: "City Name  HH:MM"
                let label = "\(city.name)  \(city.currentTime(for: date))"
                drawText(label,
                         at: CGPoint(x: pt.x + dotRadius + 5, y: pt.y - fontSize * 0.38),
                         font: font, textColor: labelYellow, shadowColor: labelInk, in: ctx)
            }
        }

        drawMoonInset(MoonPhase(date: date), imageSize: size, font: font, in: ctx)

        guard let result = ctx.makeImage() else {
            throw XPlanetError.processFailed("Cannot render annotated image")
        }
        return result
    }

    // MARK: - Moon inset

    /// Phase disc + caption in the bottom-right corner, over Antarctica —
    /// safely below the southernmost plausible city label.
    static func drawMoonInset(_ moon: MoonPhase, imageSize: CGSize, font: CTFont, in ctx: CGContext) {
        let d = max(56, imageSize.width / 34)
        let margin = d * 0.5
        let captionGap = CTFontGetSize(font) * 1.7
        let center = CGPoint(x: imageSize.width - margin - d / 2,
                             y: margin + captionGap + d / 2)

        drawMoonDisc(fraction: moon.illuminatedFraction, waxing: moon.waxing,
                     center: center, radius: d / 2, in: ctx)

        // Caption, right-aligned to the inset margin so it never runs off-screen.
        let caption = "\(moon.phaseName)  \(Int((moon.illuminatedFraction * 100).rounded()))%"
        let attrs: [NSAttributedString.Key: Any] = [
            kCTFontAttributeName as NSAttributedString.Key: font,
            kCTForegroundColorAttributeName as NSAttributedString.Key: labelYellow
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: caption, attributes: attrs))
        let lineWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        drawText(caption,
                 at: CGPoint(x: imageSize.width - margin - lineWidth, y: margin),
                 font: font, textColor: labelYellow, shadowColor: labelInk, in: ctx)
    }

    /// Classic phase rendering: shadowed disc, then the lit region bounded by
    /// the limb semicircle on the lit side and an elliptical terminator.
    /// Northern-hemisphere convention: a waxing moon is lit on the right.
    static func drawMoonDisc(fraction: Double, waxing: Bool,
                             center: CGPoint, radius: CGFloat, in ctx: CGContext) {
        let f = min(1, max(0, fraction))
        let dark = CGColor(red: 0.16, green: 0.17, blue: 0.22, alpha: 1)
        let lit  = CGColor(red: 0.96, green: 0.94, blue: 0.86, alpha: 1)
        let rim  = CGColor(red: 0.85, green: 0.85, blue: 0.80, alpha: 0.9)
        let discRect = CGRect(x: center.x - radius, y: center.y - radius,
                              width: radius * 2, height: radius * 2)

        ctx.setFillColor(dark)
        ctx.fillEllipse(in: discRect)

        if f > 0.005 {
            let dir: CGFloat = waxing ? 1 : -1
            // Signed terminator semi-axis: bulges away from the lit limb when
            // gibbous (f > 0.5), curves into the lit side when crescent.
            let sx = -dir * radius * CGFloat(2 * f - 1)
            let n = 60
            var pts: [CGPoint] = []
            for i in 0...n {   // limb: top → around the lit side → bottom
                let a = CGFloat.pi / 2 - CGFloat.pi * CGFloat(i) / CGFloat(n)
                pts.append(CGPoint(x: center.x + dir * radius * cos(a),
                                   y: center.y + radius * sin(a)))
            }
            for i in 0...n {   // terminator: bottom → top
                let a = -CGFloat.pi / 2 + CGFloat.pi * CGFloat(i) / CGFloat(n)
                pts.append(CGPoint(x: center.x + sx * cos(a),
                                   y: center.y + radius * sin(a)))
            }
            let path = CGMutablePath()
            path.addLines(between: pts)
            path.closeSubpath()
            ctx.setFillColor(lit)
            ctx.addPath(path)
            ctx.fillPath()
        }

        ctx.setStrokeColor(rim)
        ctx.setLineWidth(max(1.5, radius * 0.05))
        ctx.strokeEllipse(in: discRect)
    }

    // MARK: - Text

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
}
