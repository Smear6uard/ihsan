import CoreGraphics
import Foundation
import Testing
@testable import IhsanDesignSystem

// MARK: - Julian Date

@Test
func julianDateAtJ2000IsCorrect() {
    // J2000.0 epoch: 2000-01-01 12:00:00 UTC = JD 2451545.0
    var components = DateComponents()
    components.timeZone = TimeZone(identifier: "UTC")
    components.year = 2000
    components.month = 1
    components.day = 1
    components.hour = 12
    components.minute = 0
    components.second = 0
    let date = Calendar(identifier: .gregorian).date(from: components)!
    let jd = AstronomicalUtilities.julianDate(from: date)
    #expect(abs(jd - 2451545.0) < 1e-6, "JD at J2000.0 was \(jd), expected 2451545.0")
}

@Test
func julianDateAdvancesOneUnitPerDay() {
    var components = DateComponents()
    components.timeZone = TimeZone(identifier: "UTC")
    components.year = 2024
    components.month = 6
    components.day = 1
    components.hour = 0
    let day1 = Calendar(identifier: .gregorian).date(from: components)!
    components.day = 2
    let day2 = Calendar(identifier: .gregorian).date(from: components)!
    let jd1 = AstronomicalUtilities.julianDate(from: day1)
    let jd2 = AstronomicalUtilities.julianDate(from: day2)
    #expect(abs((jd2 - jd1) - 1.0) < 1e-6, "JD step across one day was \(jd2 - jd1), expected 1.0")
}

// MARK: - Angle normalization

@Test
func normalize360WrapsCorrectly() {
    #expect(AstronomicalUtilities.normalize360(0) == 0)
    #expect(AstronomicalUtilities.normalize360(360).isApproximately(0))
    #expect(AstronomicalUtilities.normalize360(370).isApproximately(10))
    #expect(AstronomicalUtilities.normalize360(-10).isApproximately(350))
    #expect(AstronomicalUtilities.normalize360(720).isApproximately(0))
}

@Test
func normalize180WrapsCorrectly() {
    #expect(AstronomicalUtilities.normalize180(0) == 0)
    #expect(AstronomicalUtilities.normalize180(180).isApproximately(-180))
    #expect(AstronomicalUtilities.normalize180(190).isApproximately(-170))
    #expect(AstronomicalUtilities.normalize180(-190).isApproximately(170))
}

// MARK: - SolarPosition: known checkpoints

@Test
func solarNoonAtEquatorOnMarchEquinoxIsNearZenith() {
    // 2026-03-20 ~ 12:00 UTC, sun at lat 0, lng 0.
    // Vernal equinox: declination ~0, so altitude at "clock noon" at
    // longitude 0 should be close to the zenith. The exact maximum is
    // offset by the equation of time (±~15 min, ~±4° hour angle), so
    // we tolerate altitudes > 86° rather than the literal 90° zenith.
    var components = DateComponents()
    components.timeZone = TimeZone(identifier: "UTC")
    components.year = 2026
    components.month = 3
    components.day = 20
    components.hour = 12
    let date = Calendar(identifier: .gregorian).date(from: components)!
    let pos = SolarPosition.compute(at: date, latitude: 0, longitude: 0)
    #expect(pos.altitude > 86.0, "equator equinox altitude was \(pos.altitude)°, expected > 86°")
    #expect(abs(pos.hourAngle) < 4.0, "hour angle at clock noon UTC at lng 0 was \(pos.hourAngle)°, expected within ±4° (equation of time)")
}

@Test
func solarNoonAtNapervilleInSummerIsHighInSouthSky() {
    // Naperville, IL: ~41.78°N, -88.15°E. Sun reaches max altitude on
    // summer solstice (~June 21). Solar noon at this longitude ~
    // 12:00 + (88.15 / 15) hours = 17:53 UTC. Max altitude ≈ 90 -
    // (lat - decl) = 90 - (41.78 - 23.44) = 71.66°.
    var components = DateComponents()
    components.timeZone = TimeZone(identifier: "UTC")
    components.year = 2026
    components.month = 6
    components.day = 21
    components.hour = 17
    components.minute = 53
    let date = Calendar(identifier: .gregorian).date(from: components)!
    let pos = SolarPosition.compute(at: date, latitude: 41.78, longitude: -88.15)
    #expect(abs(pos.altitude - 71.66) < 2.0, "Naperville summer solar-noon altitude was \(pos.altitude)°, expected ~71.66°")
    // Azimuth should be ~180° (due south) within a couple of degrees.
    #expect(abs(pos.azimuth - 180.0) < 5.0, "azimuth at solar noon was \(pos.azimuth)°, expected ~180°")
}

@Test
func solarHourAngleIsNegativeBeforeNoon() {
    // 06:00 UTC at lng 0 — well before solar noon (12:00).
    var components = DateComponents()
    components.timeZone = TimeZone(identifier: "UTC")
    components.year = 2026
    components.month = 6
    components.day = 1
    components.hour = 6
    let date = Calendar(identifier: .gregorian).date(from: components)!
    let pos = SolarPosition.compute(at: date, latitude: 0, longitude: 0)
    #expect(pos.hourAngle < 0, "hour angle at 06:00 UTC at lng 0 was \(pos.hourAngle)°, expected negative")
}

@Test
func solarHourAngleIsPositiveAfterNoon() {
    var components = DateComponents()
    components.timeZone = TimeZone(identifier: "UTC")
    components.year = 2026
    components.month = 6
    components.day = 1
    components.hour = 18
    let date = Calendar(identifier: .gregorian).date(from: components)!
    let pos = SolarPosition.compute(at: date, latitude: 0, longitude: 0)
    #expect(pos.hourAngle > 0, "hour angle at 18:00 UTC at lng 0 was \(pos.hourAngle)°, expected positive")
}

@Test
func solarAltitudeIsNegativeAtLocalMidnight() {
    // Local midnight at Naperville (UTC-5 CDT in June) is 05:00 UTC.
    // At that moment the sun is well below the horizon in the
    // northern hemisphere — about 30° below the horizon at June 1.
    var components = DateComponents()
    components.timeZone = TimeZone(identifier: "UTC")
    components.year = 2026
    components.month = 6
    components.day = 1
    components.hour = 5
    let date = Calendar(identifier: .gregorian).date(from: components)!
    let pos = SolarPosition.compute(at: date, latitude: 41.78, longitude: -88.15)
    #expect(pos.altitude < 0, "altitude at Naperville local midnight (05:00 UTC) was \(pos.altitude)°, expected negative (sun below horizon)")
}

@Test
func solarDeclinationRangesWithinTropics() {
    // The sun's declination varies between ±23.44° over a year.
    // Check several months — declination should stay in range with
    // headroom for the approximation.
    let months = [3, 6, 9, 12]
    for month in months {
        var components = DateComponents()
        components.timeZone = TimeZone(identifier: "UTC")
        components.year = 2026
        components.month = month
        components.day = 15
        components.hour = 12
        let date = Calendar(identifier: .gregorian).date(from: components)!
        let pos = SolarPosition.compute(at: date, latitude: 0, longitude: 0)
        #expect(abs(pos.declination) <= 23.5, "declination in month \(month) was \(pos.declination)°, expected within ±23.5°")
    }
}

// MARK: - LunarPosition: known checkpoints

@Test
func lunarIlluminationIsZeroAtNewMoon() {
    // 2026-05-16 is a known new-moon date (within a day of). Verify
    // illuminated fraction is small.
    var components = DateComponents()
    components.timeZone = TimeZone(identifier: "UTC")
    components.year = 2026
    components.month = 5
    components.day = 16
    components.hour = 12
    let date = Calendar(identifier: .gregorian).date(from: components)!
    let pos = LunarPosition.compute(at: date, latitude: 41.78, longitude: -88.15)
    #expect(pos.illuminatedFraction < 0.10, "illumination near new moon was \(pos.illuminatedFraction), expected < 0.10")
}

@Test
func lunarIlluminationIsNearFullAtFullMoon() {
    // 2026-05-31 is a known full-moon date. Verify illuminated
    // fraction is near 1.0.
    var components = DateComponents()
    components.timeZone = TimeZone(identifier: "UTC")
    components.year = 2026
    components.month = 5
    components.day = 31
    components.hour = 12
    let date = Calendar(identifier: .gregorian).date(from: components)!
    let pos = LunarPosition.compute(at: date, latitude: 41.78, longitude: -88.15)
    #expect(pos.illuminatedFraction > 0.90, "illumination near full moon was \(pos.illuminatedFraction), expected > 0.90")
}

@Test
func lunarIlluminationProgressesAcrossSynodicMonth() {
    // Sample across a full month and verify illumination rises and
    // falls. Total monotonic-rise span should cover the new → full
    // half of the synodic cycle; we don't need to pin specific values,
    // just that the function isn't a constant.
    var components = DateComponents()
    components.timeZone = TimeZone(identifier: "UTC")
    components.year = 2026
    components.month = 5
    components.hour = 12
    var samples: [Double] = []
    for day in stride(from: 1, through: 31, by: 2) {
        components.day = day
        let date = Calendar(identifier: .gregorian).date(from: components)!
        let pos = LunarPosition.compute(at: date, latitude: 0, longitude: 0)
        samples.append(pos.illuminatedFraction)
    }
    let minimum = samples.min() ?? 0
    let maximum = samples.max() ?? 0
    #expect(minimum < 0.10, "min illumination in May 2026 was \(minimum), expected < 0.10")
    #expect(maximum > 0.90, "max illumination in May 2026 was \(maximum), expected > 0.90")
}

@Test
func lunarWaxingFlagFlipsAtFullMoon() {
    // Pre-full-moon: waxing. Post-full-moon: waning.
    var components = DateComponents()
    components.timeZone = TimeZone(identifier: "UTC")
    components.year = 2026
    components.month = 5
    components.hour = 12

    components.day = 24 // pre-full-moon
    let preDate = Calendar(identifier: .gregorian).date(from: components)!
    let pre = LunarPosition.compute(at: preDate, latitude: 0, longitude: 0)

    components.day = 7 // post-full-moon (early May, after April 30 full moon)
    let postDate = Calendar(identifier: .gregorian).date(from: components)!
    let post = LunarPosition.compute(at: postDate, latitude: 0, longitude: 0)

    #expect(pre.isWaxing, "expected pre-full-moon to be waxing")
    #expect(!post.isWaxing, "expected post-full-moon to be waning")
}

// MARK: - CelestialMapping

@Test
func mappingAtHourAngleZeroIsCentered() {
    let size = CGSize(width: 400, height: 600)
    let point = CelestialMapping.screenPosition(
        hourAngle: 0,
        altitude: 45,
        in: size
    )
    #expect(abs(point.x - size.width / 2) < 0.5, "hour angle 0 should map to horizontal center, got \(point.x) on width \(size.width)")
}

@Test
func mappingAtHourAngleNegativeSpanIsLeftEdge() {
    let size = CGSize(width: 400, height: 600)
    let inset = CelestialMapping.defaultHorizontalInset
    let point = CelestialMapping.screenPosition(
        hourAngle: -CelestialMapping.defaultHourAngleSpan / 2.0,
        altitude: 0,
        in: size
    )
    #expect(abs(point.x - inset) < 0.5, "hour angle -span/2 should map to left inset \(inset), got \(point.x)")
}

@Test
func mappingAtHourAnglePositiveSpanIsRightEdge() {
    let size = CGSize(width: 400, height: 600)
    let inset = CelestialMapping.defaultHorizontalInset
    let point = CelestialMapping.screenPosition(
        hourAngle: CelestialMapping.defaultHourAngleSpan / 2.0,
        altitude: 0,
        in: size
    )
    let expected = size.width - inset
    #expect(abs(point.x - expected) < 0.5, "hour angle +span/2 should map to right edge \(expected), got \(point.x)")
}

@Test
func mappingAtZenithIsTopOfScene() {
    let size = CGSize(width: 400, height: 600)
    let inset = CelestialMapping.defaultVerticalInset
    let point = CelestialMapping.screenPosition(
        hourAngle: 0,
        altitude: 90,
        in: size
    )
    #expect(abs(point.y - inset) < 0.5, "zenith (alt 90°) should map to top inset \(inset), got \(point.y)")
}

@Test
func mappingAtHorizonIsNearBottomOfScene() {
    let size = CGSize(width: 400, height: 600)
    let point = CelestialMapping.screenPosition(
        hourAngle: 0,
        altitude: 0,
        in: size
    )
    // Altitude 0 maps to within the [-15, 90] range. With altitude min
    // -15, altitude 0 is at fraction (90-0)/105 = 0.857 down from top.
    // y = vertical inset + 0.857 * usable height.
    let inset = CelestialMapping.defaultVerticalInset
    let usable = size.height - inset * 2
    let expected = inset + CGFloat(90.0 / 105.0) * usable
    #expect(abs(point.y - expected) < 0.5, "horizon altitude should map near bottom, expected \(expected), got \(point.y)")
}

@Test
func mappingClampsOutOfRangeValues() {
    let size = CGSize(width: 400, height: 600)
    // Hour angle far below -span/2: clamp to left edge.
    let farLeft = CelestialMapping.screenPosition(hourAngle: -500, altitude: 45, in: size)
    let edgeLeft = CelestialMapping.screenPosition(hourAngle: -CelestialMapping.defaultHourAngleSpan / 2.0, altitude: 45, in: size)
    #expect(abs(farLeft.x - edgeLeft.x) < 0.5, "extreme negative hour angle should clamp to left edge")
}

// MARK: - Helpers

private extension Double {
    func isApproximately(_ other: Double, tolerance: Double = 1e-6) -> Bool {
        abs(self - other) < tolerance
    }
}
