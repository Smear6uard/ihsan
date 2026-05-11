import Foundation

/// Shared low-level astronomical utilities — Julian Date conversion,
/// degree-based trig helpers, and angle normalization.
///
/// Used by `SolarPosition` (NOAA solar position algorithm) and
/// `LunarPosition` (Meeus low-precision lunar position) in the celestial
/// scene. Kept package-internal because nothing outside the celestial
/// layer should be computing astronomical quantities directly — call
/// sites should consume the high-level `SolarPosition.compute(...)` and
/// `LunarPosition.compute(...)` APIs instead.
enum AstronomicalUtilities {

    // MARK: - Julian Date

    /// Convert a `Date` to its Julian Date.
    ///
    /// Julian Date is the canonical input for the astronomical formulas
    /// below — it sidesteps Gregorian / Julian calendar transitions and
    /// gives a uniform real-valued time scale. The implementation uses
    /// the standard Meeus formula valid for any Gregorian date after
    /// 1582-10-15; for the iPhone-app use case (current date ± a few
    /// years) this is well within the accuracy budget.
    static func julianDate(from date: Date) -> Double {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
        let year = Double(components.year ?? 2000)
        let month = Double(components.month ?? 1)
        let day = Double(components.day ?? 1)
        let hour = Double(components.hour ?? 0)
        let minute = Double(components.minute ?? 0)
        let second = Double(components.second ?? 0)

        let dayFraction = (hour + minute / 60.0 + second / 3600.0) / 24.0

        var Y = year
        var M = month
        if M <= 2 {
            Y -= 1
            M += 12
        }

        let A = floor(Y / 100.0)
        let B = 2.0 - A + floor(A / 4.0)

        let jd = floor(365.25 * (Y + 4716))
            + floor(30.6001 * (M + 1))
            + day
            + dayFraction
            + B
            - 1524.5

        return jd
    }

    /// Number of Julian centuries since the J2000.0 epoch (2000-01-01
    /// 12:00:00 UTC). The natural time-base for the solar / lunar
    /// position polynomials.
    static func julianCentury(julianDate jd: Double) -> Double {
        (jd - 2451545.0) / 36525.0
    }

    // MARK: - Degree-based trig

    /// Sine of an angle expressed in degrees.
    static func sind(_ degrees: Double) -> Double {
        sin(degrees * .pi / 180.0)
    }

    /// Cosine of an angle expressed in degrees.
    static func cosd(_ degrees: Double) -> Double {
        cos(degrees * .pi / 180.0)
    }

    /// Tangent of an angle expressed in degrees.
    static func tand(_ degrees: Double) -> Double {
        tan(degrees * .pi / 180.0)
    }

    /// arcsin returning degrees.
    static func asind(_ value: Double) -> Double {
        asin(value) * 180.0 / .pi
    }

    /// arctan2 returning degrees.
    static func atan2d(_ y: Double, _ x: Double) -> Double {
        atan2(y, x) * 180.0 / .pi
    }

    // MARK: - Angle normalization

    /// Normalize an angle to `[0, 360)` degrees.
    static func normalize360(_ degrees: Double) -> Double {
        let remainder = degrees.truncatingRemainder(dividingBy: 360.0)
        return remainder < 0 ? remainder + 360.0 : remainder
    }

    /// Normalize an angle to `[-180, 180)` degrees. Used for hour angle
    /// so that east-before-noon is negative and west-after-noon is
    /// positive, which is what the screen-position mapping expects.
    static func normalize180(_ degrees: Double) -> Double {
        var d = normalize360(degrees)
        if d >= 180.0 { d -= 360.0 }
        return d
    }
}
