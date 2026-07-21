import Foundation

/// Geocentric sub-points of the Sun and Moon — the spots on Earth where each
/// body is directly overhead right now — from truncated Meeus series
/// (Astronomical Algorithms chs. 25 and 47) plus Greenwich sidereal time.
/// Accurate to ~0.1–0.3°, i.e. a few pixels at screen resolution. Pure
/// functions of the date; the tests pin them to physical ground truth:
/// solstice/equinox subsolar latitudes, and eclipse geometry (solar eclipse →
/// sublunar ≈ subsolar; lunar eclipse → sublunar ≈ antipode of subsolar).
enum Ephemeris {

    struct SubPoint {
        let latitude: Double    // degrees, +N
        let longitude: Double   // degrees, +E, in −180…180
    }

    // MARK: - Sun

    static func subsolarPoint(date: Date = Date()) -> SubPoint {
        let t = centuries(date)
        let l0 = norm360(280.46646 + 36000.76983 * t)        // mean longitude
        let m  = norm360(357.52911 + 35999.05029 * t)        // mean anomaly
        let c  = (1.914602 - 0.004817 * t) * sinDeg(m)       // equation of centre
               + (0.019993 - 0.000101 * t) * sinDeg(2 * m)
               + 0.000289 * sinDeg(3 * m)
        return subPoint(eclipticLon: norm360(l0 + c), eclipticLat: 0, date: date, t: t)
    }

    // MARK: - Moon

    static func sublunarPoint(date: Date = Date()) -> SubPoint {
        let t = centuries(date)
        let lp = norm360(218.3164477 + 481267.88123421 * t)  // mean longitude
        let d  = norm360(297.8501921 + 445267.1114034  * t)  // mean elongation
        let m  = norm360(357.5291092 + 35999.0502909   * t)  // Sun mean anomaly
        let mp = norm360(134.9633964 + 477198.8675055  * t)  // Moon mean anomaly
        let f  = norm360(93.2720950  + 483202.0175233  * t)  // argument of latitude

        // Principal longitude terms (Meeus table 47.A, degrees).
        let lon = lp
            + 6.288774 * sinDeg(mp)
            + 1.274027 * sinDeg(2*d - mp)
            + 0.658314 * sinDeg(2*d)
            + 0.213618 * sinDeg(2*mp)
            - 0.185116 * sinDeg(m)
            - 0.114332 * sinDeg(2*f)
            + 0.058793 * sinDeg(2*d - 2*mp)
            + 0.057066 * sinDeg(2*d - m - mp)
            + 0.053322 * sinDeg(2*d + mp)
            + 0.045758 * sinDeg(2*d - m)
            - 0.040923 * sinDeg(m - mp)
            - 0.034720 * sinDeg(d)
            - 0.030383 * sinDeg(m + mp)

        // Principal latitude terms (Meeus table 47.B, degrees).
        let lat = 5.128122 * sinDeg(f)
            + 0.280602 * sinDeg(mp + f)
            + 0.277693 * sinDeg(mp - f)
            + 0.173237 * sinDeg(2*d - f)
            + 0.055413 * sinDeg(2*d + f - mp)
            + 0.046271 * sinDeg(2*d - f - mp)
            + 0.032573 * sinDeg(2*d + f)
            + 0.017198 * sinDeg(2*mp + f)

        return subPoint(eclipticLon: norm360(lon), eclipticLat: lat, date: date, t: t)
    }

    // MARK: - Shared

    /// Ecliptic position → the geographic point where the body is at zenith:
    /// latitude = declination, longitude = right ascension − Greenwich sidereal time.
    private static func subPoint(eclipticLon: Double, eclipticLat: Double,
                                 date: Date, t: Double) -> SubPoint {
        let eps = 23.4392911 - 0.0130042 * t                 // mean obliquity
        let sl = sinDeg(eclipticLon), cl = cosDeg(eclipticLon)
        let sb = sinDeg(eclipticLat), cb = cosDeg(eclipticLat)
        let se = sinDeg(eps), ce = cosDeg(eps)

        let dec = asin(sb * ce + cb * se * sl) * 180 / .pi
        let ra  = atan2(sl * ce - (sb / cb) * se, cl) * 180 / .pi
        return SubPoint(latitude: dec, longitude: norm180(ra - gmst(date)))
    }

    /// Greenwich mean sidereal time in degrees.
    static func gmst(_ date: Date) -> Double {
        let jd = julianDay(date)
        let t = (jd - 2451545.0) / 36525
        return norm360(280.46061837
            + 360.98564736629 * (jd - 2451545.0)
            + 0.000387933 * t * t
            - t * t * t / 38_710_000)
    }

    private static func julianDay(_ date: Date) -> Double {
        2440587.5 + date.timeIntervalSince1970 / 86400
    }

    private static func centuries(_ date: Date) -> Double {
        (julianDay(date) - 2451545.0) / 36525
    }

    private static func norm360(_ x: Double) -> Double {
        let y = x.truncatingRemainder(dividingBy: 360)
        return y < 0 ? y + 360 : y
    }

    private static func norm180(_ x: Double) -> Double {
        let y = norm360(x)
        return y > 180 ? y - 360 : y
    }

    private static func sinDeg(_ x: Double) -> Double { sin(x * .pi / 180) }
    private static func cosDeg(_ x: Double) -> Double { cos(x * .pi / 180) }
}
