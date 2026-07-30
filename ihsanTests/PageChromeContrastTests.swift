import Foundation
import IhsanDesignSystem
import Testing
@testable import ihsan

/// The secondary pages' contrast contract, in all four canonical
/// SkyPhases: ink on the quiet page ground, ink on panels, and every
/// mark of the Path pattern's dot-state language against the panel
/// it sits on. Body text targets 7:1; secondary text ≥4.5:1;
/// non-text marks ≥3:1 with the sheet's 1.9:1 presence floor for
/// quiet fills.
@Suite("Page chrome contrast")
struct PageChromeContrastTests {

    private let states = PaletteState.allCases

    private func silhouette(_ candidates: [SRGBValue], against surface: SRGBValue) -> Double {
        candidates.map { $0.contrastRatio(against: surface) }.max() ?? 0
    }

    // MARK: - Page ground

    @Test
    func inkHoldsSevenToOneOnThePageGroundInEveryPhase() {
        for state in states {
            let tokens = state.tokens
            for surface in [tokens.pageGroundTopValue, tokens.pageGroundBottomValue, tokens.pageGroundFlatValue] {
                let ink = tokens.inkValue.contrastRatio(against: surface)
                let secondary = tokens.inkSecondaryValue.contrastRatio(against: surface)
                #expect(ink >= 7.0, "\(state) ink on page ground \(ink)")
                #expect(secondary >= 4.5, "\(state) inkSecondary on page ground \(secondary)")
            }
        }
    }

    /// The quiet derivation must stay in the sky's family — the page
    /// ground sits between the sky's own anchors, never outside them.
    @Test
    func pageGroundStaysInsideTheSkysValueRange() {
        for state in states {
            let tokens = state.tokens
            let top = tokens.pageGroundTopValue.relativeLuminance
            let skyTop = tokens.groundTopValue.relativeLuminance
            let skyBottom = tokens.groundBottomValue.relativeLuminance
            let lo = min(skyTop, skyBottom) - 0.0001
            let hi = max(skyTop, skyBottom) + 0.0001
            #expect(top >= lo && top <= hi, "\(state) page top outside sky range")
        }
    }

    // MARK: - Panels on the page

    @Test
    func inkHoldsOnThePanelInEveryPhase() {
        for state in states {
            let tokens = state.tokens
            let panel = tokens.panelFillValue
            #expect(tokens.inkValue.contrastRatio(against: panel) >= 7.0, "\(state) ink on panel")
            #expect(
                tokens.inkSecondaryValue.contrastRatio(against: panel) >= 4.5,
                "\(state) inkSecondary on panel"
            )
        }
    }

    // MARK: - The prompt text (Reflect's hero)

    /// The reflection prompt is the page's most-read passage: italic
    /// serif ink on the hero panel. Body targets 7:1 in every phase;
    /// the citation line under it holds ≥4.5:1. This is the "prompt
    /// text specifically" contrast report the repaint was gated on —
    /// the old navy-on-brown pairing failed exactly here.
    @Test
    func promptTextReadsComfortablyInEveryPhase() {
        for state in states {
            let tokens = state.tokens
            let panel = tokens.panelFillValue
            let prompt = tokens.inkValue.contrastRatio(against: panel)
            let citation = tokens.inkSecondaryValue.contrastRatio(against: panel)
            #expect(prompt >= 7.0, "\(state) prompt \(String(format: "%.2f", prompt)):1")
            #expect(citation >= 4.5, "\(state) citation \(String(format: "%.2f", citation)):1")
        }
    }

    // MARK: - The dot-state language

    @Test
    func everyDotStateReadsOnItsPanelInEveryPhase() {
        for state in states {
            let tokens = state.tokens
            let panel = tokens.panelFillValue

            // On time — gilded: leaf carried by body or keyline.
            let onTime = silhouette([tokens.leafGoldValue, tokens.keylineValue], against: panel)
            #expect(onTime >= 3.0, "\(state) onTime dot \(onTime)")

            // Jamāʿah halo ring — the bright metal must itself read.
            let halo = silhouette(
                [tokens.metalHighlightValue, tokens.leafGoldValue, tokens.keylineValue],
                against: panel
            )
            #expect(halo >= 3.0, "\(state) jamāʿah dot \(halo)")

            // Late — the deepened warm outline.
            let late = GestaltDot.lateOutlineValue(for: tokens).contrastRatio(against: panel)
            #expect(late >= 3.0, "\(state) late dot \(late)")

            // Qadā — lifted lapis body or its metal edge.
            let qada = silhouette(
                [GestaltDot.qadaBodyValue(for: tokens), tokens.metalValue],
                against: panel
            )
            #expect(qada >= 3.0, "\(state) qadā dot \(qada)")

            // Missed — quiet, never invisible: composited at its 0.60
            // opacity the outline keeps a presence floor.
            let missedComposited = SRGBValue.mix(
                panel, GestaltDot.missedOutlineValue(for: tokens), amount: 0.60
            )
            let missed = missedComposited.contrastRatio(against: panel)
            #expect(missed >= 1.9, "\(state) missed dot \(missed)")

            // The excused dash at 0.35 — calm but present.
            let dash = SRGBValue.mix(panel, tokens.inkSecondaryValue, amount: 0.35)
                .contrastRatio(against: panel)
            #expect(dash >= 1.3, "\(state) paused dash \(dash)")
        }
    }
}
