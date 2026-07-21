import XCTest
@testable import EarthWallpaper

final class EphemerisTests: XCTestCase {

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

    private func separationDeg(_ a: Ephemeris.SubPoint, _ b: Ephemeris.SubPoint) -> Double {
        let r = Double.pi / 180
        let s = sin(a.latitude * r) * sin(b.latitude * r)
            + cos(a.latitude * r) * cos(b.latitude * r) * cos((a.longitude - b.longitude) * r)
        return acos(max(-1, min(1, s))) / r
    }

    // MARK: - Sun

    // At the June solstice the Sun stands over the Tropic of Cancer. Latitude
    // changes negligibly for hours around the solstice, so noon that day works.
    func test_subsolarLatitude_juneSolstice() {
        let p = Ephemeris.subsolarPoint(date: utcDate(2026, 6, 21, 12, 0))
        XCTAssertEqual(p.latitude, 23.437, accuracy: 0.05)
    }

    // At the March equinox the Sun is over the equator (±0.4°/day drift).
    func test_subsolarLatitude_marchEquinox() {
        let p = Ephemeris.subsolarPoint(date: utcDate(2026, 3, 20, 12, 0))
        XCTAssertEqual(p.latitude, 0, accuracy: 0.5)
    }

    // At 12:00 UTC the Sun is near the Greenwich meridian, offset only by the
    // equation of time (max ±4.1°).
    func test_subsolarLongitude_nearZeroAtNoonUTC() {
        for date in [utcDate(2026, 6, 21, 12, 0), utcDate(2026, 1, 15, 12, 0)] {
            let p = Ephemeris.subsolarPoint(date: date)
            XCTAssertLessThan(abs(p.longitude), 5.0)
        }
    }

    // MARK: - Moon

    // The sublunar latitude can never exceed obliquity + lunar inclination
    // (≈ 28.6°).
    func test_sublunarLatitude_withinLunarBounds() {
        for dayOffset in 0..<60 {
            let date = Date(timeIntervalSince1970: 1_780_000_000 + Double(dayOffset) * 86400)
            let p = Ephemeris.sublunarPoint(date: date)
            XCTAssertLessThan(abs(p.latitude), 29.0)
        }
    }

    // During a solar eclipse the Moon sits between Sun and Earth, so the
    // sublunar and subsolar points nearly coincide.
    func test_solarEclipse2026_sublunarNearSubsolar() {
        let date = utcDate(2026, 8, 12, 17, 46)
        let sep = separationDeg(Ephemeris.sublunarPoint(date: date),
                                Ephemeris.subsolarPoint(date: date))
        XCTAssertLessThan(sep, 2.0)
    }

    // During a lunar eclipse the Moon is opposite the Sun, so the sublunar
    // point is nearly the antipode of the subsolar point.
    func test_lunarEclipse2000_sublunarNearAntipode() {
        let date = utcDate(2000, 1, 21, 4, 44)
        let sun = Ephemeris.subsolarPoint(date: date)
        let antipode = Ephemeris.SubPoint(
            latitude: -sun.latitude,
            longitude: sun.longitude > 0 ? sun.longitude - 180 : sun.longitude + 180)
        let sep = separationDeg(Ephemeris.sublunarPoint(date: date), antipode)
        XCTAssertLessThan(sep, 2.0)
    }
}
