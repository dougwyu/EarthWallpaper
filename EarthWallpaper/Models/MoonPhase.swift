import Foundation

/// The Moon's current phase, computed from a truncated Meeus series
/// (Astronomical Algorithms, ch. 48). Accurate to well under a degree of
/// elongation — a few hours of lunar age — which is far more than an inset
/// icon needs. A pure function of the date: no network, no subprocess,
/// trivially testable against known eclipses (solar eclipse = new moon,
/// lunar eclipse = full moon).
struct MoonPhase {
    let illuminatedFraction: Double   // 0 (new) … 1 (full)
    let waxing: Bool
    let phaseName: String             // "Waxing gibbous", …
    let emoji: String                 // 🌒 …

    init(date: Date = Date()) {
        let jd = 2440587.5 + date.timeIntervalSince1970 / 86400
        let t = (jd - 2451545.0) / 36525    // Julian centuries since J2000

        func deg(_ x: Double) -> Double {
            let y = x.truncatingRemainder(dividingBy: 360)
            return y < 0 ? y + 360 : y
        }
        let d  = deg(297.8501921 + 445267.1114034 * t)   // mean elongation Moon−Sun
        let m  = deg(357.5291092 + 35999.0502909  * t)   // Sun's mean anomaly
        let mp = deg(134.9633964 + 477198.8675055 * t)   // Moon's mean anomaly
        let r = Double.pi / 180

        // Corrected elongation: 0° = new, 90° = first quarter, 180° = full, 270° = last.
        let e = deg(d
            + 6.289 * sin(mp * r)
            - 2.100 * sin(m * r)
            + 1.274 * sin((2 * d - mp) * r)
            + 0.658 * sin(2 * d * r)
            + 0.214 * sin(2 * mp * r)
            + 0.110 * sin(d * r))

        illuminatedFraction = (1 - cos(e * r)) / 2
        waxing = e < 180

        // Eight sectors of 45°, centred on the principal phases.
        let names  = ["New moon", "Waxing crescent", "First quarter", "Waxing gibbous",
                      "Full moon", "Waning gibbous", "Last quarter", "Waning crescent"]
        let emojis = ["🌑", "🌒", "🌓", "🌔", "🌕", "🌖", "🌗", "🌘"]
        let sector = Int(((e + 22.5) / 45).rounded(.down)) % 8
        phaseName = names[sector]
        emoji = emojis[sector]
    }
}
