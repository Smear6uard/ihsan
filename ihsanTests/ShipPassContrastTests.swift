import Foundation
import IhsanDesignSystem
import Testing
@testable import ihsan

/// Contrast for the surfaces this ship pass added, across every
/// canonical SkyPhase — dawn included, because dawn is the phase where
/// the palette crosses from a dark ground to a light one and the same
/// ink has to survive both sides of the crossing.
///
/// Text ≥ 4.5:1. Functional non-text marks ≥ 3:1. Nothing here is
/// decoration: every colour tested carries a number a person reads or
/// a state they act on.
@Suite("Ship-pass surface contrast")
struct ShipPassContrastTests {

    private let states = PaletteState.allCases

    /// The angle figures ("15° / 15°") in gold on a settings panel.
    /// They exist to be checked against a printed timetable, which is
    /// the one thing that cannot be done with text you cannot read.
    @Test("Angle figures hold AA on their panel in every phase")
    func angleFiguresAreLegible() {
        for state in states {
            let tokens = state.tokens
            let ratio = tokens.inkValue.contrastRatio(against: tokens.panelFillValue)
            #expect(ratio >= 4.5, "\(state.displayName): angles on panel \(ratio)")
        }
    }

    /// The state a row reports — "ON TIME", "NOT LOGGED" — in
    /// yesterday's sheet and the large widget.
    @Test("Row state inscriptions hold AA on their panel")
    func stateInscriptionsAreLegible() {
        for state in states {
            let tokens = state.tokens
            let logged = tokens.inkValue.contrastRatio(against: tokens.panelFillValue)
            let unlogged = tokens.inkSecondaryValue.contrastRatio(against: tokens.panelFillValue)
            #expect(logged >= 4.5, "\(state.displayName): logged state \(logged)")
            #expect(unlogged >= 4.5, "\(state.displayName): unlogged state \(unlogged)")
        }
    }

    /// A selected timing chip is lapis on leaf gold — the same gilding
    /// the plate's current ornament wears, carrying a word.
    @Test("A selected chip's label holds AA on its gilding")
    func selectedChipLabelIsLegible() {
        for state in states {
            let tokens = state.tokens
            let ratio = tokens.keylineValue.contrastRatio(against: tokens.leafGoldValue)
            #expect(ratio >= 4.5, "\(state.displayName): keyline on leafGold \(ratio)")
        }
    }

    /// The offer line in the header sits on the page ground, not on a
    /// panel — it is the one new piece of text with no surface of its
    /// own beneath it.
    @Test("The yesterday line holds on the bare page ground")
    func theOfferLineIsLegible() {
        for state in states {
            let tokens = state.tokens
            for ground in [tokens.groundTopValue, tokens.groundBottomValue] {
                let ratio = tokens.inkSecondaryValue.contrastRatio(against: ground)
                #expect(ratio >= 4.5, "\(state.displayName): offer line on ground \(ratio)")
            }
            // Its dismiss mark is a functional non-text mark.
            // The mark is drawn in metal and reads by whichever of its
            // own colour or the ink beside it separates — the
            // silhouette rule every drawn mark in the app uses.
            let mark = max(
                tokens.metalValue.contrastRatio(against: tokens.groundBottomValue),
                tokens.inkSecondaryValue.contrastRatio(against: tokens.groundBottomValue)
            )
            #expect(mark >= 3.0, "\(state.displayName): dismiss mark \(mark)")
        }
    }

    // MARK: - The nightstand

    /// StandBy is read across a dark room through Night Mode's red
    /// shift, which discards blue and green entirely. Two things have
    /// to be true: the ink must separate from the night ground, and it
    /// must not be so bright that it becomes a light source.
    @Test("The nightstand ink separates without becoming a lamp")
    func standByInkIsReadableAndNotGlaring() {
        let night = PaletteState.night.tokens
        // The ground the nightstand face actually draws on: the night
        // ramp, dimmed.
        let ground = SRGBValue(
            red: night.groundBottomValue.red * 0.45,
            green: night.groundBottomValue.green * 0.45,
            blue: night.groundBottomValue.blue * 0.45
        )
        // Read from the token rather than restated here, so the test
        // and the face can never disagree about the colour.
        let ink = night.standByInkValue

        let ratio = ink.contrastRatio(against: ground)
        #expect(ratio >= 4.5, "Nightstand ink on its ground \(ratio)")

        // Under Night Mode only the red channel survives. The ink must
        // still separate when the other two are gone.
        let redOnly = SRGBValue(red: ink.red, green: 0, blue: 0)
        let groundRedOnly = SRGBValue(red: ground.red, green: 0, blue: 0)
        #expect(
            redOnly.contrastRatio(against: groundRedOnly) >= 4.5,
            "Nightstand ink fails once Night Mode drops blue and green"
        )

        // And nothing on the face is full white.
        #expect(ink.relativeLuminance < 0.85, "Nightstand ink is bright enough to glare")
    }

    // MARK: - Widget grounds

    /// Widgets are read against arbitrary wallpaper, so their ground is
    /// a touch deeper than the app's own page. The ink has to keep up.
    @Test("Widget ink holds on the deepened widget ground")
    func widgetInkHoldsOnItsGround() {
        for state in states {
            let tokens = state.tokens
            func deepened(_ value: SRGBValue, by amount: Double) -> SRGBValue {
                let k = 1 - amount
                return SRGBValue(red: value.red * k, green: value.green * k, blue: value.blue * k)
            }
            let ground = deepened(tokens.groundBottomValue, by: 0.16)

            #expect(
                tokens.inkValue.contrastRatio(against: ground) >= 4.5,
                "\(state.displayName): widget ink \(tokens.inkValue.contrastRatio(against: ground))"
            )
            #expect(
                tokens.inkSecondaryValue.contrastRatio(against: ground) >= 4.5,
                "\(state.displayName): widget secondary ink"
            )
            // A gilded ornament reads by silhouette: the leaf itself
            // or the keyline that bounds it, whichever separates. On
            // the morning parchment it is the keyline.
            let gilding = max(
                tokens.leafGoldValue.contrastRatio(against: ground),
                tokens.keylineValue.contrastRatio(against: ground)
            )
            #expect(gilding >= 3.0, "\(state.displayName): widget gilding \(gilding)")
        }
    }
}
