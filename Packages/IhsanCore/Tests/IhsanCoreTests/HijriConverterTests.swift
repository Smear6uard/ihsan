import Foundation
import Testing
@testable import IhsanCore

/// THE one Hijri converter's contract: the base tabulation agrees
/// with Umm al-Qura, the moonsighting adjustment shifts the mapping
/// by exactly its day count in both directions, the month grid
/// round-trips through the same mapping, and the curated significant
/// days fire on their dates and nowhere else.
@Suite("Hijri converter")
struct HijriConverterTests {

    private let timeZone = TimeZone(identifier: "America/Chicago")!

    private var hijriCalendar: Calendar {
        var calendar = Calendar(identifier: .islamicUmmAlQura)
        calendar.timeZone = timeZone
        return calendar
    }

    private var civilCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    /// Noon on the civil day containing the given Hijri date.
    private func noon(hijriYear: Int, month: Int, day: Int) throws -> Date {
        let start = try #require(hijriCalendar.date(
            from: DateComponents(year: hijriYear, month: month, day: day)
        ))
        return try #require(civilCalendar.date(
            bySettingHour: 12, minute: 0, second: 0, of: start
        ))
    }

    // MARK: - Base conversion

    @Test
    func zeroOffsetAgreesWithUmmAlQura() {
        // Sweep two years of days: the converter at offset 0 IS the
        // tabulation.
        var date = Date(timeIntervalSinceReferenceDate: 790_000_000)
        for _ in 0..<730 {
            let expected = hijriCalendar.dateComponents([.year, .month, .day], from: date)
            let actual = HijriConverter.components(for: date, offsetDays: 0, timeZone: timeZone)
            #expect(actual.year == expected.year)
            #expect(actual.month == expected.month)
            #expect(actual.day == expected.day)
            date = date.addingTimeInterval(86_400)
        }
    }

    /// The adjustment shifts the mapping by exactly its day count:
    /// reading today with +k equals reading k civil days ahead with 0.
    @Test(arguments: [-2, -1, 1, 2])
    func offsetShiftsTheMappingByWholeDays(offset: Int) throws {
        var date = Date(timeIntervalSinceReferenceDate: 800_000_000)
        for _ in 0..<60 {
            let shifted = try #require(civilCalendar.date(byAdding: .day, value: offset, to: date))
            #expect(
                HijriConverter.components(for: date, offsetDays: offset, timeZone: timeZone)
                    == HijriConverter.components(for: shifted, offsetDays: 0, timeZone: timeZone)
            )
            date = date.addingTimeInterval(86_400)
        }
    }

    @Test
    func offsetsBeyondTheSupportedRangeClamp() {
        let date = Date(timeIntervalSinceReferenceDate: 800_000_000)
        #expect(
            HijriConverter.components(for: date, offsetDays: 5, timeZone: timeZone)
                == HijriConverter.components(for: date, offsetDays: 2, timeZone: timeZone)
        )
        #expect(
            HijriConverter.components(for: date, offsetDays: -9, timeZone: timeZone)
                == HijriConverter.components(for: date, offsetDays: -2, timeZone: timeZone)
        )
    }

    @Test
    func displayStringCarriesMonthDayYear() throws {
        let date = try noon(hijriYear: 1448, month: 2, day: 14)
        #expect(
            HijriConverter.string(for: date, offsetDays: 0, timeZone: timeZone)
                == "Safar 14, 1448 AH"
        )
    }

    // MARK: - Month grid

    @Test(arguments: [-2, 0, 2])
    func monthGridRoundTripsThroughTheSameMapping(offset: Int) throws {
        let date = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let days = HijriConverter.monthDays(containing: date, offsetDays: offset, timeZone: timeZone)
        #expect((29...30).contains(days.count), "Hijri months run 29 or 30 days")

        let today = HijriConverter.components(for: date, offsetDays: offset, timeZone: timeZone)
        let entry = try #require(days.first { $0.components == today })
        #expect(entry.civilDayStart == civilCalendar.startOfDay(for: date))

        // Every grid day converts back to itself under the mapping.
        for day in days {
            let noon = try #require(civilCalendar.date(
                bySettingHour: 12, minute: 0, second: 0, of: day.civilDayStart
            ))
            #expect(
                HijriConverter.components(for: noon, offsetDays: offset, timeZone: timeZone)
                    == day.components
            )
        }
    }

    // MARK: - Significant days

    @Test
    func curatedDaysFireOnTheirDatesOnly() {
        func significance(month: Int, day: Int) -> [HijriSignificance] {
            HijriConverter.significance(of: .init(year: 1448, month: month, day: day))
        }
        #expect(significance(month: 2, day: 14) == [.whiteDay])
        #expect(significance(month: 2, day: 12).isEmpty)
        #expect(significance(month: 9, day: 5) == [.ramadan])
        // Inside Ramadan the month is the fact — white days do not
        // double-mark.
        #expect(significance(month: 9, day: 14) == [.ramadan])
        #expect(significance(month: 12, day: 9).contains(.arafah))
        #expect(!significance(month: 12, day: 9).contains(.firstTenOfDhulHijjah))
        #expect(significance(month: 12, day: 3) == [.firstTenOfDhulHijjah])
        #expect(significance(month: 12, day: 11).isEmpty)
        #expect(significance(month: 1, day: 9) == [.ninthOfMuharram])
        #expect(significance(month: 1, day: 10) == [.ashura])
        #expect(HijriConverter.monthNote(forMonth: 10) != nil)
        #expect(HijriConverter.monthNote(forMonth: 9) == nil)
    }

    @Test
    func inscriptionsStateTheFact() {
        let whiteDay = HijriSignificance.whiteDay.inscription(
            for: .init(year: 1448, month: 2, day: 14)
        )
        #expect(whiteDay == "White day · Safar 14")
        let ramadan = HijriSignificance.ramadan.inscription(
            for: .init(year: 1448, month: 9, day: 3)
        )
        #expect(ramadan == "Ramadan 3")
    }

    // MARK: - Ramadan recognition rides the same mapping

    @Test
    func ramadanContextHonorsTheAdjustment() throws {
        // Noon on the civil day of Shaʿban 29 — the day before
        // Ramadan under the tabulation.
        let eveOfRamadan = try {
            let ramadanFirst = try noon(hijriYear: 1448, month: 9, day: 1)
            return try #require(civilCalendar.date(byAdding: .day, value: -1, to: ramadanFirst))
        }()

        let unadjusted = RamadanContext(at: eveOfRamadan, calendar: hijriCalendar, offsetDays: 0)
        #expect(!unadjusted.isCurrentlyRamadan)

        // A community one day ahead of the tabulation is already in
        // Ramadan on that civil day.
        let adjusted = RamadanContext(at: eveOfRamadan, calendar: hijriCalendar, offsetDays: 1)
        #expect(adjusted.isCurrentlyRamadan)
        #expect(adjusted.daysIntoRamadan == 1)
    }

    @Test
    func hijriDisplayPublishesClampedOffsets() {
        HijriDisplay.publish(offsetDays: 7)
        #expect(HijriDisplay.offsetDays == 2)
        HijriDisplay.publish(offsetDays: -4)
        #expect(HijriDisplay.offsetDays == -2)
        HijriDisplay.publish(offsetDays: 0)
        #expect(HijriDisplay.offsetDays == 0)
    }
}
