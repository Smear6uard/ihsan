import Foundation
import IhsanCore
import Testing
@testable import IhsanPrayerTimes

/// Corrective G, phase 1: the never-early property.
///
/// For any instant t earlier than a prayer's start, that prayer is
/// never `current` — equivalently, whenever the resolver reports a
/// current prayer, the instant lies inside `[start, end)` of that
/// prayer's window, and `next` is strictly future. Checked across 50
/// deterministic pseudo-random locations and dates, sweeping each
/// schedule window's full valid span — including the post-Maghrib
/// pre-Isha stretch and the post-Isha rollover into tomorrow's Fajr.
@Suite("Prayer resolution never enters a prayer early")
struct PrayerMomentNeverEarlyTests {

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
    }

    private func randomCases(count: Int) -> [Case] {
        var rng = SeededGenerator(state: 0x1A5F_0426_C0FF_EE00)
        let methods: [CalculationMethodChoice] = [.isna, .muslimWorldLeague, .ummAlQura, .egyptian]
        let madhabs: [MadhabChoice] = [.standard, .hanafi]
        return (0..<count).map { _ in
            // Latitudes to ±58° — high enough to exercise compressed
            // summer nights, low enough that every method still
            // resolves with the middle-of-night rule.
            let latitude = -58.0 + rng.unit() * 116.0
            let longitude = -180.0 + rng.unit() * 360.0
            // A civil timezone near the location's solar meridian.
            let offsetHours = (longitude / 15.0).rounded()
            let timeZone = TimeZone(secondsFromGMT: Int(offsetHours) * 3600)!
            // Dates across 2024–2027, all seasons.
            let epoch = Date(timeIntervalSinceReferenceDate: 725_000_000) // 2023-12-22
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

    @Test
    func currentIsNeverEarlyAcrossFiftyRandomLocationsAndDates() throws {
        let provider = AdhanPrayerTimesProvider()

        for testCase in randomCases(count: 50) {
            let window: PrayerScheduleWindow
            do {
                window = try provider.scheduleWindow(
                    for: testCase.date,
                    coordinates: testCase.coordinates,
                    timeZone: testCase.timeZone,
                    calculationMethod: testCase.method,
                    madhab: testCase.madhab,
                    highLatitudeRule: .middleOfNight
                )
            } catch {
                Issue.record("scheduleWindow failed for \(testCase.coordinates): \(error)")
                continue
            }

            // Probe instants: a sweep of the window's whole valid span
            // plus one-second brackets around every boundary — the
            // post-Maghrib pre-Isha stretch and the post-Isha rollover
            // are inside the sweep by construction.
            var probes: [Date] = []
            let spanStart = window.yesterdayIsha.scheduledTime.addingTimeInterval(-1800)
            let spanEnd = window.tomorrowFajr.scheduledTime
            var cursor = spanStart
            while cursor < spanEnd {
                probes.append(cursor)
                cursor = cursor.addingTimeInterval(600)
            }
            let boundaries = [
                window.yesterdayIsha.scheduledTime,
                window.day.fajr.scheduledTime,
                window.day.sunrise,
                window.day.dhuhr.scheduledTime,
                window.day.asr.scheduledTime,
                window.day.maghrib.scheduledTime,
                window.day.isha.scheduledTime,
                window.tomorrowFajr.scheduledTime
            ]
            for boundary in boundaries {
                probes.append(boundary.addingTimeInterval(-1))
                probes.append(boundary)
            }

            for probe in probes where probe < spanEnd {
                let resolution = PrayerStateResolver.resolve(
                    prayerTimes: window.resolverSchedule,
                    now: probe
                )

                if let current = resolution.currentPrayer {
                    // Never early: a current prayer's start is never
                    // in the future.
                    #expect(
                        current.scheduledTime <= probe,
                        "\(current.prayer) reported current \(current.scheduledTime.timeIntervalSince(probe))s before its start at \(probe) (\(testCase.coordinates))"
                    )
                    // And its window still contains the instant.
                    if let end = resolution.currentWindowEnd {
                        #expect(probe < end)
                    } else {
                        Issue.record("current without a window end at \(probe)")
                    }
                }

                // The next prayer is strictly future.
                #expect(resolution.nextPrayer.scheduledTime > probe)
            }
        }
    }
}
