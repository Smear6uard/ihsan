import Foundation
import IhsanCore
import Testing
@testable import IhsanPrayerTimes

/// Clock 1 against real schedules.
///
/// The unit tests in `IhsanCore` pin the arithmetic; these pin the
/// thing the arithmetic is FOR, across latitudes and seasons where
/// Isha runs deep past midnight and where it barely clears it:
///
/// * the cycle date is always the date of the most recent Fajr;
/// * an Isha instant anywhere inside its own window attributes to its
///   own cycle, rebuilt from scratch the way the app rebuilds it;
/// * clock midnight changes nothing.
@Suite("Prayer cycle attribution")
struct PrayerCycleAttributionTests {

    /// SplitMix64 — deterministic cases; a failure reproduces exactly.
    private struct SeededGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
        mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
    }

    private struct Case {
        let coordinates: Coordinates
        let timeZone: TimeZone
        let date: Date
        let method: CalculationMethodChoice
        let madhab: MadhabChoice

        var calendar: Calendar {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            return calendar
        }
    }

    private func randomCases(count: Int) -> [Case] {
        var rng = SeededGenerator(state: 0x0C1E_5AFE_D00D_1948)
        let methods: [CalculationMethodChoice] = [.isna, .muslimWorldLeague, .ummAlQura, .egyptian]
        let madhabs: [MadhabChoice] = [.standard, .hanafi]
        return (0..<count).map { _ in
            let latitude = -58.0 + rng.unit() * 116.0
            let longitude = -180.0 + rng.unit() * 360.0
            let offsetHours = (longitude / 15.0).rounded()
            let timeZone = TimeZone(secondsFromGMT: Int(offsetHours) * 3600)!
            let epoch = Date(timeIntervalSinceReferenceDate: 725_000_000)
            let date = epoch.addingTimeInterval(rng.unit() * 4 * 365.25 * 86_400)
            return Case(
                coordinates: Coordinates(latitude: latitude, longitude: longitude),
                timeZone: timeZone,
                date: date,
                method: methods[Int(rng.next() % UInt64(methods.count))],
                madhab: madhabs[Int(rng.next() % UInt64(madhabs.count))]
            )
        }
    }

    private func window(
        _ testCase: Case, at instant: Date, provider: any PrayerTimesProviding
    ) throws -> PrayerScheduleWindow {
        try provider.scheduleWindow(
            for: instant,
            coordinates: testCase.coordinates,
            timeZone: testCase.timeZone,
            calculationMethod: testCase.method,
            madhab: testCase.madhab,
            highLatitudeRule: .middleOfNight
        )
    }

    // MARK: - The cycle date is the most recent Fajr's date

    @Test("cycleDate is the date of the most recent Fajr window start")
    func cycleDateIsMostRecentFajr() throws {
        let provider = AdhanPrayerTimesProvider()

        for testCase in randomCases(count: 30) {
            let base = try window(testCase, at: testCase.date, provider: provider)
            let calendar = testCase.calendar

            var probes: [Date] = []
            var cursor = base.yesterdayIsha.scheduledTime
            while cursor < base.tomorrowFajr.scheduledTime {
                probes.append(cursor)
                cursor = cursor.addingTimeInterval(37 * 60)
            }
            for boundary in [base.day.fajr.scheduledTime, base.tomorrowFajr.scheduledTime] {
                probes.append(boundary.addingTimeInterval(-1))
                probes.append(boundary)
            }

            for probe in probes where probe < base.tomorrowFajr.scheduledTime {
                let live = try window(testCase, at: probe, provider: provider)
                let cycle = live.cycle(at: probe)

                let mostRecentFajr = probe < live.day.fajr.scheduledTime
                    ? live.yesterday.fajr.scheduledTime
                    : live.day.fajr.scheduledTime
                #expect(
                    cycle.date == calendar.startOfDay(for: mostRecentFajr),
                    "cycle date left the most recent Fajr at \(probe) (\(testCase.coordinates))"
                )
                #expect(probe < cycle.rollsAt, "cycle already rolled at \(probe)")
            }
        }
    }

    // MARK: - Isha keeps its cycle for its whole window

    @Test("An Isha instant anywhere in its window attributes to its own cycle")
    func ishaKeepsItsCycle() throws {
        let provider = AdhanPrayerTimesProvider()

        for testCase in randomCases(count: 30) {
            let base = try window(testCase, at: testCase.date, provider: provider)
            let ishaStart = base.day.isha.scheduledTime
            let ishaEnd = base.tomorrowFajr.scheduledTime
            guard ishaStart < ishaEnd else { continue }
            let expected = base.cycle(at: ishaStart).date

            var cursor = ishaStart
            while cursor < ishaEnd {
                let live = try window(testCase, at: cursor, provider: provider)
                #expect(
                    live.cycle(at: cursor).date == expected,
                    "Isha at \(cursor) left its cycle (\(testCase.coordinates))"
                )
                // And the window it is measured against is its own.
                let bounds = live.window(of: .isha, inCycleAt: cursor)
                #expect(bounds.start <= cursor && cursor < bounds.end)
                #expect(bounds.start == ishaStart)
                cursor = cursor.addingTimeInterval(29 * 60)
            }
        }
    }

    // MARK: - Midnight is not a boundary

    @Test("11:59:59 PM and 12:00:01 AM resolve to the same cycle")
    func midnightChangesNothing() throws {
        let provider = AdhanPrayerTimesProvider()

        for testCase in randomCases(count: 30) {
            let calendar = testCase.calendar
            let base = try window(testCase, at: testCase.date, provider: provider)
            let midnight = calendar.startOfDay(for: base.day.date)
            guard let nextMidnight = calendar.date(byAdding: .day, value: 1, to: midnight)
            else { continue }

            let before = nextMidnight.addingTimeInterval(-1)
            let after = nextMidnight.addingTimeInterval(1)

            let beforeCycle = try window(testCase, at: before, provider: provider).cycle(at: before)
            let afterCycle = try window(testCase, at: after, provider: provider).cycle(at: after)

            #expect(
                beforeCycle.date == afterCycle.date,
                "midnight moved the cycle at \(testCase.coordinates)"
            )
            #expect(beforeCycle.rollsAt == afterCycle.rollsAt)
        }
    }

    // MARK: - Clock 2 boundaries travel with the window

    @Test("The window vouches for its own evening boundaries")
    func eveningBoundariesCoverBothDays() throws {
        let provider = AdhanPrayerTimesProvider()

        for testCase in randomCases(count: 10) {
            let base = try window(testCase, at: testCase.date, provider: provider)
            let boundaries = base.eveningBoundaries
            #expect(boundaries.count == 2)
            #expect(boundaries.last?.maghrib == base.day.maghrib.scheduledTime)
            #expect(boundaries.first?.maghrib == base.yesterday.maghrib.scheduledTime)
        }
    }
}
