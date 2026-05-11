import Foundation

/// The sun's position in the local sky at a given moment.
///
/// Computed via the NOAA solar position algorithm (the same algorithm
/// underlying the calculator at gml.noaa.gov/grad/solcalc). Accurate to
/// ~0.01° for any date within ±100 years of the current epoch — well
/// within the accuracy budget for the celestial scene, which renders the
/// sun as a 48pt ornament.
///
/// The instance carries altitude, azimuth, hour angle, and declination.
/// The celestial scene's screen-position mapping consumes `altitude` +
/// `hourAngle` directly (see `CelestialMapping`); other call sites can
/// reach for azimuth (for shadow-direction hints) or declination (for
/// season visualisation in future iterations).
public struct SolarPosition: Sendable, Equatable {

    /// Altitude in degrees above the local horizon. 0° = on the
    /// horizon, 90° = at the zenith, negative = below the horizon
    /// (i.e., the sun is "below" the user — night, or before sunrise).
    public let altitude: Double

    /// Azimuth in degrees from due north, measured clockwise. 0° =
    /// north, 90° = east, 180° = south, 270° = west.
    public let azimuth: Double

    /// Local hour angle in degrees. Negative before solar noon (morning),
    /// zero at solar noon, positive after solar noon (afternoon).
    /// Conventionally, the sun's hour angle is ~-90° at sunrise on the
    /// equator at equinox and ~+90° at sunset on the same day.
    public let hourAngle: Double

    /// Solar declination in degrees — the angle between the sun's rays
    /// and the equatorial plane of the Earth. Varies between ±23.44°
    /// over a year (winter solstice / summer solstice).
    public let declination: Double

    /// Compute the sun's position at the given moment for the given
    /// observer location.
    ///
    /// - Parameters:
    ///   - date: The moment in absolute time. UTC handling is internal
    ///     to the function — pass `Date.now` directly.
    ///   - latitude: Observer latitude in degrees. Positive north,
    ///     negative south.
    ///   - longitude: Observer longitude in degrees. Positive east,
    ///     negative west.
    public static func compute(
        at date: Date,
        latitude: Double,
        longitude: Double
    ) -> SolarPosition {
        let jd = AstronomicalUtilities.julianDate(from: date)
        let T = AstronomicalUtilities.julianCentury(julianDate: jd)

        // Geometric mean longitude of the sun (degrees), normalised.
        let L0 = AstronomicalUtilities.normalize360(
            280.46646 + 36000.76983 * T + 0.0003032 * T * T
        )

        // Geometric mean anomaly of the sun (degrees).
        let M = 357.52911 + 35999.05029 * T - 0.0001537 * T * T

        // Eccentricity of Earth's orbit.
        let e = 0.016708634 - 0.000042037 * T - 0.0000001267 * T * T
        _ = e  // currently unused — kept inline for completeness; the
               // formulas below are independent of e because we drop the
               // distance R from the position calculation (purely
               // visual).

        // Equation of center (degrees).
        let C = (1.914602 - 0.004817 * T - 0.000014 * T * T)
                * AstronomicalUtilities.sind(M)
            + (0.019993 - 0.000101 * T)
                * AstronomicalUtilities.sind(2 * M)
            + 0.000289
                * AstronomicalUtilities.sind(3 * M)

        // True longitude of the sun.
        let trueLongitude = L0 + C

        // Apparent longitude (corrected for nutation / aberration).
        let omega = 125.04 - 1934.136 * T
        let apparentLongitude = trueLongitude
            - 0.00569
            - 0.00478 * AstronomicalUtilities.sind(omega)

        // Mean obliquity of the ecliptic (degrees).
        let eps0 = 23.0 + (26.0 + 21.448 / 60.0) / 60.0
            - (46.8150 * T + 0.00059 * T * T - 0.001813 * T * T * T) / 3600.0

        // Corrected obliquity.
        let epsCorrected = eps0 + 0.00256 * AstronomicalUtilities.cosd(omega)

        // Declination — the equatorial-plane angle of the sun's rays.
        let declination = AstronomicalUtilities.asind(
            AstronomicalUtilities.sind(epsCorrected)
                * AstronomicalUtilities.sind(apparentLongitude)
        )

        // Right ascension.
        let rightAscension = AstronomicalUtilities.normalize360(
            AstronomicalUtilities.atan2d(
                AstronomicalUtilities.cosd(epsCorrected)
                    * AstronomicalUtilities.sind(apparentLongitude),
                AstronomicalUtilities.cosd(apparentLongitude)
            )
        )

        // Greenwich mean sidereal time (degrees).
        let theta0 = AstronomicalUtilities.normalize360(
            280.46061837
                + 360.98564736629 * (jd - 2451545.0)
                + 0.000387933 * T * T
                - T * T * T / 38710000.0
        )

        // Local sidereal time; equivalent to GMST + observer longitude.
        let localSiderealTime = AstronomicalUtilities.normalize360(theta0 + longitude)

        // Local hour angle of the sun (degrees), wrapped to [-180, 180).
        let hourAngle = AstronomicalUtilities.normalize180(
            localSiderealTime - rightAscension
        )

        // Altitude.
        let sinAlt = AstronomicalUtilities.sind(latitude)
                * AstronomicalUtilities.sind(declination)
            + AstronomicalUtilities.cosd(latitude)
                * AstronomicalUtilities.cosd(declination)
                * AstronomicalUtilities.cosd(hourAngle)
        let altitude = AstronomicalUtilities.asind(max(-1, min(1, sinAlt)))

        // Azimuth, measured from due north, clockwise.
        let cosAlt = AstronomicalUtilities.cosd(altitude)
        let sinAz: Double
        let cosAz: Double
        if abs(cosAlt) < 1e-9 {
            // Sun is at zenith or nadir — azimuth degenerate. Return 180
            // (due south) as a deterministic placeholder; the celestial
            // mapping ignores azimuth at the zenith because hour angle
            // already pins the x-coordinate.
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

        return SolarPosition(
            altitude: altitude,
            azimuth: azimuth,
            hourAngle: hourAngle,
            declination: declination
        )
    }
}
