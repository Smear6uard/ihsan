import Foundation
import Testing
@testable import ihsan

private func date(_ components: DateComponents) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar.date(from: components)!
}

private func utc(year: Int, month: Int, day: Int, hour: Int = 12) -> Date {
    var comps = DateComponents()
    comps.year = year
    comps.month = month
    comps.day = day
    comps.hour = hour
    return date(comps)
}

@Suite("MoonPhase")
struct MoonPhaseTests {
    /// Reference: 2024-01-11 11:57 UTC was a documented new moon.
    /// Our 8-bucket mapping should classify the nearest noon as new.
    @Test
    func recognizesKnownNewMoon() {
        let d = utc(year: 2024, month: 1, day: 11)
        let fraction = MoonPhase.phaseFraction(at: d)
        // New moon = fraction near 0 (or near 1 by wraparound).
        #expect(fraction < 0.06 || fraction > 0.94,
                "Phase fraction \(fraction) should be near 0 for a new moon")
    }

    /// 2024-01-25 17:54 UTC was a documented full moon.
    @Test
    func recognizesKnownFullMoon() {
        let d = utc(year: 2024, month: 1, day: 25, hour: 18)
        let fraction = MoonPhase.phaseFraction(at: d)
        #expect(abs(fraction - 0.5) < 0.06,
                "Phase fraction \(fraction) should be near 0.5 for a full moon")
    }

    @Test
    func phaseFractionStaysInZeroOneRange() {
        for daysOffset in stride(from: -400, through: 400, by: 13) {
            let d = Date(timeIntervalSinceNow: TimeInterval(daysOffset) * 86_400)
            let fraction = MoonPhase.phaseFraction(at: d)
            #expect(fraction >= 0.0 && fraction < 1.0,
                    "Phase fraction \(fraction) out of range at offset \(daysOffset)")
        }
    }

    @Test
    func bucketCyclesThroughEightPhases() {
        // Sample once per ~half-week across one full synodic month
        // starting from a documented new moon; we should see every
        // bucket at least once.
        var seen = Set<String>()
        let base = utc(year: 2024, month: 1, day: 11)
        for daysAfter in stride(from: 0.0, through: 30.0, by: 0.5) {
            let d = base.addingTimeInterval(daysAfter * 86_400)
            seen.insert(MoonPhase.bucket(at: d).symbolName)
        }
        #expect(seen.count == 8,
                "Expected all 8 phase buckets across a full lunation, saw \(seen.count)")
    }
}
