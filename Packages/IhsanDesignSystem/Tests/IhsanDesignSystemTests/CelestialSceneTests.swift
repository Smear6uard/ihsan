import Foundation
import Testing
@testable import IhsanDesignSystem

// MARK: - dayFraction crossover points

@Test
func dayFractionAtMidnightIsZero() {
    let date = dateAt(hour: 0, minute: 0)
    let fraction = SkyState.dayFraction(at: date)
    #expect(fraction == 0.0, "dayFraction at midnight was \(fraction), expected 0.0")
}

@Test
func dayFractionAtNoonIsOne() {
    let date = dateAt(hour: 12, minute: 0)
    let fraction = SkyState.dayFraction(at: date)
    #expect(fraction == 1.0, "dayFraction at noon was \(fraction), expected 1.0")
}

@Test
func dayFractionAtSunriseAnchorIsHalf() {
    // Sunrise anchor is 06:30. At the exact midpoint of the dawn
    // transition window, smoothstep(0.5) = 0.5.
    let date = dateAt(hour: 6, minute: 30)
    let fraction = SkyState.dayFraction(at: date)
    #expect(abs(fraction - 0.5) < 0.01, "dayFraction at sunrise anchor was \(fraction), expected ~0.5")
}

@Test
func dayFractionAtSunsetAnchorIsHalf() {
    let date = dateAt(hour: 18, minute: 30)
    let fraction = SkyState.dayFraction(at: date)
    #expect(abs(fraction - 0.5) < 0.01, "dayFraction at sunset anchor was \(fraction), expected ~0.5")
}

@Test
func dayFractionBeforeDawnWindowIsZero() {
    let date = dateAt(hour: 5, minute: 59)
    let fraction = SkyState.dayFraction(at: date)
    #expect(fraction == 0.0, "dayFraction at 05:59 was \(fraction), expected 0.0 (before dawn window)")
}

@Test
func dayFractionAfterDawnWindowIsOne() {
    let date = dateAt(hour: 7, minute: 1)
    let fraction = SkyState.dayFraction(at: date)
    #expect(fraction == 1.0, "dayFraction at 07:01 was \(fraction), expected 1.0 (after dawn window)")
}

@Test
func dayFractionBeforeDuskWindowIsOne() {
    let date = dateAt(hour: 17, minute: 59)
    let fraction = SkyState.dayFraction(at: date)
    #expect(fraction == 1.0, "dayFraction at 17:59 was \(fraction), expected 1.0 (before dusk window)")
}

@Test
func dayFractionAfterDuskWindowIsZero() {
    let date = dateAt(hour: 19, minute: 1)
    let fraction = SkyState.dayFraction(at: date)
    #expect(fraction == 0.0, "dayFraction at 19:01 was \(fraction), expected 0.0 (after dusk window)")
}

@Test
func dayFractionIsMonotonicAcrossDawn() {
    // The smoothstep curve never decreases through the dawn window.
    var previous = -1.0
    for minute in stride(from: 0, through: 60, by: 5) {
        let date = dateAt(hour: 6, minute: minute)
        let fraction = SkyState.dayFraction(at: date)
        #expect(fraction >= previous, "dayFraction decreased at 06:\(minute): \(previous) → \(fraction)")
        previous = fraction
    }
}

@Test
func dayFractionIsMonotonicAcrossDusk() {
    // Through the dusk window, fraction never increases.
    var previous = 2.0
    for minute in stride(from: 0, through: 60, by: 5) {
        let date = dateAt(hour: 18, minute: minute)
        let fraction = SkyState.dayFraction(at: date)
        #expect(fraction <= previous, "dayFraction increased at 18:\(minute): \(previous) → \(fraction)")
        previous = fraction
    }
}

// MARK: - smoothstep

@Test
func smoothstepBoundsAreZeroAndOne() {
    #expect(SkyState.smoothstep(0.0) == 0.0)
    #expect(SkyState.smoothstep(1.0) == 1.0)
    #expect(SkyState.smoothstep(-0.5) == 0.0, "smoothstep clamps below 0")
    #expect(SkyState.smoothstep(1.5) == 1.0, "smoothstep clamps above 1")
}

@Test
func smoothstepAtHalfIsHalf() {
    // 3 * 0.25 - 2 * 0.125 = 0.75 - 0.25 = 0.5
    #expect(abs(SkyState.smoothstep(0.5) - 0.5) < 1e-9)
}

// MARK: - SkyState star opacity coupling

@Test
func starOpacityIsOneAtNight() {
    let state = SkyState.current(at: dateAt(hour: 2, minute: 0))
    #expect(state.starOpacity == 1.0, "star opacity at deep night was \(state.starOpacity), expected 1.0")
}

@Test
func starOpacityIsZeroAtDay() {
    let state = SkyState.current(at: dateAt(hour: 12, minute: 0))
    #expect(state.starOpacity == 0.0, "star opacity at noon was \(state.starOpacity), expected 0.0")
}

@Test
func starOpacityIsHalfAtSunrise() {
    let state = SkyState.current(at: dateAt(hour: 6, minute: 30))
    #expect(abs(state.starOpacity - 0.5) < 0.01, "star opacity at sunrise anchor was \(state.starOpacity), expected ~0.5")
}

// MARK: - StarField determinism

@Test
func starFieldSeedIsStableForSameDate() {
    let dateA = dateAt(hour: 22, minute: 30)
    let dateB = dateAt(hour: 23, minute: 45)
    // Same calendar day → same seed.
    #expect(StarField.seed(for: dateA) == StarField.seed(for: dateB))
}

@Test
func starFieldSeedChangesAcrossDays() {
    let day1 = dateAt(hour: 22, minute: 0)
    var components = DateComponents()
    components.year = 2026
    components.month = 5
    components.day = 16
    components.hour = 22
    let day2 = Calendar.current.date(from: components)!
    #expect(StarField.seed(for: day1) != StarField.seed(for: day2))
}

@Test
func seededRandomIsDeterministic() {
    var rngA = SeededRandom(seed: 12345)
    var rngB = SeededRandom(seed: 12345)
    for _ in 0..<10 {
        #expect(rngA.nextDouble() == rngB.nextDouble())
    }
}

@Test
func seededRandomReturnsValuesInUnitRange() {
    var rng = SeededRandom(seed: 42)
    for _ in 0..<100 {
        let value = rng.nextDouble()
        #expect(value >= 0.0 && value < 1.0, "random value \(value) was outside [0, 1)")
    }
}

@Test
func seededRandomWithZeroSeedDoesNotLock() {
    var rng = SeededRandom(seed: 0)
    let first = rng.nextDouble()
    let second = rng.nextDouble()
    // Without the zero-seed safeguard the LCG would output 0
    // repeatedly. The constructor rewrites 0 → 1 internally.
    #expect(first != second || (first != 0 && second != 0))
}

// MARK: - Helpers

private func dateAt(hour: Int, minute: Int) -> Date {
    var components = DateComponents()
    components.year = 2026
    components.month = 5
    components.day = 15
    components.hour = hour
    components.minute = minute
    return Calendar.current.date(from: components) ?? .now
}
