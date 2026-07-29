import Foundation
import Testing
@testable import IhsanDesignSystem

/// Part-B item 7: the plate must visually terminate — the ground
/// plane and the horizon band have to be measurably present against
/// the sky in every palette state, not a rumor that dissolves on an
/// OLED. These are the source-side floors; the on-device check reads
/// the same steps off a screenshot.
struct GroundPlaneTests {

    /// The ground plane sits a real luminance step below the sky's
    /// bottom anchor — the same material, visibly deeper.
    @Test(arguments: PaletteState.allCases)
    func subterraneanIsAVisibleStepDown(state: PaletteState) {
        let tokens = state.tokens
        let sky = tokens.groundBottomValue.relativeLuminance
        let ground = tokens.subterraneanValue.relativeLuminance
        #expect(ground < sky, "\(state) ground must be deeper than its sky")
        // Relative floor: at least a 10% luminance drop from the sky.
        #expect(
            (sky - ground) / max(sky, 0.001) >= 0.10,
            "\(state): ground step \(sky - ground) too subtle against sky \(sky)"
        )
    }

    // MARK: - Corrective E item 4: the token audit

    /// The ground plane is never a desaturated gray: every state's
    /// token carries real chroma. The pre-corrective derivation
    /// (lightness-scaling the cool near-white sky) yielded OKLab
    /// chroma ≈ 0.005 on the day states — unpainted primer. The
    /// floor here is set well above that failure mode.
    @Test(arguments: PaletteState.allCases)
    func groundPlaneIsNeverGray(state: PaletteState) {
        let lab = state.tokens.groundPlaneValue.oklab
        let chroma = (lab.a * lab.a + lab.b * lab.b).squareRoot()
        #expect(
            chroma >= 0.02,
            "\(state) groundPlane chroma \(chroma) reads as gray"
        )
    }

    /// Day states stand on warm ivory — the OKLab b-axis (blue−yellow)
    /// must sit clearly on the yellow side. Night states stay in the
    /// indigo/plum families of their skies (b ≤ 0 for indigo; sunset's
    /// plum holds red chroma instead).
    @Test
    func groundPlaneFamiliesMatchTheSpec() {
        let morning = PaletteState.morning.tokens.groundPlaneValue.oklab
        let afternoon = PaletteState.afternoon.tokens.groundPlaneValue.oklab
        #expect(morning.b >= 0.02, "morning ground must be warm ivory, not cool gray")
        #expect(afternoon.b >= 0.02, "afternoon ground must be warm ivory, not cool gray")

        let night = PaletteState.night.tokens.groundPlaneValue.oklab
        #expect(night.b <= -0.02, "night ground stays in the indigo family")

        let sunset = PaletteState.sunset.tokens.groundPlaneValue.oklab
        #expect(sunset.a >= 0.02, "sunset ground stays in the plum family")
    }

    /// The horizon wash is a distinct hue/luminance from the sky it
    /// sits on — at the drawn 0.70 peak opacity the composited band
    /// must differ from the plain sky by a noticeable margin.
    @Test(arguments: PaletteState.allCases)
    func horizonBandIsMeasurable(state: PaletteState) {
        let tokens = state.tokens
        let sky = tokens.groundBottomValue
        let wash = tokens.horizonWashValue
        let composited = SRGBValue.mix(sky, wash, amount: 0.70)
        let delta = abs(composited.relativeLuminance - sky.relativeLuminance)
        #expect(
            delta >= 0.008,
            "\(state): composited band delta \(delta) reads as absent"
        )
    }
}
