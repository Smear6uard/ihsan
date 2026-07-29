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
}
