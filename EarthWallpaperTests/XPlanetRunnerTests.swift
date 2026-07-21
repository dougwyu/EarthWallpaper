import XCTest
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers
@testable import EarthWallpaper

final class XPlanetRunnerTests: XCTestCase {

    // MARK: - Helpers

    private func writePNG(_ image: CGImage, to url: URL) {
        guard let dest = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
    }

    private func makeContext(width: Int, height: Int) -> CGContext {
        CGContext(data: nil, width: width, height: height,
                  bitsPerComponent: 8, bytesPerRow: 0,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    }

    /// A synthetic dark-blue "base map" PNG standing in for xplanet output.
    private func makeBasePNG(width: Int, height: Int) -> URL {
        let ctx = makeContext(width: width, height: height)
        ctx.setFillColor(CGColor(red: 0.05, green: 0.10, blue: 0.30, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("base_\(UUID().uuidString).png")
        writePNG(ctx.makeImage()!, to: url)
        return url
    }

    // MARK: - Annotation

    func test_annotate_returnsImageMatchingBaseSize() throws {
        let base = makeBasePNG(width: 800, height: 400)
        defer { try? FileManager.default.removeItem(at: base) }
        let cities = [
            City(name: "London", latitude: 51.5, longitude: -0.13, timezone: "Europe/London"),
            City(name: "Sydney", latitude: -33.87, longitude: 151.21, timezone: "Australia/Sydney")
        ]
        let image = try XPlanetRunner.annotate(baseMapAt: base, cities: cities)
        XCTAssertEqual(image.width, 800)
        XCTAssertEqual(image.height, 400)
        // Dump for manual inspection of labels + moon inset.
        writePNG(image, to: URL(fileURLWithPath: "/tmp/ew_annotate_test.png"))
    }

    func test_annotate_missingBase_throws() {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("nope_\(UUID().uuidString).png")
        XCTAssertThrowsError(try XPlanetRunner.annotate(baseMapAt: missing, cities: []))
    }

    // MARK: - Label collision avoidance

    private func rects(anchors: [CGPoint], widths: [CGFloat],
                       fontSize: CGFloat = 24, dotRadius: CGFloat = 7) -> [CGRect] {
        let origins = XPlanetRunner.labelOrigins(for: anchors, labelWidths: widths,
                                                 fontSize: fontSize, dotRadius: dotRadius)
        return zip(origins, widths).map {
            XPlanetRunner.labelRect(origin: $0, width: $1, fontSize: fontSize)
        }
    }

    private func assertPairwiseDisjoint(_ rects: [CGRect],
                                        file: StaticString = #filePath, line: UInt = #line) {
        for i in rects.indices {
            for j in rects.indices where j > i {
                XCTAssertFalse(rects[i].intersects(rects[j]),
                               "labels \(i) and \(j) overlap: \(rects[i]) vs \(rects[j])",
                               file: file, line: line)
            }
        }
    }

    func test_labelOrigins_coincidentAnchors_doNotOverlap() {
        let anchors = [CGPoint(x: 500, y: 300), CGPoint(x: 505, y: 302)]
        assertPairwiseDisjoint(rects(anchors: anchors, widths: [220, 200]))
    }

    // A tight cluster like London/Paris/Amsterdam/Berlin must all resolve.
    func test_labelOrigins_clusteredAnchors_allDisjoint() {
        let anchors = [
            CGPoint(x: 500, y: 300), CGPoint(x: 540, y: 310),
            CGPoint(x: 520, y: 290), CGPoint(x: 560, y: 305),
            CGPoint(x: 510, y: 315)
        ]
        assertPairwiseDisjoint(rects(anchors: anchors, widths: [220, 180, 260, 200, 240]))
    }

    // A label must not sit on top of another city's dot: anchor B lies exactly
    // where A's default label would run.
    func test_labelOrigins_avoidNeighbouringDots() {
        let fontSize: CGFloat = 24
        let dotRadius: CGFloat = 7
        let anchors = [CGPoint(x: 500, y: 300), CGPoint(x: 580, y: 300)]
        let origins = XPlanetRunner.labelOrigins(for: anchors, labelWidths: [220, 220],
                                                 fontSize: fontSize, dotRadius: dotRadius)
        let labelA = XPlanetRunner.labelRect(origin: origins[0], width: 220, fontSize: fontSize)
        let dotB = CGRect(x: 580 - dotRadius, y: 300 - dotRadius,
                          width: dotRadius * 2, height: dotRadius * 2)
        XCTAssertFalse(labelA.intersects(dotB), "label A overlaps city B's dot")
    }

    // Labels must dodge extra obstacles (the sun/moon markers).
    func test_labelOrigins_avoidObstacles() {
        let fontSize: CGFloat = 24
        let obstacle = CGRect(x: 540, y: 280, width: 50, height: 50)  // in default label path
        let origins = XPlanetRunner.labelOrigins(for: [CGPoint(x: 500, y: 300)],
                                                 labelWidths: [220],
                                                 fontSize: fontSize, dotRadius: 7,
                                                 obstacles: [obstacle])
        let rect = XPlanetRunner.labelRect(origin: origins[0], width: 220, fontSize: fontSize)
        XCTAssertFalse(rect.intersects(obstacle))
    }

    // Far-apart labels keep the classic right-of-dot placement.
    func test_labelOrigins_distantAnchors_useDefaultPosition() {
        let anchors = [CGPoint(x: 200, y: 300), CGPoint(x: 2000, y: 1200)]
        let origins = XPlanetRunner.labelOrigins(for: anchors, labelWidths: [220, 220],
                                                 fontSize: 24, dotRadius: 7)
        XCTAssertEqual(origins[0].x, 200 + 7 + 5, accuracy: 0.5)
        XCTAssertEqual(origins[0].y, 300 - 24 * 0.38, accuracy: 0.5)
        XCTAssertEqual(origins[1].x, 2000 + 7 + 5, accuracy: 0.5)
    }

    // Renders a tight European cluster for visual verification of placement.
    func test_annotate_europeCluster_writesPreview() throws {
        let base = makeBasePNG(width: 1600, height: 800)
        defer { try? FileManager.default.removeItem(at: base) }
        let cities = [
            City(name: "London", latitude: 51.51, longitude: -0.13, timezone: "Europe/London"),
            City(name: "Paris", latitude: 48.86, longitude: 2.35, timezone: "Europe/Paris"),
            City(name: "Amsterdam", latitude: 52.37, longitude: 4.90, timezone: "Europe/Amsterdam"),
            City(name: "Berlin", latitude: 52.52, longitude: 13.40, timezone: "Europe/Berlin")
        ]
        let image = try XPlanetRunner.annotate(baseMapAt: base, cities: cities)
        writePNG(image, to: URL(fileURLWithPath: "/tmp/ew_cluster_test.png"))
        XCTAssertEqual(image.width, 1600)
    }

    // Renders every principal phase into one strip for visual verification.
    func test_moonDisc_rendersAllPhases() {
        let ctx = makeContext(width: 880, height: 140)
        ctx.setFillColor(CGColor(red: 0.05, green: 0.10, blue: 0.30, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: 880, height: 140))
        let combos: [(Double, Bool)] = [
            (0.03, true), (0.25, true), (0.5, true), (0.75, true),
            (0.97, true), (0.75, false), (0.5, false), (0.25, false)
        ]
        for (i, combo) in combos.enumerated() {
            XPlanetRunner.drawMoonDisc(fraction: combo.0, waxing: combo.1,
                                       center: CGPoint(x: 55 + 110 * i, y: 70),
                                       radius: 45, in: ctx)
        }
        writePNG(ctx.makeImage()!, to: URL(fileURLWithPath: "/tmp/ew_moon_strip.png"))
    }

    // Equirectangular: lon=0, lat=0 → centre of image
    func test_pixelPosition_equator_primeMeridian() {
        let size = CGSize(width: 360, height: 180)
        let pt = XPlanetRunner.pixelPosition(latitude: 0, longitude: 0, size: size)
        XCTAssertEqual(pt.x, 180, accuracy: 0.5)
        XCTAssertEqual(pt.y, 90,  accuracy: 0.5)  // CG y=0 at bottom → equator is mid-height
    }

    // North Pole → top of image (image_y=0 → cg_y = height)
    func test_pixelPosition_northPole() {
        let size = CGSize(width: 360, height: 180)
        let pt = XPlanetRunner.pixelPosition(latitude: 90, longitude: 0, size: size)
        XCTAssertEqual(pt.x, 180,  accuracy: 0.5)
        XCTAssertEqual(pt.y, 180,  accuracy: 0.5)  // top of image = cg_y = height
    }

    // London ~51.5°N, 0°W
    func test_pixelPosition_london() {
        let size = CGSize(width: 3600, height: 1800)
        let pt = XPlanetRunner.pixelPosition(latitude: 51.5, longitude: -0.12, size: size)
        // x ≈ (180 - 0.12) / 360 * 3600 ≈ 1799
        XCTAssertEqual(pt.x, 1798.8, accuracy: 1)
        // image_y = (90 - 51.5) / 180 * 1800 = 385, cg_y = 1800 - 385 = 1415
        XCTAssertEqual(pt.y, 1415, accuracy: 1)
    }

    // Date Line: longitude=180 → right edge
    func test_pixelPosition_dateLine() {
        let size = CGSize(width: 360, height: 180)
        let pt = XPlanetRunner.pixelPosition(latitude: 0, longitude: 180, size: size)
        XCTAssertEqual(pt.x, 360, accuracy: 0.5)
    }

    // Map fills the full frame (xplanet stretches it). At a non-2:1 size,
    // latitude still spans the entire height — no letterbox offset.
    func test_pixelPosition_fillsFullFrame_nonSquareAspect() {
        let size = CGSize(width: 3840, height: 2486)   // ratio ≈ 1.54 (real Retina screen)
        // London 51.5°N, 0°: x = (180/360)*3840 = 1920
        //   imageY = (90-51.5)/180*2486 = 531.74; cg_y = 2486 - 531.74 = 1954.26
        let pt = XPlanetRunner.pixelPosition(latitude: 51.5, longitude: 0, size: size)
        XCTAssertEqual(pt.x, 1920, accuracy: 0.5)
        XCTAssertEqual(pt.y, 1954.26, accuracy: 1)
    }
}
