import XCTest
@testable import EarthWallpaper

final class XPlanetRunnerTests: XCTestCase {

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
