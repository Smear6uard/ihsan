import Foundation
import IhsanCore
import Testing
@testable import IhsanPrayerTimes

@Test
func beforeFajrNextPrayerIsFajrAndCurrentPrayerIsNil() throws {
    let provider = AdhanPrayerTimesProvider()
    let times = try makeChicagoTimes()
    let referenceDate = times.fajr.scheduledTime.addingTimeInterval(-60)

    let next = try provider.nextPrayer(
        from: referenceDate,
        coordinates: chicagoCoordinates,
        timeZone: chicagoTimeZone,
        calculationMethod: .isna,
        madhab: .standard,
        highLatitudeRule: .middleOfNight
    )
    let current = try provider.currentPrayer(
        at: referenceDate,
        coordinates: chicagoCoordinates,
        timeZone: chicagoTimeZone,
        calculationMethod: .isna,
        madhab: .standard,
        highLatitudeRule: .middleOfNight
    )

    #expect(next.prayer == .fajr)
    #expect(current == nil)
}

@Test
func betweenFajrAndDhuhrNextPrayerIsDhuhrAndCurrentPrayerIsFajr() throws {
    let provider = AdhanPrayerTimesProvider()
    let times = try makeChicagoTimes()
    let referenceDate = times.fajr.scheduledTime.addingTimeInterval(60)

    let next = try provider.nextPrayer(
        from: referenceDate,
        coordinates: chicagoCoordinates,
        timeZone: chicagoTimeZone,
        calculationMethod: .isna,
        madhab: .standard,
        highLatitudeRule: .middleOfNight
    )
    let current = try provider.currentPrayer(
        at: referenceDate,
        coordinates: chicagoCoordinates,
        timeZone: chicagoTimeZone,
        calculationMethod: .isna,
        madhab: .standard,
        highLatitudeRule: .middleOfNight
    )

    #expect(next.prayer == .dhuhr)
    #expect(current?.prayer == .fajr)
}

@Test
func afterIshaNextPrayerRollsOverToTomorrowFajrAndCurrentPrayerIsIsha() throws {
    let provider = AdhanPrayerTimesProvider()
    let times = try makeChicagoTimes()
    let referenceDate = times.isha.scheduledTime.addingTimeInterval(60)

    let next = try provider.nextPrayer(
        from: referenceDate,
        coordinates: chicagoCoordinates,
        timeZone: chicagoTimeZone,
        calculationMethod: .isna,
        madhab: .standard,
        highLatitudeRule: .middleOfNight
    )
    let current = try provider.currentPrayer(
        at: referenceDate,
        coordinates: chicagoCoordinates,
        timeZone: chicagoTimeZone,
        calculationMethod: .isna,
        madhab: .standard,
        highLatitudeRule: .middleOfNight
    )

    #expect(next.prayer == .fajr)
    #expect(next.scheduledTime > times.isha.scheduledTime)
    #expect(current?.prayer == .isha)
}

@Test
func exactlyAtFajrNextPrayerIsDhuhr() throws {
    let provider = AdhanPrayerTimesProvider()
    let times = try makeChicagoTimes()

    let next = try provider.nextPrayer(
        from: times.fajr.scheduledTime,
        coordinates: chicagoCoordinates,
        timeZone: chicagoTimeZone,
        calculationMethod: .isna,
        madhab: .standard,
        highLatitudeRule: .middleOfNight
    )
    let current = try provider.currentPrayer(
        at: times.fajr.scheduledTime,
        coordinates: chicagoCoordinates,
        timeZone: chicagoTimeZone,
        calculationMethod: .isna,
        madhab: .standard,
        highLatitudeRule: .middleOfNight
    )

    #expect(next.prayer == .dhuhr)
    #expect(current?.prayer == .fajr)
}

private let chicagoCoordinates = Coordinates(latitude: 41.8781, longitude: -87.6298)
private let chicagoTimeZone = TimeZone(identifier: "America/Chicago")!
