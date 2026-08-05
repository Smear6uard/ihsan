import Foundation
import Testing
@testable import IhsanDesignSystem

/// The contrast audit for text standing on the SKY, re-run for
/// corrective H.
///
/// `PaletteV2ContrastTests` checks ink against the three ground
/// tokens. That was sufficient while the sky was a near-flat field
/// bounded by those tokens; it is not sufficient now. The day zenith
/// is a real lapis-leaning blue and the ramp down to the pale horizon
/// is long, so a marker label at 40% of the way down the plate stands
/// on a colour that is not any token — it is a point on the gradient.
///
/// Everything the plate prints on the sky is audited here against the
/// composed field at every height:
///
/// - the header's location line and inscription (ink / inkSecondary),
/// - each marker's two-line name-over-time label (ink / inkSecondary),
/// - the sunrise inscription (inkSecondary),
///
/// and the audit runs continuously across the phase cycle, not just on
/// the five plateaus, because the transitions are where a ramp can
/// quietly cross a text colour.
struct SkyFieldContrastTests {

    /// Heights sampled down the sky, from the top of the frame to the
    /// horizon chord. Fine enough that no gradient segment is skipped.
    private static let heights: [Double] = stride(from: 0.0, through: 1.0, by: 0.02).map { $0 }

    /// Primary ink holds AAA against the sky at every height, in every
    /// canonical state. The header's location line and every marker's
    /// prayer name are this pair.
    @Test(arguments: PaletteState.allCases)
    func primaryInkHoldsAAAAcrossTheWholeSky(state: PaletteState) {
        let tokens = state.tokens
        for height in Self.heights {
            let sky = CelestialSkyView.skyValue(atFraction: height, tokens: tokens)
            let ratio = tokens.inkValue.contrastRatio(against: sky)
            #expect(
                ratio >= 7.0,
                "\(state.rawValue) ink on sky at \(height) is \(ratio):1, below AAA"
            )
        }
    }

    /// Secondary ink holds AA against the sky at every height. Marker
    /// times and the sunrise inscription are this pair, and the
    /// deepened zenith is the case that made this test necessary.
    @Test(arguments: PaletteState.allCases)
    func secondaryInkHoldsAAAcrossTheWholeSky(state: PaletteState) {
        let tokens = state.tokens
        for height in Self.heights {
            let sky = CelestialSkyView.skyValue(atFraction: height, tokens: tokens)
            let ratio = tokens.inkSecondaryValue.contrastRatio(against: sky)
            #expect(
                ratio >= 4.5,
                "\(state.rawValue) inkSecondary on sky at \(height) is \(ratio):1, below AA"
            )
        }
    }

    /// The same audit swept continuously through the phase cycle. Any
    /// height at which primary ink drops below AA must be inside an
    /// active ink halo — the same deal `PaletteV2ContrastTests` strikes
    /// for the ground tokens, extended to the field.
    @Test
    func skyDipsOnlyUnderAnActiveHalo() {
        let steps = 600
        var subAA = 0
        var samples = 0
        for step in 0..<steps {
            let phase = SkyPhase(unit: Double(step) / Double(steps))
            let tokens = PaletteState.resolved(for: phase)
            for height in Self.heights {
                let sky = CelestialSkyView.skyValue(atFraction: height, tokens: tokens)
                let ratio = tokens.inkValue.contrastRatio(against: sky)
                samples += 1
                if ratio < 4.5 {
                    subAA += 1
                    #expect(
                        tokens.inkHaloStrength > 0.05,
                        "ink at \(ratio):1 on the sky with no halo, phase \(phase.unit) height \(height)"
                    )
                }
            }
        }
        let fraction = Double(subAA) / Double(samples)
        #expect(fraction < 0.06, "sub-AA sky passage covers \(fraction) of the swept field")
    }

    /// The Reduce Transparency fallback is a ground like any other:
    /// the flat sky must clear AAA for primary ink and AA for
    /// secondary, in every state.
    @Test(arguments: PaletteState.allCases)
    func flatSkyFallbackHoldsContrast(state: PaletteState) {
        let tokens = state.tokens
        let flat = CelestialSkyView.skyFlatValue(tokens: tokens)
        let primary = tokens.inkValue.contrastRatio(against: flat)
        let secondary = tokens.inkSecondaryValue.contrastRatio(against: flat)
        #expect(primary >= 7.0, "\(state.rawValue) ink on the flat sky is \(primary):1")
        #expect(secondary >= 4.5, "\(state.rawValue) inkSecondary on the flat sky is \(secondary):1")
    }

    /// And it must actually look like the sky it replaces — a flat
    /// fill that ignored the zenith would hand Reduce Transparency
    /// users a blank page on the day states. The fallback sits inside
    /// the ramp it averages, and on the day states it carries real
    /// blue rather than collapsing to the near-white horizon.
    @Test(arguments: [PaletteState.firstLight, PaletteState.morning, PaletteState.afternoon])
    func flatSkyFallbackKeepsTheSkyBlue(state: PaletteState) {
        let tokens = state.tokens
        let flat = CelestialSkyView.skyFlatValue(tokens: tokens)
        #expect(flat.oklab.b <= -0.015, "\(state.rawValue) flat sky lost its blue (b = \(flat.oklab.b))")
        #expect(
            flat.relativeLuminance < tokens.groundTopValue.relativeLuminance,
            "\(state.rawValue) flat sky is no deeper than its own horizon"
        )
        #expect(
            flat.relativeLuminance > tokens.skyZenithValue.relativeLuminance,
            "\(state.rawValue) flat sky is darker than its own zenith"
        )
    }

    /// The ramp is monotone in lightness on the day states: the sky
    /// gets steadily paler from the zenith down to the horizon, with
    /// no local reversal that would read as a band of its own. (The
    /// jewel states are exempt — their horizon wash is deliberately
    /// brighter than the ground beneath it.)
    @Test(arguments: [PaletteState.firstLight, PaletteState.morning, PaletteState.afternoon])
    func dayRampNeverReversesOnItsWayDown(state: PaletteState) {
        let samples = CelestialSkyView.skySamples(tokens: state.tokens)
        for (a, b) in zip(samples, samples.dropFirst()) {
            // Tolerance covers the last stop pair, where the ramp
            // settles from groundTop onto the marginally deeper
            // groundBottom.
            #expect(
                b.value.oklab.l >= a.value.oklab.l - 0.021,
                "\(state.rawValue) sky reverses between \(a.location) and \(b.location)"
            )
        }
    }

    /// Stops are dense enough that no single segment jumps a visible
    /// value step — the guard against banding on the longer day ramp.
    @Test(arguments: PaletteState.allCases)
    func noGradientSegmentJumpsAVisibleStep(state: PaletteState) {
        let samples = CelestialSkyView.skySamples(tokens: state.tokens)
        for (a, b) in zip(samples, samples.dropFirst()) {
            let step = abs(b.value.oklab.l - a.value.oklab.l)
            #expect(
                step <= 0.035,
                "\(state.rawValue) sky steps \(step) in lightness between \(a.location) and \(b.location) — too coarse to stay smooth"
            )
        }
    }
}
