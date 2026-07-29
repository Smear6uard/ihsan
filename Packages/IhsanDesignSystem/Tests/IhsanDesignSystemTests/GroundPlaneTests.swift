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
