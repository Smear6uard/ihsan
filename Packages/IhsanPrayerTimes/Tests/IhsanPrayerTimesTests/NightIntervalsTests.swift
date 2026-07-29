import Foundation
import IhsanCore
import Testing
@testable import IhsanPrayerTimes

private func chicagoNight() throws -> NightIntervals {
    let provider = AdhanPrayerTimesProvider()
    return try provider.nightIntervals(
        for: fixedDate(),
        coordinates: Coordinates(latitude: 41.8781, longitude: -87.6298),
        timeZone: TimeZone(identifier: "America/Chicago")!,
        calculationMethod: .isna,
        madhab: .standard,
        highLatitudeRule: .middleOfNight
    )
}

@Test
func nisfAlLaylBisectsTheNightSpanExactly() throws {
    let night = try chicagoNight()

    #expect(night.nisfAlLayl == night.start.addingTimeInterval(night.span / 2))
    #expect(night.nisfAlLayl > night.start)
    #expect(night.nisfAlLayl < night.end)
}

@Test
func providerNightSpansTodayMaghribToTomorrowTrueFajr() throws {
    let provider = AdhanPrayerTimesProvider()
    let coordinates = Coordinates(latitude: 41.8781, longitude: -87.6298)
    let timeZone = TimeZone(identifier: "America/Chicago")!

    let today = try provider.dayTimes(
        for: fixedDate(), coordinates: coordinates, timeZone: timeZone,
        calculationMethod: .isna, madhab: .standard, highLatitudeRule: .middleOfNight
    )
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let tomorrow = try provider.dayTimes(
        for: try #require(calendar.date(byAdding: .day, value: 1, to: fixedDate())),
        coordinates: coordinates, timeZone: timeZone,
        calculationMethod: .isna, madhab: .standard, highLatitudeRule: .middleOfNight
    )

    let night = try chicagoNight()
    #expect(night.start == today.maghrib.scheduledTime)
    #expect(night.end == tomorrow.fajr.scheduledTime)
}

@Test
func thirdsShareExactBoundariesWithSpanAndEachOther() throws {
    let night = try chicagoNight()

    #expect(night.firstThird.start == night.start)
    #expect(night.firstThird.end == night.middleThird.start)
    #expect(night.middleThird.end == night.lastThird.start)
    #expect(night.lastThird.end == night.end)
    #expect(night.lastThirdStart == night.lastThird.start)
}

/// Property: for arbitrary night spans (fractional seconds included), the three
/// thirds always partition [maghrib, fajr] exactly — shared boundaries, no gaps,
/// no overlap, durations summing to the span.
@Test
func thirdsAlwaysPartitionTheSpanExactly() throws {
    var seed: UInt64 = 0x1DE5_CA1E_5EED
    func nextRandom() -> Double {
        seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Double(seed >> 11) / Double(UInt64.max >> 11)
    }

    for _ in 0..<500 {
        let maghrib = Date(timeIntervalSince1970: 1_700_000_000 + nextRandom() * 300_000_000)
        // 3h compressed high-latitude nights through 21h polar winters.
        let span = 3 * 3600 + nextRandom() * 18 * 3600
        let night = try NightIntervals(maghrib: maghrib, nextFajr: maghrib.addingTimeInterval(span))

        #expect(night.firstThird.start == night.start)
        #expect(night.firstThird.end == night.middleThird.start)
        #expect(night.middleThird.end == night.lastThird.start)
        #expect(night.lastThird.end == night.end)

        let summed = night.firstThird.duration + night.middleThird.duration + night.lastThird.duration
        #expect(abs(summed - night.span) < 0.000_001)
        #expect(abs(night.firstThird.duration - night.span / 3) < 0.000_001)
        #expect(night.nisfAlLayl == night.start.addingTimeInterval(night.span / 2))
    }
}

@Test
func nightMathAgreesWithAdhanSunnahTimesWithinRounding() throws {
    // Adhan rounds sunnah times to the minute; our intervals are exact.
    let provider = AdhanPrayerTimesProvider()
    let today = try makeChicagoTimes()
    let night = try provider.nightIntervals(
        for: fixedDate(),
        coordinates: Coordinates(latitude: 41.8781, longitude: -87.6298),
        timeZone: TimeZone(identifier: "America/Chicago")!,
        calculationMethod: .isna,
        madhab: .standard,
        highLatitudeRule: .middleOfNight
    )

    #expect(abs(night.nisfAlLayl.timeIntervalSince(today.middleOfTheNight)) <= 60)
    #expect(abs(night.lastThirdStart.timeIntervalSince(today.lastThirdOfTheNight)) <= 60)
}

@Test(arguments: [
    // Night containing the US spring-forward (2026-03-08 02:00 CST → CDT).
    "2026-03-07T18:00:00Z",
    // Night containing the US fall-back (2026-11-01 02:00 CDT → CST).
    "2026-10-31T18:00:00Z",
])
func dstTransitionNightsStayExactUnderIntervalArithmetic(dateUTC: String) throws {
    let provider = AdhanPrayerTimesProvider()
    let coordinates = Coordinates(latitude: 41.8781, longitude: -87.6298)
    let timeZone = TimeZone(identifier: "America/Chicago")!
    let date = try #require(ISO8601DateFormatter().date(from: dateUTC))

    let night = try provider.nightIntervals(
        for: date, coordinates: coordinates, timeZone: timeZone,
        calculationMethod: .isna, madhab: .standard, highLatitudeRule: .middleOfNight
    )

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let tomorrow = try provider.dayTimes(
        for: try #require(calendar.date(byAdding: .day, value: 1, to: date)),
        coordinates: coordinates, timeZone: timeZone,
        calculationMethod: .isna, madhab: .standard, highLatitudeRule: .middleOfNight
    )

    // The span is absolute-instant arithmetic: it must equal the true distance
    // to tomorrow's Fajr regardless of the wall-clock hour lost or gained.
    #expect(night.end == tomorrow.fajr.scheduledTime)
    #expect(night.span == tomorrow.fajr.scheduledTime.timeIntervalSince(night.start))
    #expect(night.firstThird.end == night.middleThird.start)
    #expect(night.middleThird.end == night.lastThird.start)
    #expect(night.nisfAlLayl > night.start && night.nisfAlLayl < night.end)
}

@Test
func highLatitudeSummerNightResolvesWheneverFardTimesDo() throws {
    // Oslo, 59.9°N, summer solstice — the compressed night must still divide.
    let provider = AdhanPrayerTimesProvider()
    let night = try provider.nightIntervals(
        for: try #require(ISO8601DateFormatter().date(from: "2026-06-21T12:00:00Z")),
        coordinates: Coordinates(latitude: 59.9139, longitude: 10.7522),
        timeZone: TimeZone(identifier: "Europe/Oslo")!,
        calculationMethod: .muslimWorldLeague,
        madhab: .standard,
        highLatitudeRule: .middleOfNight
    )

    #expect(night.span > 0)
    #expect(night.start < night.nisfAlLayl)
    #expect(night.nisfAlLayl < night.lastThirdStart)
    #expect(night.lastThirdStart < night.end)
}

@Test
func invertedNightInputsThrow() {
    let maghrib = Date(timeIntervalSince1970: 1_778_893_440)
    #expect(throws: PrayerTimesError.self) {
        try NightIntervals(maghrib: maghrib, nextFajr: maghrib.addingTimeInterval(-60))
    }
    #expect(throws: PrayerTimesError.self) {
        try NightIntervals(maghrib: maghrib, nextFajr: maghrib)
    }
}

@Test
func duhaWindowUsesConfigurableOffsetsWithNeutralDefaults() throws {
    let sunrise = Date(timeIntervalSince1970: 1_778_841_000)
    let dhuhr = Date(timeIntervalSince1970: 1_778_867_280)

    let defaulted = try #require(DuhaWindow(sunrise: sunrise, dhuhr: dhuhr))
    #expect(defaulted.start == sunrise.addingTimeInterval(20 * 60))
    #expect(defaulted.end == dhuhr.addingTimeInterval(-15 * 60))

    let custom = try #require(
        DuhaWindow(sunrise: sunrise, dhuhr: dhuhr, sunriseOffset: 45 * 60, dhuhrMargin: 30 * 60)
    )
    #expect(custom.start == sunrise.addingTimeInterval(45 * 60))
    #expect(custom.end == dhuhr.addingTimeInterval(-30 * 60))
}

@Test
func duhaWindowCollapsesToNilWhenOffsetsMeet() {
    let sunrise = Date(timeIntervalSince1970: 1_778_841_000)
    let dhuhr = sunrise.addingTimeInterval(30 * 60)

    #expect(DuhaWindow(sunrise: sunrise, dhuhr: dhuhr) == nil)
}

@Test
func providerDuhaWindowDerivesFromSunriseAndDhuhr() throws {
    let provider = AdhanPrayerTimesProvider()
    let today = try makeChicagoTimes()
    let window = try #require(
        try provider.duhaWindow(
            for: fixedDate(),
            coordinates: Coordinates(latitude: 41.8781, longitude: -87.6298),
            timeZone: TimeZone(identifier: "America/Chicago")!,
            calculationMethod: .isna,
            madhab: .standard,
            highLatitudeRule: .middleOfNight
        )
    )

    #expect(window.start == today.sunrise.addingTimeInterval(20 * 60))
    #expect(window.end == today.dhuhr.scheduledTime.addingTimeInterval(-15 * 60))
}
