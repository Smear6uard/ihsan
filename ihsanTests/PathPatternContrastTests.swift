import CoreGraphics
import Testing
import IhsanCore
import IhsanDesignSystem
@testable import ihsan

/// The audit `GestaltDot`'s doc comment has always claimed —
/// "static treatment functions expose the exact values so
/// PathPatternContrastTests audits what the dots render" — and which
/// did not exist until corrective I. In its absence the two overlay
/// rows shipped invisible: on the morning panel a "present" dhikr mark
/// composited to 1.52:1 while an EMPTY fardh cell composited to
/// 1.30:1, so "something happened here" and "nothing did" were 0.22
/// apart and both below the threshold of resolution.
struct PathPatternContrastTests {

    /// Composite a mark drawn at `opacity` over the panel it stands on.
    private func composite(
        _ mark: SRGBValue, over panel: SRGBValue, opacity: Double
    ) -> SRGBValue {
        SRGBValue.mix(panel, mark, amount: opacity)
    }

    /// Every mark that means SOMETHING HAPPENED must be resolvable
    /// against the panel it stands on.
    @Test(arguments: PaletteState.allCases)
    func overlayPresenceMarksAreVisible(state: PaletteState) {
        let tokens = state.tokens
        let mark = composite(
            GestaltGrid.overlayMarkValue(for: tokens),
            over: tokens.panelFillValue,
            opacity: GestaltGrid.overlayMarkOpacity
        )
        let ratio = mark.contrastRatio(against: tokens.panelFillValue)
        #expect(
            ratio >= 3.0,
            Comment(rawValue: "\(state.rawValue) overlay presence mark is \(ratio):1 "
                + "against the panel — below the threshold of resolution")
        )
    }

    /// And it must be clearly separated from the mark that means
    /// NOTHING HAPPENED, or the row says nothing at all.
    @Test(arguments: PaletteState.allCases)
    func presenceIsDistinctFromAbsence(state: PaletteState) {
        let tokens = state.tokens
        let present = composite(
            GestaltGrid.overlayMarkValue(for: tokens),
            over: tokens.panelFillValue,
            opacity: GestaltGrid.overlayMarkOpacity
        )
        let unlogged = composite(
            tokens.metalValue, over: tokens.panelFillValue, opacity: 0.28
        )
        #expect(
            present.contrastRatio(against: unlogged) >= 1.8,
            Comment(rawValue: "\(state.rawValue): a present overlay mark and an unlogged "
                + "fardh cell are \(present.contrastRatio(against: unlogged)):1 apart")
        )
    }

    /// The fardh treatments the grid has always drawn, audited for the
    /// first time. Late, missed, and qadā each mean something specific
    /// and each must be resolvable.
    ///
    /// The outlined treatments carry their own value. The GILDED ones
    /// — on-time and qadā — are a body inside an edge, and which of
    /// the two separates depends on the panel's polarity, exactly as
    /// `InkKeyline`'s two-tone ring does: on a jewel panel the light
    /// gilded body carries it and the dark keyline merges; on a
    /// near-white day panel the body is gold-on-white at ~2.4:1 and
    /// the dark edge is what makes it read as gold rather than tan.
    /// So a gilded mark is resolvable when EITHER pole separates.
    @Test(arguments: PaletteState.allCases)
    func fardhTreatmentsAreResolvable(state: PaletteState) {
        let tokens = state.tokens
        let panel = tokens.panelFillValue

        // Single-value treatments: the stroke is the whole mark.
        let outlines: [(String, SRGBValue, Double)] = [
            ("late", GestaltDot.lateOutlineValue(for: tokens), 0.95),
            ("missed", GestaltDot.missedOutlineValue(for: tokens), 0.60)
        ]
        for (name, value, opacity) in outlines {
            let ratio = composite(value, over: panel, opacity: opacity)
                .contrastRatio(against: panel)
            #expect(
                ratio >= 3.0,
                Comment(rawValue: "\(state.rawValue) \(name) dot is \(ratio):1 against the panel")
            )
        }

        // Two-pole treatments: body or edge, whichever does the work.
        let gilded: [(String, SRGBValue, SRGBValue)] = [
            ("onTime", tokens.leafGoldValue, composite(tokens.keylineValue, over: panel, opacity: 0.90)),
            ("qada", GestaltDot.qadaBodyValue(for: tokens), composite(tokens.metalValue, over: panel, opacity: 0.90))
        ]
        for (name, body, edge) in gilded {
            let bodyRatio = body.contrastRatio(against: panel)
            let edgeRatio = edge.contrastRatio(against: panel)
            #expect(
                max(bodyRatio, edgeRatio) >= 3.0,
                Comment(rawValue: "\(state.rawValue) \(name) dot separates at neither pole — "
                    + "body \(bodyRatio):1, edge \(edgeRatio):1 against the panel")
            )
        }
    }

    /// Below `GestaltDot.keylineFloor` the dot drops its keyline — at
    /// 3 pt a 0.5 pt stroke has no line to draw — so on the 90-day
    /// view the BODY has to carry the separation by itself. That is
    /// where the gilded marks were genuinely invisible: bare
    /// `leafGold` at ~2.4:1 on the day panels, lifted lapis at ~2.5:1
    /// on sunset's.
    @Test(arguments: PaletteState.allCases)
    func gildedBodiesResolveWhereTheKeylineCannotBeDrawn(state: PaletteState) {
        let tokens = state.tokens
        let panel = tokens.panelFillValue
        let small = GestaltDot.keylineFloor - 1
        let cases: [(String, SRGBValue)] = [
            ("onTime", GestaltDot.onTimeBodyValue(for: tokens, size: small)),
            ("qada", GestaltDot.qadaBodyValue(for: tokens, size: small))
        ]
        for (name, value) in cases {
            let ratio = value.contrastRatio(against: panel)
            #expect(
                ratio >= 3.0,
                Comment(rawValue: "\(state.rawValue) \(name) body is \(ratio):1 against the "
                    + "panel at \(small) pt, where no keyline is drawn")
            )
        }
    }
}
