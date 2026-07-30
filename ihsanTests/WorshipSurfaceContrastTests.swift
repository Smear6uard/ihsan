import Foundation
import IhsanDesignSystem
import Testing
@testable import ihsan

/// Contrast for the wider-worship surfaces — the Hijri month sheet,
/// the fasting inscriptions, and the tasbīḥ instrument — across every
/// canonical SkyPhase, dawn included. Text ≥ 4.5:1 (7:1 for body
/// ink); non-text functional marks ≥ 3:1 by silhouette (a gilded form
/// may earn its edge from the keyline that bounds it, the sheet-tile
/// precedent).
@Suite("Wider-worship surface contrast")
struct WorshipSurfaceContrastTests {

    private let states = PaletteState.allCases

    private func silhouette(_ candidates: [SRGBValue], against surface: SRGBValue) -> Double {
        candidates.map { $0.contrastRatio(against: surface) }.max() ?? 0
    }

    /// The Hijri sheet's gilded today: the keyline numeral on its
    /// leaf-gold disc is text and holds AA in every phase.
    @Test
    func gildedTodayNumeralHoldsOnItsLeaf() {
        for state in states {
            let tokens = state.tokens
            let ratio = tokens.keylineValue.contrastRatio(against: tokens.leafGoldValue)
            #expect(ratio >= 4.5, "\(state) keyline on leafGold \(ratio)")
        }
    }

    /// The gilded forms the new surfaces add — the ring's marks, the
    /// cycle dots, the today disc — read against every ground by
    /// silhouette: the leaf or its keyline edge, whichever separates.
    @Test
    func gildedMarksSeparateFromEveryGround() {
        for state in states {
            let tokens = state.tokens
            for surface in [tokens.groundTopValue, tokens.groundBottomValue, tokens.panelFillValue] {
                let ratio = silhouette(
                    [tokens.leafGoldValue, tokens.keylineValue], against: surface
                )
                #expect(ratio >= 3.0, "\(state) gilded mark on ground \(ratio)")
            }
        }
    }

    /// The fasting inscription and the sunrise inscription sit in
    /// inkSecondary directly on the sky ground — secondary text, AA.
    @Test
    func inscriptionsHoldOnTheSkyGround() {
        for state in states {
            let tokens = state.tokens
            for surface in [tokens.groundTopValue, tokens.groundBottomValue, tokens.groundPlaneValue] {
                let ratio = tokens.inkSecondaryValue.contrastRatio(against: surface)
                #expect(ratio >= 4.5, "\(state) inkSecondary on ground \(ratio)")
            }
        }
    }

    /// The instrument's center numeral is primary ink on the full sky
    /// ground — 7:1 like every body reading.
    @Test
    func dhikrNumeralHoldsOnTheSkyGround() {
        for state in states {
            let tokens = state.tokens
            for surface in [tokens.groundTopValue, tokens.groundBottomValue] {
                let ratio = tokens.inkValue.contrastRatio(against: surface)
                #expect(ratio >= 7.0, "\(state) ink on ground \(ratio)")
            }
        }
    }
}
