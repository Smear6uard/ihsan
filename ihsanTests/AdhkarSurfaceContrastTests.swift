import Foundation
import IhsanDesignSystem
import Testing
@testable import ihsan

/// Contrast for every mark and every line the remembrance surfaces
/// draw, across all five SkyPhases including dawn.
///
/// Text ≥ 4.5:1, and 7:1 for body reading. Non-text functional marks
/// ≥ 3:1 by silhouette — a gilded form may earn its edge from the
/// keyline that bounds it, the sheet-tile precedent.
@Suite("Adhkar surface contrast")
struct AdhkarSurfaceContrastTests {

    private let states = PaletteState.allCases

    private func silhouette(_ candidates: [SRGBValue], against surface: SRGBValue) -> Double {
        candidates.map { $0.contrastRatio(against: surface) }.max() ?? 0
    }

    /// Everything the reading surface can be drawn on: the ground it
    /// sits on full-screen, and the panel the offer card uses.
    private func surfaces(_ tokens: SkyPaletteTokens) -> [(String, SRGBValue)] {
        [
            ("groundTop", tokens.groundTopValue),
            ("groundBottom", tokens.groundBottomValue),
            ("panelFill", tokens.panelFillValue)
        ]
    }

    // MARK: - The reading

    /// The Arabic and the translation are body reading on the full sky
    /// ground, at the app's 7:1 bar.
    @Test
    func theReadingHoldsBodyContrastInEveryPhase() {
        for state in states {
            let tokens = state.tokens
            for (name, surface) in surfaces(tokens) {
                let ratio = tokens.inkValue.contrastRatio(against: surface)
                #expect(ratio >= 7.0, "\(state) reading on \(name) is \(ratio)")
            }
        }
    }

    /// Transliteration, citation, the chrome inscription and the
    /// window text are secondary — AA.
    @Test
    func theQuieterLinesHoldAAInEveryPhase() {
        for state in states {
            let tokens = state.tokens
            for (name, surface) in surfaces(tokens) {
                let ratio = tokens.inkSecondaryValue.contrastRatio(against: surface)
                #expect(ratio >= 4.5, "\(state) secondary line on \(name) is \(ratio)")
            }
        }
    }

    // MARK: - The marks

    /// A gilded sequence mark and a gilded ring mark separate from
    /// every ground by leaf or by the keyline that bounds it.
    @Test
    func gildedMarksSeparateFromEveryGround() {
        for state in states {
            let tokens = state.tokens
            for (name, surface) in surfaces(tokens) {
                let ratio = silhouette(
                    [tokens.leafGoldValue, tokens.keylineValue], against: surface
                )
                #expect(ratio >= 3.0, "\(state) gilded mark on \(name) is \(ratio)")
            }
        }
    }

    /// A mark not yet counted is drawn at 70% — an outline, not a
    /// solid — so what the eye sees is the stroke COMPOSITED over the
    /// ground. Measuring the token alone would flatter it; this
    /// measures the colour that actually lands on the page.
    private func pendingMark(on surface: SRGBValue, tokens: SkyPaletteTokens) -> SRGBValue {
        SRGBValue.mix(surface, tokens.inkSecondaryValue, amount: 0.70)
    }

    /// An ungilded mark says "not yet counted" — that is information,
    /// so it owes the 3:1 non-text bar.
    ///
    /// This is the test that caught the original choice. `metal` is
    /// the app's brass and the obvious colour for a quiet engraved
    /// mark, and it measures 2.58:1 at full strength on the worst
    /// ground — an uncounted mark nobody can see on a bright morning.
    @Test
    func engravedMarksSeparateFromEveryGround() {
        for state in states {
            let tokens = state.tokens
            for (name, surface) in surfaces(tokens) {
                let ratio = pendingMark(on: surface, tokens: tokens)
                    .contrastRatio(against: surface)
                #expect(ratio >= 3.0, "\(state) engraved mark on \(name) is \(ratio)")
            }
        }
    }

    /// Metal stays off functional marks. Pinned so the prettier choice
    /// cannot come back without someone deciding to.
    @Test
    func metalCannotCarryAFunctionalMark() {
        let worst = states.flatMap { state -> [Double] in
            let tokens = state.tokens
            return surfaces(tokens).map { tokens.metalValue.contrastRatio(against: $0.1) }
        }.min() ?? 0
        #expect(
            worst < 3.0,
            "metal now measures \(worst) at worst — reconsider the mark colour deliberately"
        )
    }

    /// "Where I am" has to be tellable from "not yet". The current
    /// mark is drawn in ink; the pending one in composited
    /// inkSecondary.
    @Test
    func theCurrentMarkIsDistinguishableFromAPendingOne() {
        for state in states {
            let tokens = state.tokens
            for (name, surface) in surfaces(tokens) {
                let ratio = tokens.inkValue
                    .contrastRatio(against: pendingMark(on: surface, tokens: tokens))
                #expect(
                    ratio >= 1.3,
                    "\(state) current and pending marks on \(name) are \(ratio) apart"
                )
            }
        }
    }

    /// The centre numeral of the counting ring is primary ink on the
    /// full sky ground — the same bar the tasbīḥ instrument's numeral
    /// holds.
    @Test
    func theCountNumeralHoldsOnTheSkyGround() {
        for state in states {
            let tokens = state.tokens
            for surface in [tokens.groundTopValue, tokens.groundBottomValue] {
                let ratio = tokens.inkValue.contrastRatio(against: surface)
                #expect(ratio >= 7.0, "\(state) numeral on ground \(ratio)")
            }
        }
    }

    /// Dawn is the phase most recently added and the easiest to forget,
    /// so it is asserted by name as well as by the sweep above.
    @Test
    func dawnIsCoveredByName() {
        let tokens = PaletteState.dawn.tokens
        #expect(tokens.inkValue.contrastRatio(against: tokens.groundTopValue) >= 7.0)
        #expect(tokens.inkSecondaryValue.contrastRatio(against: tokens.groundTopValue) >= 4.5)
        #expect(
            silhouette([tokens.leafGoldValue, tokens.keylineValue], against: tokens.groundTopValue) >= 3.0
        )
    }
}
