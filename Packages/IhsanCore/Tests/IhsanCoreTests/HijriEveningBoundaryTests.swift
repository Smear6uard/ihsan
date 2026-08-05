import Foundation
import Testing
@testable import IhsanCore

/// Clock 2's contract: the Hijri day turns at Maghrib, the
/// moonsighting adjustment still applies on top of it, and a day with
/// no published boundary tabulates civilly.
///
/// Serialized because the published boundary table is process-wide.
@Suite("Hijri evening boundary — clock 2", .serialized)
struct HijriEveningBoundaryTests {

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Toronto")!
        return calendar
    }

    private static func at(day: Int, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(
            from: DateComponents(year: 2026, month: 8, day: day, hour: hour, minute: minute)
        )!
    }

    private static let timeZone = TimeZone(identifier: "America/Toronto")!
    private static let maghrib = at(day: 4, 20, 25)

    private func withBoundary<T>(_ body: () throws -> T) rethrows -> T {
        HijriDisplay.publish(
            eveningBoundaries: [
                .init(civilDayStart: Self.at(day: 4, 0, 0), maghrib: Self.maghrib)
            ],
            timeZone: Self.timeZone
        )
        defer { HijriDisplay.clearEveningBoundaries() }
        return try body()
    }

    // MARK: - The flip

    @Test("One minute before Maghrib the date is still the daytime's")
    func beforeMaghrib() {
        let before = HijriConverter.components(
            for: Self.maghrib.addingTimeInterval(-60),
            offsetDays: 0,
            maghribOfCivilDay: Self.maghrib,
            timeZone: Self.timeZone
        )
        let noon = HijriConverter.components(
            for: Self.at(day: 4, 12, 0),
            offsetDays: 0,
            maghribOfCivilDay: Self.maghrib,
            timeZone: Self.timeZone
        )
        #expect(before == noon)
    }

    @Test("Maghrib itself begins the next Hijri day")
    func atMaghrib() {
        let noon = HijriConverter.components(
            for: Self.at(day: 4, 12, 0),
            offsetDays: 0,
            maghribOfCivilDay: Self.maghrib,
            timeZone: Self.timeZone
        )
        let atSunset = HijriConverter.components(
            for: Self.maghrib,
            offsetDays: 0,
            maghribOfCivilDay: Self.maghrib,
            timeZone: Self.timeZone
        )
        #expect(atSunset.day == noon.day + 1 || atSunset.day == 1)
    }

    @Test("One minute after Maghrib equals the following daytime")
    func afterMaghribEqualsTomorrow() {
        let evening = HijriConverter.components(
            for: Self.maghrib.addingTimeInterval(60),
            offsetDays: 0,
            maghribOfCivilDay: Self.maghrib,
            timeZone: Self.timeZone
        )
        let tomorrowNoon = HijriConverter.components(
            for: Self.at(day: 5, 12, 0),
            offsetDays: 0,
            maghribOfCivilDay: Self.at(day: 5, 20, 24),
            timeZone: Self.timeZone
        )
        #expect(evening == tomorrowNoon)
    }

    @Test("Midnight is not a Hijri boundary either")
    func midnightChangesNothing() {
        let lateEvening = HijriConverter.components(
            for: Self.at(day: 4, 23, 59),
            offsetDays: 0,
            maghribOfCivilDay: Self.maghrib,
            timeZone: Self.timeZone
        )
        let afterMidnight = HijriConverter.components(
            for: Self.at(day: 5, 0, 1),
            offsetDays: 0,
            maghribOfCivilDay: Self.at(day: 5, 20, 24),
            timeZone: Self.timeZone
        )
        #expect(lateEvening == afterMidnight)
    }

    // MARK: - The adjustment still applies

    @Test("The moonsighting offset shifts the evening date too", arguments: [-2, -1, 1, 2])
    func offsetAppliesAfterFlip(offset: Int) {
        let base = HijriConverter.components(
            for: Self.maghrib.addingTimeInterval(60),
            offsetDays: 0,
            maghribOfCivilDay: Self.maghrib,
            timeZone: Self.timeZone
        )
        let adjusted = HijriConverter.components(
            for: Self.maghrib.addingTimeInterval(60),
            offsetDays: offset,
            maghribOfCivilDay: Self.maghrib,
            timeZone: Self.timeZone
        )
        // Same month in these test dates, so the day count moves by
        // exactly the adjustment.
        #expect(adjusted.day == base.day + offset)
    }

    // MARK: - Publication

    @Test("The published boundary drives the no-argument form")
    func publishedBoundaryIsConsulted() {
        withBoundary {
            let evening = HijriConverter.components(
                for: Self.maghrib.addingTimeInterval(60),
                offsetDays: 0,
                timeZone: Self.timeZone
            )
            let noon = HijriConverter.components(
                for: Self.at(day: 4, 12, 0),
                offsetDays: 0,
                timeZone: Self.timeZone
            )
            #expect(evening.day == noon.day + 1)
        }
    }

    @Test("An unpublished day tabulates civilly rather than guessing")
    func unknownBoundaryFallsBack() {
        HijriDisplay.clearEveningBoundaries()
        #expect(HijriDisplay.maghrib(forCivilDayOf: Self.at(day: 4, 12, 0)) == nil)
        let evening = HijriConverter.components(
            for: Self.at(day: 4, 22, 0), offsetDays: 0, timeZone: Self.timeZone
        )
        let noon = HijriConverter.components(
            for: Self.at(day: 4, 12, 0), offsetDays: 0, timeZone: Self.timeZone
        )
        #expect(evening == noon)
    }

    @Test("A boundary is matched by civil day, not by proximity")
    func boundaryMatchesItsOwnDay() {
        withBoundary {
            #expect(HijriDisplay.maghrib(forCivilDayOf: Self.at(day: 4, 3, 0)) == Self.maghrib)
            #expect(HijriDisplay.maghrib(forCivilDayOf: Self.at(day: 5, 3, 0)) == nil)
        }
    }
}
