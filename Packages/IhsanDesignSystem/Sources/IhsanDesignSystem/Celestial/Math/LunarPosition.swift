import Foundation

/// The moon's position in the local sky and its illuminated fraction
/// at a given moment.
///
/// Computed via the low-precision lunar position formulas from Meeus,
/// *Astronomical Algorithms* (chapters 47 and 48). Accuracy is ~0.3° in
/// position and ~1% in illumination — well within the visual budget
/// for a 56pt moon ornament with a crescent cutout. The full Meeus
/// algorithm (≈60 periodic terms) would buy ~0.001° accuracy at the
/// cost of much more code; the visible difference is invisible to the
/// eye.
public struct LunarPosition: Sendable, Equatable {

    /// Altitude in degrees above the local horizon. Negative when the
    /// moon is below the horizon (caller should suppress rendering in
    /// that case).
    public let altitude: Double

    /// Azimuth in degrees from due north, clockwise. 0° = north, 90° =
    /// east, 180° = south, 270° = west.
    public let azimuth: Double

    /// Local hour angle in degrees, wrapped to `[-180, 180)`.
    public let hourAngle: Double

    /// The fraction of the moon's disc illuminated by the sun. 0.0 at
    /// new moon, 1.0 at full moon, ~0.5 at first / last quarter.
    public let illuminatedFraction: Double

    /// `true` while the moon is waxing (between new and full); `false`
    /// while waning (between full and new). Drives the orientation of
    /// the crescent cutout in `MoonOrnament` so the lit edge faces the
    /// correct side.
    public let isWaxing: Bool

    /// Compute the moon's position and illumination at the given moment.
    ///
    /// - Parameters:
    ///   - date: The moment in absolute time.
    ///   - latitude: Observer latitude in degrees.
    ///   - longitude: Observer longitude in degrees.
    public static func compute(
        at date: Date,
        latitude: Double,
        longitude: Double
    ) -> LunarPosition {
        let jd = AstronomicalUtilities.julianDate(from: date)
        let T = AstronomicalUtilities.julianCentury(julianDate: jd)

        // Mean elements (Meeus low-precision, degrees).
        let Lp = AstronomicalUtilities.normalize360(218.316 + 481267.8813 * T)
        let Mp = AstronomicalUtilities.normalize360(134.963 + 477198.8676 * T)
        let Ms = AstronomicalUtilities.normalize360(357.528 + 35999.0503 * T)
        let D  = AstronomicalUtilities.normalize360(297.850 + 445267.1115 * T)
        let F  = AstronomicalUtilities.normalize360( 93.272 + 483202.0175 * T)

        // Ecliptic longitude of the moon — the dominant periodic terms
        // from Meeus' simplified expression (eq. 47.1 reduced).
        let lambda = AstronomicalUtilities.normalize360(
            Lp
            + 6.289 * AstronomicalUtilities.sind(Mp)
            - 1.274 * AstronomicalUtilities.sind(Mp - 2 * D)
            + 0.658 * AstronomicalUtilities.sind(2 * D)
            - 0.186 * AstronomicalUtilities.sind(Ms)
            - 0.059 * AstronomicalUtilities.sind(2 * Mp - 2 * D)
            - 0.057 * AstronomicalUtilities.sind(Mp - 2 * D + Ms)
            + 0.053 * AstronomicalUtilities.sind(Mp + 2 * D)
            + 0.046 * AstronomicalUtilities.sind(2 * D - Ms)
            + 0.041 * AstronomicalUtilities.sind(Mp - Ms)
            - 0.035 * AstronomicalUtilities.sind(D)
            - 0.031 * AstronomicalUtilities.sind(Mp + Ms)
        )

        // Ecliptic latitude (eq. 47.2 reduced).
        let beta =
              5.128 * AstronomicalUtilities.sind(F)
            + 0.281 * AstronomicalUtilities.sind(Mp + F)
            - 0.278 * AstronomicalUtilities.sind(F - Mp)
            - 0.173 * AstronomicalUtilities.sind(F - 2 * D)
            + 0.055 * AstronomicalUtilities.sind(Mp + F - 2 * D)
            - 0.046 * AstronomicalUtilities.sind(F + 2 * D - Mp)
            + 0.033 * AstronomicalUtilities.sind(F + 2 * D)
            + 0.017 * AstronomicalUtilities.sind(2 * Mp + F)

        // Convert to equatorial coordinates using mean obliquity.
        // The ~0.005° nutation correction is neglected at this precision.
        let eps = 23.4393 - 0.0130 * T

        let sinLambda = AstronomicalUtilities.sind(lambda)
        let cosLambda = AstronomicalUtilities.cosd(lambda)
        let sinBeta = AstronomicalUtilities.sind(beta)
        let cosBeta = AstronomicalUtilities.cosd(beta)
        let sinEps = AstronomicalUtilities.sind(eps)
        let cosEps = AstronomicalUtilities.cosd(eps)

        let declination = AstronomicalUtilities.asind(
            sinBeta * cosEps + cosBeta * sinEps * sinLambda
        )
        let rightAscension = AstronomicalUtilities.normalize360(
            AstronomicalUtilities.atan2d(
                sinLambda * cosEps - (sinBeta / cosBeta) * sinEps,
                cosLambda
            )
        )

        // Greenwich mean sidereal time.
        let theta0 = AstronomicalUtilities.normalize360(
            280.46061837
                + 360.98564736629 * (jd - 2451545.0)
                + 0.000387933 * T * T
                - T * T * T / 38710000.0
        )

        let localSiderealTime = AstronomicalUtilities.normalize360(
            theta0 + longitude
        )

        let hourAngle = AstronomicalUtilities.normalize180(
            localSiderealTime - rightAscension
        )

        // Altitude and azimuth.
        let sinAlt = AstronomicalUtilities.sind(latitude)
                * AstronomicalUtilities.sind(declination)
            + AstronomicalUtilities.cosd(latitude)
                * AstronomicalUtilities.cosd(declination)
                * AstronomicalUtilities.cosd(hourAngle)
        let altitude = AstronomicalUtilities.asind(max(-1, min(1, sinAlt)))

        let cosAlt = AstronomicalUtilities.cosd(altitude)
        let sinAz: Double
        let cosAz: Double
        if abs(cosAlt) < 1e-9 {
            sinAz = 0
            cosAz = -1
        } else {
            sinAz = -AstronomicalUtilities.cosd(declination)
                * AstronomicalUtilities.sind(hourAngle)
                / cosAlt
            cosAz = (AstronomicalUtilities.sind(declination)
                - AstronomicalUtilities.sind(altitude)
                    * AstronomicalUtilities.sind(latitude))
                / (cosAlt * AstronomicalUtilities.cosd(latitude))
        }
        let azimuth = AstronomicalUtilities.normalize360(
            AstronomicalUtilities.atan2d(sinAz, cosAz)
        )

        // Illuminated fraction.
        //
        // The phase angle is the sun–earth–moon angle, which equals the
        // ecliptic-longitude difference for the precision we need
        // (latitude effect is ~0.01% on illumination — negligible).
        // Mean solar longitude is reused from the solar formulas above
        // because we only need it modulo 360°.
        let L0Sun = AstronomicalUtilities.normalize360(
            280.46646 + 36000.76983 * T + 0.0003032 * T * T
        )
        let CSun = (1.914602 - 0.004817 * T) * AstronomicalUtilities.sind(Ms)
            + 0.019993 * AstronomicalUtilities.sind(2 * Ms)
        let trueSolarLongitude = AstronomicalUtilities.normalize360(L0Sun + CSun)

        let elongation = AstronomicalUtilities.normalize360(lambda - trueSolarLongitude)
        // illuminated fraction = (1 - cos(elongation)) / 2
        let illuminated = (1.0 - AstronomicalUtilities.cosd(elongation)) / 2.0

        // Waxing while moon's ecliptic longitude is ahead of the sun's
        // by less than 180° — i.e., during the new → full half of the
        // synodic month.
        let isWaxing = elongation < 180.0

        return LunarPosition(
            altitude: altitude,
            azimuth: azimuth,
            hourAngle: hourAngle,
            illuminatedFraction: max(0.0, min(1.0, illuminated)),
            isWaxing: isWaxing
        )
    }
}
