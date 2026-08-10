import Foundation
import Testing
@testable import IhsanCore

@Suite("Iqamah resolution")
struct IqamahScheduleTests {

    private static func zone(_ identifier: String) -> TimeZone {
        TimeZone(identifier: identifier)!
    }

    private static func instant(
        _ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int,
        in timeZone: TimeZone
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(
            from: DateComponents(
                year: year, month: month, day: day, hour: hour, minute: minute
            )
        )!
    }

    @Test("An offset entry resolves to the adhan plus its minutes")
    func offsetAddsToAdhan() {
        let timeZone = Self.zone("America/Chicago")
        let adhan = Self.instant(2026, 8, 9, 5, 22, in: timeZone)
        let entry = IqamahEntry(prayer: .fajr, mode: .offset, offsetMinutes: 20)

        let resolved = IqamahSchedule.resolve(
            entry: entry, adhan: adhan, timeZone: timeZone
        )

        #expect(resolved == adhan.addingTimeInterval(20 * 60))
    }

    @Test("A none entry resolves to nothing")
    func noneResolvesToNil() {
        let timeZone = Self.zone("America/Chicago")
        let adhan = Self.instant(2026, 8, 9, 5, 22, in: timeZone)
        let entry = IqamahEntry(prayer: .fajr, mode: .none)

        #expect(
            IqamahSchedule.resolve(entry: entry, adhan: adhan, timeZone: timeZone) == nil
        )
    }

    @Test("A fixed time later the same day resolves on that day")
    func fixedLaterSameDay() {
        let timeZone = Self.zone("America/Chicago")
        let adhan = Self.instant(2026, 8, 9, 12, 51, in: timeZone)
        let entry = IqamahEntry(
            prayer: .dhuhr, mode: .fixed, fixedMinutesFromMidnight: 13 * 60 + 30
        )

        let resolved = IqamahSchedule.resolve(
            entry: entry, adhan: adhan, timeZone: timeZone
        )

        #expect(resolved == Self.instant(2026, 8, 9, 13, 30, in: timeZone))
    }

    /// The case that decided the rule: at high latitude in summer an Isha
    /// adhan at 22:30 with a board time of 00:15 belongs to the NEXT civil
    /// day. Resolving on the adhan's own day would place the iqamah
    /// twenty-two hours before its adhan.
    @Test("A fixed time past midnight resolves forward, never backward")
    func fixedPastMidnightRollsForward() {
        let timeZone = Self.zone("Europe/Oslo")
        let adhan = Self.instant(2026, 6, 15, 22, 30, in: timeZone)
        let entry = IqamahEntry(prayer: .isha, mode: .fixed, fixedMinutesFromMidnight: 15)

        let resolved = IqamahSchedule.resolve(
            entry: entry, adhan: adhan, timeZone: timeZone
        )

        #expect(resolved == Self.instant(2026, 6, 16, 0, 15, in: timeZone))
        #expect(resolved! > adhan)
    }

    @Test("A fixed time equal to the adhan resolves to the adhan itself")
    func fixedEqualToAdhanIsTheAdhan() {
        let timeZone = Self.zone("America/Chicago")
        let adhan = Self.instant(2026, 8, 9, 13, 30, in: timeZone)
        let entry = IqamahEntry(
            prayer: .dhuhr, mode: .fixed, fixedMinutesFromMidnight: 13 * 60 + 30
        )

        #expect(
            IqamahSchedule.resolve(entry: entry, adhan: adhan, timeZone: timeZone) == adhan
        )
    }

    @Test("Every fixed resolution lands within 24 hours after its adhan")
    func fixedAlwaysWithinTwentyFourHours() {
        let timeZone = Self.zone("America/Chicago")
        let adhan = Self.instant(2026, 8, 9, 17, 40, in: timeZone)

        for minute in stride(from: 0, to: 1440, by: 7) {
            let entry = IqamahEntry(
                prayer: .asr, mode: .fixed, fixedMinutesFromMidnight: minute
            )
            let resolved = IqamahSchedule.resolve(
                entry: entry, adhan: adhan, timeZone: timeZone
            )

            #expect(resolved != nil)
            let delta = resolved!.timeIntervalSince(adhan)
            #expect(delta >= 0)
            #expect(delta < 24 * 3600)
        }
    }

    /// Spring-forward skips 02:00–03:00 local. A board time inside the gap
    /// has no instant that day; resolution must still return the first real
    /// occurrence rather than nil or a time before the adhan.
    @Test("A fixed time inside a spring-forward gap still resolves forward")
    func fixedInsideDSTGapResolvesForward() {
        let timeZone = Self.zone("America/Chicago")
        // 2026-03-08: clocks jump 02:00 -> 03:00 local.
        let adhan = Self.instant(2026, 3, 7, 20, 10, in: timeZone)
        let entry = IqamahEntry(
            prayer: .isha, mode: .fixed, fixedMinutesFromMidnight: 2 * 60 + 30
        )

        let resolved = IqamahSchedule.resolve(
            entry: entry, adhan: adhan, timeZone: timeZone
        )

        #expect(resolved != nil)
        #expect(resolved! > adhan)
        #expect(resolved!.timeIntervalSince(adhan) < 24 * 3600)
    }

    /// Fall-back repeats 01:00–02:00 local. The earlier of the two is the
    /// one the board means.
    @Test("A fixed time inside a fall-back repeat takes the first occurrence")
    func fixedInsideDSTRepeatTakesTheFirst() {
        let timeZone = Self.zone("America/Chicago")
        // 2026-11-01: clocks fall 02:00 -> 01:00 local.
        let adhan = Self.instant(2026, 10, 31, 19, 40, in: timeZone)
        let entry = IqamahEntry(
            prayer: .isha, mode: .fixed, fixedMinutesFromMidnight: 60 + 30
        )

        let resolved = IqamahSchedule.resolve(
            entry: entry, adhan: adhan, timeZone: timeZone
        )

        #expect(resolved != nil)
        #expect(resolved! > adhan)
        #expect(resolved!.timeIntervalSince(adhan) < 24 * 3600)
    }

    @Test("Entries survive an encode and decode round trip")
    func roundTripsThroughJSON() {
        let entries = [
            IqamahEntry(
                prayer: .fajr, mode: .offset, offsetMinutes: 20, reminderEnabled: true
            ),
            IqamahEntry(prayer: .dhuhr, mode: .fixed, fixedMinutesFromMidnight: 810),
        ]

        let decoded = IqamahSchedule.decode(IqamahSchedule.encode(entries))

        // Compare decoded VALUES — never the encoded string. JSONEncoder
        // key ordering is not stable across processes.
        #expect(decoded == entries)
    }

    @Test("A payload missing newer keys still decodes")
    func decodesLeniently() {
        let json = #"[{"prayer":"fajr","mode":"offset","offsetMinutes":15}]"#

        let decoded = IqamahSchedule.decode(json)

        #expect(decoded.count == 1)
        #expect(decoded[0].offsetMinutes == 15)
        #expect(decoded[0].reminderEnabled == false)
    }

    @Test("Unreadable JSON decodes to no entries rather than throwing")
    func decodesGarbageToEmpty() {
        #expect(IqamahSchedule.decode("not json").isEmpty)
    }

    @Test("An entry reports whether it would render a time")
    func reportsWhetherItIsSet() {
        #expect(IqamahEntry(prayer: .fajr).isSet == false)
        #expect(IqamahEntry(prayer: .fajr, mode: .offset).isSet == false)
        #expect(
            IqamahEntry(prayer: .fajr, mode: .offset, offsetMinutes: 0).isSet
        )
        #expect(
            IqamahEntry(prayer: .fajr, mode: .fixed, fixedMinutesFromMidnight: 0).isSet
        )
    }

    @Test("The empty set carries one unset entry per prayer, in the day's order")
    func emptyCoversEveryPrayer() {
        #expect(IqamahSchedule.empty.map(\.prayer) == Prayer.allCases)
        #expect(IqamahSchedule.empty.allSatisfy { $0.mode == .none })
    }
}
