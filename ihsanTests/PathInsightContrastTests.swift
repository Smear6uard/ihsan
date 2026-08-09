import CoreGraphics
import IhsanDesignSystem
import Testing
@testable import ihsan

/// The readout card's call to action.
///
/// The card is deliberately the one place on the Path with a filled
/// button, and it sits on clear glass rather than a panel — so both the
/// label and the capsule's own edge have to survive every phase of the
/// day, not just the two that were open in the simulator.
@Suite("Path readout contrast")
struct PathInsightContrastTests {

    @Test("The action label holds on its capsule in every phase", arguments: PaletteState.allCases)
    func actionLabelHolds(state: PaletteState) {
        let tokens = state.tokens
        let ratio = tokens.inkValue.contrastRatio(against: tokens.panelFillValue)
        #expect(
            ratio >= 7.0,
            Comment(rawValue: "\(state.rawValue) action label is \(ratio):1 on the capsule")
        )
    }

    /// The capsule is filled with the panel colour while the card
    /// behind it is clear glass, so its edge is what says "button"
    /// rather than "paragraph". It has to be resolvable against the
    /// fill it encloses — which a fixed metal stroke is not: it falls
    /// to 2.84:1 by afternoon, and that was the shape this control
    /// nearly shipped in.
    @Test("The capsule edge is resolvable in every phase", arguments: PaletteState.allCases)
    func capsuleEdgeResolves(state: PaletteState) {
        let tokens = state.tokens
        let ratio = TrajectoryInsightCard
            .actionEdgeValue(for: tokens)
            .contrastRatio(against: tokens.panelFillValue)
        #expect(
            ratio >= 3.0,
            Comment(rawValue: "\(state.rawValue) capsule edge is \(ratio):1 against its fill")
        )
    }

    /// And the phase-aware choice must actually be picking the better
    /// of the two, not settling on one and calling it adaptive.
    @Test("The edge always takes the stronger candidate", arguments: PaletteState.allCases)
    func capsuleEdgePicksTheStrongerToken(state: PaletteState) {
        let tokens = state.tokens
        let panel = tokens.panelFillValue
        let chosen = TrajectoryInsightCard.actionEdgeValue(for: tokens).contrastRatio(against: panel)
        let best = max(
            tokens.metalValue.contrastRatio(against: panel),
            tokens.keylineValue.contrastRatio(against: panel)
        )
        #expect(chosen == best, "\(state.rawValue) edge is not the stronger of metal and keyline")
    }

    /// The supporting line under the finding is secondary ink, and the
    /// finding itself is full ink. Both are read at body size on the
    /// same ground, so both are held to the page's own targets.
    @Test("Finding and supporting line both read", arguments: PaletteState.allCases)
    func cardTextReads(state: PaletteState) {
        let tokens = state.tokens
        let panel = tokens.panelFillValue
        #expect(tokens.inkValue.contrastRatio(against: panel) >= 7.0)
        #expect(tokens.inkSecondaryValue.contrastRatio(against: panel) >= 4.5)
    }
}
