import Foundation
import Testing
@testable import IhsanDesignSystem

/// SkyPhase and palette interpolation contracts: solar-event
/// resolution, plateau identity, and — the structural fix for the
/// previously flagged snapping bug — continuity of every token across
/// the entire phase cycle.
struct SkyPhaseTests {

    // MARK: - Continuity (the anti-snapping contract)

    /// Two-part anti-snapping contract.
    ///
    /// Part 1 — bounded speed: at 2,000 samples/cycle no channel may
    /// move more than 0.10/step. The fastest legitimate motion is a
    /// figure token (ink/panel) crossing its narrow window: ≈0.85 of
    /// channel range over 0.01 of the cycle (figureHalfWidth 0.005)
    /// = 20 samples, times smootherstep's 1.875× peak slope
    /// ≈ 0.08/step. v1's sunrise flip crossed the same distance in
    /// ~1 sample (≈0.85/step).
    ///
    /// Part 2 — true continuity: quadrupling the sampling density must
    /// cut the worst per-step delta by ≈4× (any continuous curve
    /// scales linearly; a discontinuity's delta would not shrink at
    /// all). This detects a snap of ANY size, independent of speed
    /// tuning.
    @Test
    func noTokenSnapsAnywhereInTheCycle() {
        func maxStepDelta(samples: Int) -> Double {
            var previous = PaletteState.resolved(for: SkyPhase(unit: 0))
            var worst = 0.0
            for step in 1...samples {
                let tokens = PaletteState.resolved(for: SkyPhase(unit: Double(step) / Double(samples)))
                for (a, b) in zip(channels(of: previous), channels(of: tokens)) {
                    worst = max(worst, abs(a - b))
                }
                previous = tokens
            }
            return worst
        }

        let coarse = maxStepDelta(samples: 2_000)
        #expect(coarse <= 0.10, "worst per-step channel delta \(coarse) exceeds continuous-motion bound")

        let fine = maxStepDelta(samples: 8_000)
        #expect(
            fine <= coarse / 2.5,
            "refining the sampling barely reduced the worst delta (\(coarse) → \(fine)) — discontinuity"
        )
    }

    /// The cycle must close: phase 0 and phase 1 are the same moment.
    @Test
    func cycleWrapsSeamlessly() {
        let atZero = PaletteState.resolved(for: SkyPhase(unit: 0.0))
        let atOne = PaletteState.resolved(for: SkyPhase(unit: 0.999999))
        for (a, b) in zip(channels(of: atZero), channels(of: atOne)) {
            #expect(abs(a - b) < 0.01)
        }
    }

    private func channels(of tokens: SkyPaletteTokens) -> [Double] {
        let values = [
            tokens.groundTopValue, tokens.groundBottomValue, tokens.horizonWashValue,
            tokens.inkValue, tokens.inkSecondaryValue, tokens.metalValue,
            tokens.metalHighlightValue, tokens.glowValue, tokens.panelFillValue,
            tokens.panelStrokeValue, tokens.panelTextureValue,
            tokens.positiveValue, tokens.attentionValue
        ]
        return values.flatMap { [$0.red, $0.green, $0.blue] } + [tokens.panelTextureOpacity]
    }

    // MARK: - Plateaus and fixed states

    @Test(arguments: PaletteState.allCases)
    func fixedPhaseReturnsCanonicalTokens(state: PaletteState) {
        #expect(PaletteState.resolved(for: .fixed(state)) == state.tokens)
    }

    @Test
    func plateausHoldSteadyAwayFromTransitions() {
        // Each unit sits well clear of every transition band.
        #expect(PaletteState.resolved(for: SkyPhase(unit: 0.01)) == SkyPaletteTokens.night)
        #expect(PaletteState.resolved(for: SkyPhase(unit: 0.105)) == SkyPaletteTokens.dawn)
        #expect(PaletteState.resolved(for: SkyPhase(unit: 0.2275)) == SkyPaletteTokens.firstLight)
        #expect(PaletteState.resolved(for: SkyPhase(unit: 0.3475)) == SkyPaletteTokens.morning)
        #expect(PaletteState.resolved(for: SkyPhase(unit: 0.55)) == SkyPaletteTokens.afternoon)
        #expect(PaletteState.resolved(for: SkyPhase(unit: 0.80)) == SkyPaletteTokens.sunset)
    }

    // MARK: - Solar-event resolution

    private var normalDay: SolarDayEvents {
        // A temperate-latitude day, expressed as absolute instants.
        let base = Date(timeIntervalSinceReferenceDate: 800_000_000)
        return SolarDayEvents(
            fajr: base.addingTimeInterval(4.5 * 3600),
            sunrise: base.addingTimeInterval(6 * 3600),
            solarNoon: base.addingTimeInterval(13 * 3600),
            maghrib: base.addingTimeInterval(20 * 3600),
            isha: base.addingTimeInterval(21.5 * 3600)
        )
    }

    @Test
    func eventsLandOnTheirPaletteAnchors() {
        let events = normalDay
        #expect(abs(SkyPhase.resolve(at: events.fajr, events: events).unit - SkyPhase.fajrUnit) < 0.001)
        #expect(abs(SkyPhase.resolve(at: events.sunrise, events: events).unit - SkyPhase.sunriseUnit) < 0.001)
        #expect(abs(SkyPhase.resolve(at: events.solarNoon, events: events).unit - SkyPhase.solarNoonUnit) < 0.001)
        #expect(abs(SkyPhase.resolve(at: events.maghrib, events: events).unit - SkyPhase.maghribUnit) < 0.001)
        #expect(abs(SkyPhase.resolve(at: events.isha, events: events).unit - SkyPhase.ishaUnit) < 0.001)
    }

    // MARK: - Dawn

    /// The dawn contract: for t in [fajr, sunrise) the dominant state
    /// is night or dawn — never morning; the morning plateau begins
    /// only after the sunrise transition band completes.
    @Test
    func fajrToSunriseIsDawnTwilightNeverMorning() {
        let events = normalDay
        let span = events.sunrise.timeIntervalSince(events.fajr)
        for step in 0..<40 {
            let t = events.fajr.addingTimeInterval(span * Double(step) / 40.0)
            let dominant = SkyPhase.resolve(at: t, events: events).dominantState
            #expect(
                dominant == .night || dominant == .dawn,
                "morning leaked into the fajr→sunrise passage at step \(step)"
            )
        }
        // Mid-dawn holds the canonical dawn plateau.
        let midDawn = events.fajr.addingTimeInterval(span / 2)
        #expect(PaletteState.resolved(for: SkyPhase.resolve(at: midDawn, events: events)) == SkyPaletteTokens.dawn)
    }

    /// Stars fade progressively across the dawn passage: full before
    /// fajr, monotonically thinning, and effectively gone at sunrise.
    @Test
    func nightnessFadesProgressivelyAcrossDawn() {
        let events = normalDay
        let beforeFajr = SkyPhase.resolve(at: events.fajr.addingTimeInterval(-3600), events: events)
        #expect(beforeFajr.nightness > 0.95)

        let span = events.sunrise.timeIntervalSince(events.fajr)
        var previous = 2.0
        for step in 0...20 {
            let t = events.fajr.addingTimeInterval(span * Double(step) / 20.0)
            let nightness = SkyPhase.resolve(at: t, events: events).nightness
            #expect(nightness <= previous + 1e-9, "stars brightened mid-dawn at step \(step)")
            previous = nightness
        }
        let atSunrise = SkyPhase.resolve(at: events.sunrise, events: events)
        #expect(atSunrise.nightness < 0.10)

        let midMorning = SkyPhase.resolve(at: events.sunrise.addingTimeInterval(2 * 3600), events: events)
        #expect(midMorning.nightness == 0.0)
    }

    /// The dawn wash grows toward sunrise and hands off after it.
    @Test
    func dawnProgressGrowsTowardSunrise() {
        let events = normalDay
        #expect(SkyPhase.resolve(at: events.fajr.addingTimeInterval(-3600), events: events).dawnProgress == 0)
        let span = events.sunrise.timeIntervalSince(events.fajr)
        let early = SkyPhase.resolve(at: events.fajr.addingTimeInterval(span * 0.25), events: events).dawnProgress
        let late = SkyPhase.resolve(at: events.fajr.addingTimeInterval(span * 0.75), events: events).dawnProgress
        #expect(early < late)
        #expect(SkyPhase.resolve(at: events.sunrise, events: events).dawnProgress > 0.95)
        #expect(SkyPhase.resolve(at: events.sunrise.addingTimeInterval(2 * 3600), events: events).dawnProgress == 0)
    }

    @Test
    func midMorningResolvesToMorningPlateau() {
        let events = normalDay
        let midMorning = events.sunrise.addingTimeInterval(
            events.solarNoon.timeIntervalSince(events.sunrise) / 2
        )
        let phase = SkyPhase.resolve(at: midMorning, events: events)
        #expect(phase.dominantState == .morning)
        #expect(PaletteState.resolved(for: phase) == SkyPaletteTokens.morning)
    }

    @Test
    func deepNightResolvesToNightBeforeAndAfterMidnight() {
        let events = normalDay
        let lateNight = events.isha.addingTimeInterval(3 * 3600)
        let preDawn = events.sunrise.addingTimeInterval(-2 * 3600)
        #expect(SkyPhase.resolve(at: lateNight, events: events).dominantState == .night)
        #expect(SkyPhase.resolve(at: preDawn, events: events).dominantState == .night)
    }

    @Test
    func resolutionIsMonotonicAcrossTheDay() {
        let events = normalDay
        let start = events.sunrise.addingTimeInterval(-4 * 3600)
        var lastUnwrapped = -1.0
        for minute in stride(from: 0.0, through: 24 * 60, by: 5.0) {
            let phase = SkyPhase.resolve(at: start.addingTimeInterval(minute * 60), events: events)
            // Unwrap: units may cross 1.0 → 0.0 once late at night.
            var unit = phase.unit
            while unit < lastUnwrapped - 0.5 { unit += 1.0 }
            #expect(unit >= lastUnwrapped - 1e-9, "phase went backwards at minute \(minute)")
            lastUnwrapped = unit
        }
    }

    /// Degenerate high-latitude input (events crammed together) must
    /// not crash, divide by zero, or produce NaN.
    @Test
    func degenerateEventOrderingIsGuarded() {
        let base = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let events = SolarDayEvents(
            fajr: base.addingTimeInterval(10),  // after sunrise
            sunrise: base,
            solarNoon: base,          // coincident
            maghrib: base.addingTimeInterval(60),
            isha: base.addingTimeInterval(30)  // out of order
        )
        for hour in 0..<24 {
            let phase = SkyPhase.resolve(at: base.addingTimeInterval(Double(hour) * 3600), events: events)
            #expect(phase.unit.isFinite)
            #expect(phase.unit >= 0 && phase.unit < 1)
        }
    }

    // MARK: - Nightness

    @Test
    func nightnessFadesInsteadOfStepping() {
        #expect(SkyPhase.fixed(.night).nightness == 1.0)
        #expect(SkyPhase.fixed(.morning).nightness == 0.0)
        // Mid-dawn the last stars are still out; by sunrise they are
        // effectively gone — the fade spans the whole passage.
        #expect(SkyPhase.fixed(.dawn).nightness > 0.2)
        #expect(SkyPhase.fixed(.dawn).nightness < 0.8)
        #expect(SkyPhase(unit: SkyPhase.sunriseUnit).nightness < 0.10)
        // The evening side is untouched: at the isha boundary center
        // the blend is half night.
        let atIsha = SkyPhase(unit: SkyPhase.ishaUnit)
        #expect(abs(atIsha.nightness - 0.5) < 0.01)
    }

    // MARK: - OKLab math

    @Test
    func oklabRoundTripsWithinOneStep() {
        let samples: [UInt32] = [0x0E1330, 0xF5F7FA, 0x7A2233, 0xC9A96A, 0x1B2350, 0x8FBF9F]
        for hex in samples {
            let original = SRGBValue(hex: hex)
            let roundTripped = original.oklab.srgb
            #expect(abs(original.red - roundTripped.red) < 1.0 / 255.0)
            #expect(abs(original.green - roundTripped.green) < 1.0 / 255.0)
            #expect(abs(original.blue - roundTripped.blue) < 1.0 / 255.0)
        }
    }

    @Test
    func oklabMixEndpointsAreExact() {
        let a = SRGBValue(hex: 0x0E1330)
        let b = SRGBValue(hex: 0xF5F7FA)
        let at0 = SRGBValue.mix(a, b, amount: 0)
        let at1 = SRGBValue.mix(a, b, amount: 1)
        #expect(abs(at0.red - a.red) < 1.0 / 255.0 && abs(at1.red - b.red) < 1.0 / 255.0)
        #expect(abs(at0.green - a.green) < 1.0 / 255.0 && abs(at1.green - b.green) < 1.0 / 255.0)
        #expect(abs(at0.blue - a.blue) < 1.0 / 255.0 && abs(at1.blue - b.blue) < 1.0 / 255.0)
    }

    // MARK: - First light

    /// The morning gets a chapter, not just a boundary. The evening
    /// has both (maghrib the boundary, sunset the state); before this
    /// the morning's equivalent moment owned no tokens at all.
    @Test
    func firstLightHoldsItsOwnPlateau() {
        let phase = SkyPhase.fixed(.firstLight)
        let mix = phase.blend
        #expect(mix.amount == 0, "firstLight's fixed phase is not on a plateau")
        #expect(mix.from == .firstLight)
        #expect(PaletteState.resolved(for: phase) == SkyPaletteTokens.firstLight)
    }

    /// Every transition band must be disjoint, or two boundaries would
    /// blend at once and a state could lose its plateau entirely.
    @Test
    func noTwoTransitionBandsOverlap() {
        let centres = [
            SkyPhase.fajrUnit, SkyPhase.sunriseUnit, SkyPhase.firstLightEndUnit,
            SkyPhase.solarNoonUnit, SkyPhase.maghribUnit, SkyPhase.ishaUnit
        ]
        for (a, b) in zip(centres, centres.dropFirst()) {
            #expect(
                b - a > 2 * SkyPhase.atmosphereHalfWidth,
                "boundaries at \(a) and \(b) are closer than a full band apart"
            )
        }
        // The night wraps.
        #expect(
            (SkyPhase.fajrUnit + 1.0) - SkyPhase.ishaUnit > 2 * SkyPhase.atmosphereHalfWidth
        )
    }

    /// The sixth anchor is DERIVED — `SolarDayEvents` gains no field.
    /// First light lasts as long as the dawn that preceded it, capped
    /// so an extreme-latitude dawn cannot swallow the morning.
    @Test
    func firstLightEndMirrorsTheDawnSpan() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        func date(_ h: Int, _ m: Int) -> Date {
            calendar.date(from: DateComponents(
                year: 2026, month: 8, day: 2, hour: h, minute: m
            ))!
        }
        let events = SolarDayEvents(
            fajr: date(4, 14), sunrise: date(5, 45), solarNoon: date(12, 58),
            maghrib: date(20, 8), isha: date(21, 38)
        )
        // 5:45 + (5:45 − 4:14) = 7:16.
        let expected = date(7, 16)
        let resolved = SkyPhase.resolve(at: expected, events: events)
        #expect(
            abs(resolved.unit - SkyPhase.firstLightEndUnit) < 0.002,
            "first light ends at \(resolved.unit), expected \(SkyPhase.firstLightEndUnit)"
        )
        // 6:15 — the moment this state exists for — is on the plateau.
        #expect(SkyPhase.resolve(at: date(6, 15), events: events).blend.amount == 0)
        #expect(SkyPhase.resolve(at: date(6, 15), events: events).blend.from == .firstLight)
    }

    /// firstLight → morning carries NO polarity flip: both are
    /// luminous day states and firstLight's figure roles are morning's
    /// exactly. Only sunrise and maghrib may cross.
    @Test
    func onlySunriseAndMaghribCross() {
        let steps = 4_000
        for step in 0..<steps {
            let phase = SkyPhase(unit: Double(step) / Double(steps))
            guard phase.inkHaloStrength > 0.01 else { continue }
            let nearSunrise = abs(phase.unit - SkyPhase.sunriseUnit) <= SkyPhase.atmosphereHalfWidth
            let nearMaghrib = abs(phase.unit - SkyPhase.maghribUnit) <= SkyPhase.atmosphereHalfWidth
            #expect(
                nearSunrise || nearMaghrib,
                "a polarity crossing appeared at phase \(phase.unit)"
            )
        }
    }
}
