import Foundation
import Testing
@testable import IhsanCore

@Test
func detectsRamadanFromShabanBoundary() throws {
    var calendar = Calendar(identifier: .islamicUmmAlQura)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!

    let ramadanStart = try #require(
        calendar.date(from: DateComponents(year: 1447, month: 9, day: 1, hour: 12))
    )
    let shabanFinalDay = try #require(
        calendar.date(byAdding: .day, value: -1, to: ramadanStart)
    )

    #expect(!RamadanContext.isCurrentlyRamadan(at: shabanFinalDay, calendar: calendar))
    #expect(RamadanContext.isCurrentlyRamadan(at: ramadanStart, calendar: calendar))
    #expect(RamadanContext.daysIntoRamadan(at: ramadanStart, calendar: calendar) == 1)
}

@Test
func detectsShawwalFromRamadanBoundary() throws {
    var calendar = Calendar(identifier: .islamicUmmAlQura)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!

    let ramadanStart = try #require(
        calendar.date(from: DateComponents(year: 1447, month: 9, day: 1, hour: 12))
    )
    let ramadanLength = try #require(
        calendar.range(of: .day, in: .month, for: ramadanStart)?.count
    )
    let ramadanFinalDay = try #require(
        calendar.date(from: DateComponents(year: 1447, month: 9, day: ramadanLength, hour: 12))
    )
    let shawwalStart = try #require(
        calendar.date(byAdding: .day, value: 1, to: ramadanFinalDay)
    )

    #expect(RamadanContext.isCurrentlyRamadan(at: ramadanFinalDay, calendar: calendar))
    #expect(RamadanContext.daysIntoRamadan(at: ramadanFinalDay, calendar: calendar) == ramadanLength)
    #expect(RamadanContext.daysRemainingInRamadan(at: ramadanFinalDay, calendar: calendar) == 0)
    #expect(!RamadanContext.isCurrentlyRamadan(at: shawwalStart, calendar: calendar))
}

@Test
func honorsCalendarTimeZoneNearInternationalDateLine() throws {
    var kiritimatiCalendar = Calendar(identifier: .islamicUmmAlQura)
    kiritimatiCalendar.timeZone = try #require(TimeZone(identifier: "Pacific/Kiritimati"))

    var adakCalendar = Calendar(identifier: .islamicUmmAlQura)
    adakCalendar.timeZone = try #require(TimeZone(identifier: "America/Adak"))

    let kiritimatiRamadanStart = try #require(
        kiritimatiCalendar.date(from: DateComponents(year: 1447, month: 9, day: 1, hour: 0, minute: 30))
    )

    #expect(RamadanContext.isCurrentlyRamadan(at: kiritimatiRamadanStart, calendar: kiritimatiCalendar))
    #expect(!RamadanContext.isCurrentlyRamadan(at: kiritimatiRamadanStart, calendar: adakCalendar))
}
