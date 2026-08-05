import Foundation
import Testing
@testable import IhsanDesignSystem

/// Corrective F: the illumination pass's token contracts. The gilded
/// treatment only works if the leaf reads as leaf and the keyline
/// reads as a dark edge — these pin both mathematically so no state
/// can drift back to "tan line on cream".
struct IlluminationTokenTests {

    /// The keyline is deep ultramarine in every state: near-black in
    /// value, unmistakably on the blue side in hue.
    @Test(arguments: PaletteState.allCases)
    func keylineIsDeepUltramarine(state: PaletteState) {
        let keyline = state.tokens.keylineValue
        #expect(
            keyline.relativeLuminance <= 0.035,
            "\(state) keyline is not a deep accent"
        )
        #expect(
            keyline.oklab.b <= -0.03,
            "\(state) keyline has drifted out of the ultramarine family"
        )
    }

    /// The solid fill is burnished gold — saturated and warm, sitting
    /// in the mid values where a dark keyline and a bright ground can
    /// both bound it.
    @Test(arguments: PaletteState.allCases)
    func leafGoldReadsAsLeaf(state: PaletteState) {
        let leaf = state.tokens.leafGoldValue.oklab
        let chroma = (leaf.a * leaf.a + leaf.b * leaf.b).squareRoot()
        #expect(chroma >= 0.06, "\(state) leaf gold is undersaturated")
        #expect(leaf.b >= 0.05, "\(state) leaf gold is not warm")
        let luminance = state.tokens.leafGoldValue.relativeLuminance
        #expect(
            luminance > 0.25 && luminance < 0.65,
            "\(state) leaf gold \(luminance) leaves the burnished mid range"
        )
    }

    /// The dark edge must actually separate the leaf from the field:
    /// keyline vs leaf gold holds a strong contrast in every state.
    @Test(arguments: PaletteState.allCases)
    func keylineBoundsTheLeaf(state: PaletteState) {
        let ratio = state.tokens.keylineValue.contrastRatio(
            against: state.tokens.leafGoldValue
        )
        #expect(ratio >= 4.5, "\(state) keyline/leaf contrast \(ratio) too soft")
    }

    // MARK: - Phase 2: the chord

    /// The day-state zenith is a genuine sky, deepest overhead.
    ///
    /// Corrective H item 1 moved this contract's floor. Before, the
    /// zenith was a faint tint held above 0.55 luminance — "a hint of
    /// blue on a near-white page". A real sky is deepest at the top,
    /// so the luminance floor drops to 0.40 (still firmly a light-key
    /// field: the horizon it grades into sits above 0.88) and the
    /// BLUENESS requirement tightens by 3× in its place. The zenith
    /// can never again be a near-white, and it can never be a dark
    /// ceiling either.
    @Test
    func dayZenithsCarryRealBlue() {
        for state in [PaletteState.firstLight, .morning, .afternoon] {
            let zenith = state.tokens.skyZenithValue
            let lab = zenith.oklab
            let chroma = (lab.a * lab.a + lab.b * lab.b).squareRoot()
            #expect(lab.b <= -0.06, "\(state) zenith is not blue enough (b = \(lab.b))")
            #expect(chroma >= 0.06, "\(state) zenith is a tint, not a sky (C = \(chroma))")
            #expect(
                zenith.relativeLuminance >= 0.40,
                "\(state) zenith too heavy — the day field must stay light-key"
            )
            #expect(
                zenith.relativeLuminance <= 0.62,
                "\(state) zenith too pale to read as a zenith"
            )
        }
    }

    /// The zenith is a real value step below the horizon it grades
    /// into — the gradient has somewhere to go. Without this the sky
    /// can satisfy "is blue" while still being flat.
    @Test(arguments: [PaletteState.firstLight, PaletteState.morning, PaletteState.afternoon])
    func dayZenithIsDeeperThanItsHorizon(state: PaletteState) {
        let tokens = state.tokens
        let zenith = tokens.skyZenithValue.oklab.l
        let horizon = tokens.groundBottomValue.oklab.l
        #expect(
            horizon - zenith >= 0.12,
            "\(state) sky spans only \(horizon - zenith) in lightness — reads flat"
        )
    }

    /// The day sky warms as the day goes on, and it does so in ONE
    /// direction. In OKLCH all three day zeniths sit in the blue
    /// quadrant; each successive one is further round toward violet,
    /// which is the warm direction from blue.
    ///
    /// Corrective I extended this from a pair to a progression. It was
    /// morning-vs-afternoon while those were the only day states; the
    /// claim it was really making is that the sky's hue is monotone
    /// across the day, and a first-light zenith cooler than morning's
    /// is what makes that claim worth stating rather than asserting a
    /// single comparison twice.
    @Test
    func theDayZenithsWarmMonotonically() {
        func hueDegrees(_ value: SRGBValue) -> Double {
            let lab = value.oklab
            return atan2(lab.b, lab.a) * 180 / .pi
        }
        let hues = [PaletteState.firstLight, .morning, .afternoon]
            .map { ($0, hueDegrees($0.tokens.skyZenithValue)) }
        for (earlier, later) in zip(hues, hues.dropFirst()) {
            #expect(
                later.1 - earlier.1 >= 5.0,
                "\(later.0) zenith (\(later.1)°) is not warmer than \(earlier.0)'s (\(earlier.1)°)"
            )
        }
    }

    /// Lapis is ultramarine in every state: blue-side hue, real
    /// chroma, deep enough to read as pigment beside the gold.
    @Test(arguments: PaletteState.allCases)
    func lapisIsUltramarine(state: PaletteState) {
        let lapis = state.tokens.lapisValue.oklab
        #expect(lapis.b <= -0.05, "\(state) lapis is not on the blue side")
        let chroma = (lapis.a * lapis.a + lapis.b * lapis.b).squareRoot()
        #expect(chroma >= 0.06, "\(state) lapis is undersaturated")
    }

    /// Text over the zenith stays legible: primary ink at AAA,
    /// secondary at AA, on every state's zenith (the header sits on
    /// this field).
    @Test(arguments: PaletteState.allCases)
    func textHoldsContrastOnTheZenith(state: PaletteState) {
        let tokens = state.tokens
        let primary = tokens.inkValue.contrastRatio(against: tokens.skyZenithValue)
        let secondary = tokens.inkSecondaryValue.contrastRatio(against: tokens.skyZenithValue)
        #expect(primary >= 7.0, "\(state) ink on zenith \(primary) below AAA")
        #expect(secondary >= 4.5, "\(state) inkSecondary on zenith \(secondary) below AA")
    }
}
