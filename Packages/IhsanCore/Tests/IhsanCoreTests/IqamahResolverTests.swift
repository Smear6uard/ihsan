import Foundation
import Testing
@testable import IhsanCore

@Suite("Which iqamah a prayer shows")
struct IqamahResolverTests {

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

    private static func masjid(
        entries: [IqamahEntry] = [],
        khutbah: Int? = nil
    ) -> MyMasjidSnapshot {
        MyMasjidSnapshot(
            name: "Masjid al-Noor",
            streetLabel: nil,
            entries: Prayer.allCases.map { prayer in
                entries.first { $0.prayer == prayer } ?? IqamahEntry(prayer: prayer)
            },
            jumuahKhutbahMinutesFromMidnight: khutbah,
            reminderLeadMinutes: 10
        )
    }

    // 2026-08-12 is a Wednesday; 2026-08-14 is a Friday.
    private static let wednesdayDhuhr = instant(2026, 8, 12, 12, 51, in: zone("America/Chicago"))
    private static let fridayDhuhr = instant(2026, 8, 14, 12, 51, in: zone("America/Chicago"))

    @Test("No masjid means no inscription")
    func noMasjidNoInscription() {
        let resolved = IqamahResolver.resolved(
            masjid: nil,
            prayer: .dhuhr,
            adhan: Self.wednesdayDhuhr,
            timeZone: Self.zone("America/Chicago")
        )
        #expect(resolved == nil)
    }

    @Test("A prayer with no entry shows nothing")
    func unsetPrayerShowsNothing() {
        let resolved = IqamahResolver.resolved(
            masjid: Self.masjid(),
            prayer: .asr,
            adhan: Self.wednesdayDhuhr,
            timeZone: Self.zone("America/Chicago")
        )
        #expect(resolved == nil)
    }

    @Test("A fixed entry resolves to its own time")
    func fixedResolves() {
        let timeZone = Self.zone("America/Chicago")
        let resolved = IqamahResolver.resolved(
            masjid: Self.masjid(entries: [
                IqamahEntry(prayer: .dhuhr, mode: .fixed, fixedMinutesFromMidnight: 13 * 60 + 30)
            ]),
            prayer: .dhuhr,
            adhan: Self.wednesdayDhuhr,
            timeZone: timeZone
        )

        #expect(resolved?.kind == .iqamah)
        #expect(resolved?.time == Self.instant(2026, 8, 12, 13, 30, in: timeZone))
    }

    /// The card shows the answer, never the formula.
    @Test("An offset entry resolves to a time, not a rule")
    func offsetResolvesToATime() {
        let timeZone = Self.zone("America/Chicago")
        let resolved = IqamahResolver.resolved(
            masjid: Self.masjid(entries: [
                IqamahEntry(prayer: .dhuhr, mode: .offset, offsetMinutes: 20)
            ]),
            prayer: .dhuhr,
            adhan: Self.wednesdayDhuhr,
            timeZone: timeZone
        )

        #expect(resolved?.kind == .iqamah)
        #expect(resolved?.time == Self.wednesdayDhuhr.addingTimeInterval(20 * 60))
    }

    @Test("On Friday the khutbah replaces the Dhuhr iqamah")
    func fridayKhutbahReplacesDhuhr() {
        let timeZone = Self.zone("America/Chicago")
        let resolved = IqamahResolver.resolved(
            masjid: Self.masjid(
                entries: [
                    IqamahEntry(prayer: .dhuhr, mode: .fixed, fixedMinutesFromMidnight: 13 * 60 + 30)
                ],
                khutbah: 13 * 60 + 15
            ),
            prayer: .dhuhr,
            adhan: Self.fridayDhuhr,
            timeZone: timeZone
        )

        #expect(resolved?.kind == .khutbah)
        #expect(resolved?.time == Self.instant(2026, 8, 14, 13, 15, in: timeZone))
    }

    @Test("Without a khutbah time, Friday's Dhuhr keeps its ordinary iqamah")
    func fridayWithoutKhutbahKeepsIqamah() {
        let timeZone = Self.zone("America/Chicago")
        let resolved = IqamahResolver.resolved(
            masjid: Self.masjid(entries: [
                IqamahEntry(prayer: .dhuhr, mode: .fixed, fixedMinutesFromMidnight: 13 * 60 + 30)
            ]),
            prayer: .dhuhr,
            adhan: Self.fridayDhuhr,
            timeZone: timeZone
        )

        #expect(resolved?.kind == .iqamah)
        #expect(resolved?.time == Self.instant(2026, 8, 14, 13, 30, in: timeZone))
    }

    @Test("A khutbah time alone shows on Friday even with no Dhuhr iqamah")
    func khutbahAloneShowsOnFriday() {
        let resolved = IqamahResolver.resolved(
            masjid: Self.masjid(khutbah: 13 * 60 + 15),
            prayer: .dhuhr,
            adhan: Self.fridayDhuhr,
            timeZone: Self.zone("America/Chicago")
        )

        #expect(resolved?.kind == .khutbah)
    }

    @Test("A khutbah time does not leak onto other days")
    func khutbahDoesNotShowOnWednesday() {
        let resolved = IqamahResolver.resolved(
            masjid: Self.masjid(khutbah: 13 * 60 + 15),
            prayer: .dhuhr,
            adhan: Self.wednesdayDhuhr,
            timeZone: Self.zone("America/Chicago")
        )

        #expect(resolved == nil)
    }

    @Test("A khutbah time does not leak onto other prayers")
    func khutbahDoesNotShowOnAsr() {
        let timeZone = Self.zone("America/Chicago")
        let fridayAsr = Self.instant(2026, 8, 14, 16, 40, in: timeZone)
        let resolved = IqamahResolver.resolved(
            masjid: Self.masjid(
                entries: [IqamahEntry(prayer: .asr, mode: .offset, offsetMinutes: 15)],
                khutbah: 13 * 60 + 15
            ),
            prayer: .asr,
            adhan: fridayAsr,
            timeZone: timeZone
        )

        #expect(resolved?.kind == .iqamah)
        #expect(resolved?.time == fridayAsr.addingTimeInterval(15 * 60))
    }

    /// Friday belongs to the place, not to the phone. Someone in Tokyo on
    /// Friday afternoon must see the khutbah even while the device's own
    /// zone is still on Thursday.
    @Test("Friday is decided in the place's timezone, not the device's")
    func fridayIsDecidedInThePlacesTimezone() {
        let tokyo = Self.zone("Asia/Tokyo")
        // 2026-08-14 13:00 in Tokyo is 2026-08-13 23:00 in Chicago.
        let tokyoFridayDhuhr = Self.instant(2026, 8, 14, 11, 40, in: tokyo)

        let resolved = IqamahResolver.resolved(
            masjid: Self.masjid(khutbah: 12 * 60 + 30),
            prayer: .dhuhr,
            adhan: tokyoFridayDhuhr,
            timeZone: tokyo
        )

        #expect(resolved?.kind == .khutbah)
        #expect(resolved?.time == Self.instant(2026, 8, 14, 12, 30, in: tokyo))

        // The same instant read through Chicago is a Thursday, and shows
        // no khutbah at all.
        let readFromChicago = IqamahResolver.resolved(
            masjid: Self.masjid(khutbah: 12 * 60 + 30),
            prayer: .dhuhr,
            adhan: tokyoFridayDhuhr,
            timeZone: Self.zone("America/Chicago")
        )
        #expect(readFromChicago == nil)
    }
}
