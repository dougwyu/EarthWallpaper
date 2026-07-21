import XCTest
@testable import EarthWallpaper

final class MoonPhaseTests: XCTestCase {

    private func utcDate(_ year: Int, _ month: Int, _ day: Int,
                         _ hour: Int = 0, _ minute: Int = 0) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day
        c.hour = hour; c.minute = minute
        c.timeZone = TimeZone(identifier: "UTC")
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: c)!
    }

    // A solar eclipse can only happen at the exact moment of new moon.
    func test_totalSolarEclipse1999_isNewMoon() {
        let moon = MoonPhase(date: utcDate(1999, 8, 11, 11, 3))
        XCTAssertLessThan(moon.illuminatedFraction, 0.02)
        XCTAssertEqual(moon.phaseName, "New moon")
    }

    // A lunar eclipse can only happen at the exact moment of full moon.
    func test_totalLunarEclipse2000_isFullMoon() {
        let moon = MoonPhase(date: utcDate(2000, 1, 21, 4, 44))
        XCTAssertGreaterThan(moon.illuminatedFraction, 0.98)
        XCTAssertEqual(moon.phaseName, "Full moon")
    }

    func test_totalSolarEclipse2026_isNewMoon() {
        let moon = MoonPhase(date: utcDate(2026, 8, 12, 17, 46))
        XCTAssertLessThan(moon.illuminatedFraction, 0.03)
    }

    // Between the new moon of 2000-01-06 and the full moon of 2000-01-21.
    func test_midJanuary2000_isWaxing() {
        let moon = MoonPhase(date: utcDate(2000, 1, 14))
        XCTAssertTrue(moon.waxing)
        XCTAssertGreaterThan(moon.illuminatedFraction, 0.2)
        XCTAssertLessThan(moon.illuminatedFraction, 0.85)
    }

    // Shortly after the full moon of 2000-01-21.
    func test_lateJanuary2000_isWaning() {
        let moon = MoonPhase(date: utcDate(2000, 1, 25))
        XCTAssertFalse(moon.waxing)
    }

    func test_fractionAlwaysWithinBounds() {
        for daysOffset in stride(from: 0, to: 60, by: 1) {
            let date = Date(timeIntervalSince1970: 1_600_000_000 + Double(daysOffset) * 86400)
            let f = MoonPhase(date: date).illuminatedFraction
            XCTAssertGreaterThanOrEqual(f, 0)
            XCTAssertLessThanOrEqual(f, 1)
        }
    }
}
