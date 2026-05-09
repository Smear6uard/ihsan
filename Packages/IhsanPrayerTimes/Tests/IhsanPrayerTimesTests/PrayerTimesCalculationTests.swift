import Foundation
import IhsanCore
import Testing
@testable import IhsanPrayerTimes

@Test
func knownLocationProducesChronologicalFardhTimes() throws {
    let times = try makeChicagoTimes()
    let scheduledTimes = times.allFardh.map(\.scheduledTime)

    #expect(times.allFardh.map(\.prayer) == [.fajr, .dhuhr, .asr, .maghrib, .isha])
    #expect(scheduledTimes == scheduledTimes.sorted())
    #expect(Set(scheduledTimes).count == 5)
}

@Test
func ishaInChicagoUsingISNA() throws {
    let times = try makeChicagoTimes()
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!

    let ishaHour = calendar.component(.hour, from: times.isha.scheduledTime)
    #expect(ishaHour >= 1 && ishaHour <= 5)
}

@Test
func meccaUsingUmmAlQuraProducesCompleteDay() throws {
    let provider = AdhanPrayerTimesProvider()
    let times = try provider.dayTimes(
        for: fixedDate(),
        coordinates: Coordinates(latitude: 21.4225, longitude: 39.8262),
        timeZone: TimeZone(identifier: "Asia/Riyadh")!,
        calculationMethod: .ummAlQura,
        madhab: .standard,
        highLatitudeRule: .middleOfNight
    )

    #expect(times.fajr.prayer == .fajr)
    #expect(times.sunrise > times.fajr.scheduledTime)
    #expect(times.isha.scheduledTime > times.maghrib.scheduledTime)
}

@Test
func hanafiAsrIsLaterThanStandardAsr() throws {
    let provider = AdhanPrayerTimesProvider()
    let coordinates = Coordinates(latitude: 41.8781, longitude: -87.6298)
    let timeZone = TimeZone(identifier: "America/Chicago")!

    let standard = try provider.dayTimes(
        for: fixedDate(),
        coordinates: coordinates,
        timeZone: timeZone,
        calculationMethod: .isna,
        madhab: .standard,
        highLatitudeRule: .middleOfNight
    )
    let hanafi = try provider.dayTimes(
        for: fixedDate(),
        coordinates: coordinates,
        timeZone: timeZone,
        calculationMethod: .isna,
        madhab: .hanafi,
        highLatitudeRule: .middleOfNight
    )

    #expect(hanafi.asr.scheduledTime > standard.asr.scheduledTime)
}

@Test
func calculationMethodsProduceDifferentFajrAndIsha() throws {
    let provider = AdhanPrayerTimesProvider()
    let coordinates = Coordinates(latitude: 41.8781, longitude: -87.6298)
    let timeZone = TimeZone(identifier: "America/Chicago")!

    let isna = try provider.dayTimes(
        for: fixedDate(),
        coordinates: coordinates,
        timeZone: timeZone,
        calculationMethod: .isna,
        madhab: .standard,
        highLatitudeRule: .middleOfNight
    )
    let egyptian = try provider.dayTimes(
        for: fixedDate(),
        coordinates: coordinates,
        timeZone: timeZone,
        calculationMethod: .egyptian,
        madhab: .standard,
        highLatitudeRule: .middleOfNight
    )

    #expect(egyptian.fajr.scheduledTime != isna.fajr.scheduledTime)
    #expect(egyptian.isha.scheduledTime != isna.isha.scheduledTime)
}

@Test
func sunnahTimesFallWithinExpectedNightWindow() throws {
    let provider = AdhanPrayerTimesProvider()
    let timeZone = TimeZone(identifier: "America/Chicago")!
    let coordinates = Coordinates(latitude: 41.8781, longitude: -87.6298)
    let today = try makeChicagoTimes()

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let tomorrowDate = try #require(calendar.date(byAdding: .day, value: 1, to: fixedDate()))
    let tomorrow = try provider.dayTimes(
        for: tomorrowDate,
        coordinates: coordinates,
        timeZone: timeZone,
        calculationMethod: .isna,
        madhab: .standard,
        highLatitudeRule: .middleOfNight
    )

    #expect(today.middleOfTheNight > today.maghrib.scheduledTime)
    #expect(today.middleOfTheNight < tomorrow.fajr.scheduledTime)
    #expect(today.lastThirdOfTheNight > today.middleOfTheNight)
    #expect(today.lastThirdOfTheNight < tomorrow.fajr.scheduledTime)
}

@Test
func allFardhArrayIsChronological() throws {
    let times = try makeChicagoTimes()

    for index in times.allFardh.indices.dropFirst() {
        #expect(times.allFardh[index].scheduledTime > times.allFardh[index - 1].scheduledTime)
    }
}

func fixedDate() -> Date {
    ISO8601DateFormatter().date(from: "2026-05-15T12:00:00Z")!
}

func makeChicagoTimes() throws -> DayPrayerTimes {
    let provider = AdhanPrayerTimesProvider()
    return try provider.dayTimes(
        for: fixedDate(),
        coordinates: Coordinates(latitude: 41.8781, longitude: -87.6298),
        timeZone: TimeZone(identifier: "America/Chicago")!,
        calculationMethod: .isna,
        madhab: .standard,
        highLatitudeRule: .middleOfNight
    )
}
