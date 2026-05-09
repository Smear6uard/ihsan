import Foundation
import Testing
@testable import IhsanDesignSystem

// MARK: - Helpers

private func makeDate(hour: Int, minute: Int = 0, second: Int = 0) -> Date {
    var components = DateComponents()
    components.year = 2026
    components.month = 5
    components.day = 15
    components.hour = hour
    components.minute = minute
    components.second = second
    return Calendar.current.date(from: components)!
}

private func hue(at date: Date) -> Double {
    let progress = IhsanColor.dayProgress(for: date)
    return IhsanColor.interpolatedHSB(at: progress).hue
}

// MARK: - Tests

@Test
func dayProgressIsZeroAtMidnight() {
    let midnight = makeDate(hour: 0, minute: 0, second: 0)
    let progress = IhsanColor.dayProgress(for: midnight)
    #expect(progress == 0.0)
}

@Test
func dayProgressIsHalfAtNoon() {
    let noon = makeDate(hour: 12, minute: 0, second: 0)
    let progress = IhsanColor.dayProgress(for: noon)
    #expect(abs(progress - 0.5) < 0.0001)
}

@Test
func keyframesAreOrderedByProgress() {
    let progresses = IhsanColor.tintStops.map(\.progress)
    #expect(progresses == progresses.sorted())
}

@Test
func keyframesSpanFullDay() {
    let first = IhsanColor.tintStops.first!
    let last = IhsanColor.tintStops.last!
    #expect(first.progress == 0.0)
    #expect(last.progress == 1.0)
}

@Test
func midnightAndWraparoundAreContinuous() {
    // The 0.0 stop and 1.0 stop must match exactly so a Date at the very
    // end of the day produces the same color as one at the start.
    let first = IhsanColor.tintStops.first!
    let last = IhsanColor.tintStops.last!
    #expect(first.hue == last.hue)
    #expect(first.sat == last.sat)
    #expect(first.brightness == last.brightness)

    let h0 = IhsanColor.interpolatedHSB(at: 0.0)
    let h1 = IhsanColor.interpolatedHSB(at: 1.0)
    #expect(abs(h0.hue - h1.hue) < 0.0001)
    #expect(abs(h0.saturation - h1.saturation) < 0.0001)
    #expect(abs(h0.brightness - h1.brightness) < 0.0001)
}

@Test
func fajrTintIsCoolVioletBlue() {
    // ~5am: hue should be in the violet-blue range, 230°–260°.
    let h = hue(at: makeDate(hour: 5, minute: 0))
    #expect(h >= 230 && h <= 260, "Fajr hue was \(h), expected 230–260")
}

@Test
func dhuhrTintIsWarmCream() {
    // Noon (~0.50): we keyframe to hue 45°, which sits in the warm cream
    // range. Allow a tolerance around the keyframe.
    let h = hue(at: makeDate(hour: 12, minute: 0))
    #expect(h >= 30 && h <= 60, "Dhuhr hue was \(h), expected 30–60")
}

@Test
func asrTintIsWarmHoneyGold() {
    // ~3:30pm: hue should be in the warm honey-gold range, 25°–50°.
    let h = hue(at: makeDate(hour: 15, minute: 30))
    #expect(h >= 25 && h <= 50, "Asr hue was \(h), expected 25–50")
}

@Test
func maghribTintIsRoseGold() {
    // ~7pm: hue should be in the rose-gold / warm orange range, 0°–30°.
    let h = hue(at: makeDate(hour: 19, minute: 12))
    #expect(h >= 0 && h <= 35, "Maghrib hue was \(h), expected 0–35")
}

@Test
func ishaTintIsDeepBlueMagenta() {
    // ~10pm: hue should be in the deep blue-magenta range, 240°–290°.
    let h = hue(at: makeDate(hour: 21, minute: 36))
    #expect(h >= 240 && h <= 290, "Isha hue was \(h), expected 240–290")
}

@Test
func interpolationIsDeterministic() {
    // Calling twice with the same input must return identical components.
    let date = makeDate(hour: 14, minute: 17, second: 22)
    let progress = IhsanColor.dayProgress(for: date)
    let a = IhsanColor.interpolatedHSB(at: progress)
    let b = IhsanColor.interpolatedHSB(at: progress)
    #expect(a.hue == b.hue)
    #expect(a.saturation == b.saturation)
    #expect(a.brightness == b.brightness)
}

@Test
func adjacentTimestampsProduceCloseHues() {
    // 5 minutes apart — no discontinuities should produce a >5° hue jump
    // anywhere on the day except across the antipodal hue wrap (which we
    // exclude by checking the smaller direction around the wheel).
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .current

    var maxJump = 0.0
    var jumpAt: Date = .now

    for hour in 0..<24 {
        for minute in stride(from: 0, to: 60, by: 5) {
            let now = makeDate(hour: hour, minute: minute)
            let later = makeDate(hour: hour, minute: minute + 5)
            let h1 = hue(at: now)
            let h2 = hue(at: later)
            var delta = abs(h2 - h1)
            if delta > 180 { delta = 360 - delta }
            if delta > maxJump {
                maxJump = delta
                jumpAt = now
            }
        }
    }

    // The largest single 5-minute step crosses the rose-gold→deep-magenta
    // segment between Maghrib (15°) and Isha (270°), which is 105° spread
    // over 0.10 of a day = 144 minutes; per 5 minutes that's ~3.6°.
    #expect(maxJump < 6.0, "Largest 5-minute hue jump was \(maxJump)° at \(jumpAt)")
}

@Test
func interpolationClampsToValidRange() {
    // Out-of-range progress should clamp without crashing.
    let neg = IhsanColor.interpolatedHSB(at: -0.5)
    let over = IhsanColor.interpolatedHSB(at: 1.5)
    #expect(neg.hue >= 0 && neg.hue <= 360)
    #expect(over.hue >= 0 && over.hue <= 360)
    #expect(neg.saturation >= 0 && neg.saturation <= 1)
    #expect(over.saturation >= 0 && over.saturation <= 1)
}

@Test
func keyframeHuesMatchSpec() {
    // Quick sanity check that the documented keyframe hues haven't drifted
    // — these are the contract of the visual identity.
    let stops = IhsanColor.tintStops
    #expect(stops[0].hue == 250) // midnight
    #expect(stops[1].hue == 245) // ~Fajr
    #expect(stops[3].hue == 45)  // Dhuhr
    #expect(stops[4].hue == 35)  // Asr
    #expect(stops[5].hue == 15)  // Maghrib
    #expect(stops[6].hue == 270) // Isha
}
