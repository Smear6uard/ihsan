import Foundation
import Testing
@testable import IhsanCore

/// Clock 1's contract. The property under test throughout is the one
/// the corrective exists for: **nothing happens at midnight**. A log at
/// 11:59 PM and a log at 12:01 AM belong to the same cycle; the only
/// instant that changes the answer is Fajr.
@Suite("Prayer cycle — clock 1")
struct PrayerCycleTests {

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Toronto")!
        return calendar
    }

    /// August 4 2026 in Toronto, with plausible Fajr instants.
    private static func at(day: Int, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(
            from: DateComponents(year: 2026, month: 8, day: day, hour: hour, minute: minute)
        )!
    }

    private static let aug4Fajr = at(day: 4, 4, 42)
    private static let aug5Fajr = at(day: 5, 4, 43)
    private static let aug4Start = at(day: 4, 0, 0)
    private static let aug5Start = at(day: 5, 0, 0)

    // MARK: - The rule

    @Test("At or after the civil day's Fajr, the cycle is that day's")
    func cycleAfterFajr() {
        let cycle = PrayerCycleClock.cycle(
            at: Self.at(day: 4, 13, 30),
            civilDayFajr: Self.aug4Fajr,
            nextDayFajr: Self.aug5Fajr,
            calendar: Self.calendar
        )
        #expect(cycle.date == Self.aug4Start)
        #expect(cycle.rollsAt == Self.aug5Fajr)
    }

    @Test("Fajr itself opens the new cycle — the boundary is half-open")
    func cycleAtFajrExactly() {
        let cycle = PrayerCycleClock.cycle(
            at: Self.aug5Fajr,
            civilDayFajr: Self.aug5Fajr,
            nextDayFajr: Self.at(day: 6, 4, 44),
            calendar: Self.calendar
        )
        #expect(cycle.date == Self.aug5Start)
    }

    @Test("One second before Fajr the cycle is still the previous day's")
    func cycleJustBeforeFajr() {
        let cycle = PrayerCycleClock.cycle(
            at: Self.aug5Fajr.addingTimeInterval(-1),
            civilDayFajr: Self.aug5Fajr,
            nextDayFajr: Self.at(day: 6, 4, 44),
            calendar: Self.calendar
        )
        #expect(cycle.date == Self.aug4Start)
        #expect(cycle.rollsAt == Self.aug5Fajr)
    }

    // MARK: - Midnight is not a boundary

    @Test("11:59 PM and 12:01 AM land in the same cycle")
    func midnightChangesNothing() {
        let beforeMidnight = PrayerCycleClock.cycleDate(
            at: Self.at(day: 4, 23, 59),
            civilDayFajr: Self.aug4Fajr,
            calendar: Self.calendar
        )
        let afterMidnight = PrayerCycleClock.cycleDate(
            at: Self.at(day: 5, 0, 1),
            civilDayFajr: Self.aug5Fajr,
            calendar: Self.calendar
        )
        #expect(beforeMidnight == afterMidnight)
        #expect(beforeMidnight == Self.aug4Start)
    }

    @Test("An Isha at any instant inside its own window keeps its cycle")
    func ishaAcrossItsWholeWindow() {
        // Isha Aug 4 at 21:14, running to Fajr Aug 5 at 04:43.
        let isha = Self.at(day: 4, 21, 14)
        var instant = isha
        while instant < Self.aug5Fajr {
            let civilDayFajr = instant < Self.aug5Start ? Self.aug4Fajr : Self.aug5Fajr
            let date = PrayerCycleClock.cycleDate(
                at: instant, civilDayFajr: civilDayFajr, calendar: Self.calendar
            )
            #expect(
                date == Self.aug4Start,
                "Isha at \(instant) left its own cycle"
            )
            instant = instant.addingTimeInterval(17 * 60)
        }
    }

    @Test("The cycle key never depends on the instant's own civil day")
    func keyDerivesFromFajrNotInstant() {
        // Two instants on opposite sides of midnight, both handed the
        // Fajr of their own civil day, produce one key.
        for offsetMinutes in stride(from: -180, through: 180, by: 15) {
            let instant = Self.aug5Start.addingTimeInterval(TimeInterval(offsetMinutes * 60))
            let civilDayFajr = instant < Self.aug5Start ? Self.aug4Fajr : Self.aug5Fajr
            let date = PrayerCycleClock.cycleDate(
                at: instant, civilDayFajr: civilDayFajr, calendar: Self.calendar
            )
            #expect(date == Self.aug4Start, "offset \(offsetMinutes) escaped the cycle")
        }
    }

    // MARK: - Neighbours

    @Test("The previous cycle is one calendar day back")
    func previousCycle() {
        let cycle = PrayerCycle(date: Self.aug5Start, rollsAt: Self.at(day: 6, 4, 44))
        #expect(cycle.previousDate(calendar: Self.calendar) == Self.aug4Start)
    }

    @Test("A daylight-saving spring forward does not shift the key")
    func acrossDaylightSaving() {
        // Toronto springs forward at 2 AM on March 8 2026.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Toronto")!
        func march(_ day: Int, _ hour: Int, _ minute: Int) -> Date {
            calendar.date(
                from: DateComponents(year: 2026, month: 3, day: day, hour: hour, minute: minute)
            )!
        }
        let cycle = PrayerCycleClock.cycle(
            at: march(8, 4, 0),
            civilDayFajr: march(8, 6, 21),
            nextDayFajr: march(9, 6, 19),
            calendar: calendar
        )
        #expect(cycle.date == march(7, 0, 0))
        #expect(cycle.rollsAt == march(8, 6, 21))
    }
}
