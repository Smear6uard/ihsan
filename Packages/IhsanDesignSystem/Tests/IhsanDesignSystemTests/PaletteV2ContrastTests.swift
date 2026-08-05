import Foundation
import Testing
@testable import IhsanDesignSystem

/// Palette v2 contrast contract: every (text, ground) token pair in
/// every canonical state clears WCAG AA (≥ 4.5:1); body ink targets
/// 7:1 and any pair under that is flagged as a warning in the test
/// log without failing the suite.
struct PaletteV2ContrastTests {

    private struct Pair {
        let textName: String
        let text: SRGBValue
        let groundName: String
        let ground: SRGBValue
        let isBodyText: Bool
    }

    private func textPairs(for tokens: SkyPaletteTokens) -> [Pair] {
        let grounds: [(String, SRGBValue)] = [
            ("groundTop", tokens.groundTopValue),
            ("groundBottom", tokens.groundBottomValue),
            ("panelFill", tokens.panelFillValue)
        ]
        var pairs: [Pair] = []
        for (groundName, ground) in grounds {
            pairs.append(Pair(
                textName: "ink", text: tokens.inkValue,
                groundName: groundName, ground: ground, isBodyText: true
            ))
            pairs.append(Pair(
                textName: "inkSecondary", text: tokens.inkSecondaryValue,
                groundName: groundName, ground: ground, isBodyText: false
            ))
        }
        // Status tokens render as text on panels and directly on the
        // ground (log sheet, focused card inscriptions).
        for (groundName, ground) in grounds where groundName != "groundTop" {
            pairs.append(Pair(
                textName: "positive", text: tokens.positiveValue,
                groundName: groundName, ground: ground, isBodyText: false
            ))
            pairs.append(Pair(
                textName: "attention", text: tokens.attentionValue,
                groundName: groundName, ground: ground, isBodyText: false
            ))
        }
        return pairs
    }

    @Test(arguments: PaletteState.allCases)
    func allTextOnGroundPairsMeetAA(state: PaletteState) {
        for pair in textPairs(for: state.tokens) {
            let ratio = pair.text.contrastRatio(against: pair.ground)
            #expect(
                ratio >= 4.5,
                "\(state.rawValue) \(pair.textName) on \(pair.groundName) is \(ratio), below WCAG AA 4.5:1"
            )
            if pair.isBodyText && ratio < 7.0 {
                print(
                    "⚠️ CONTRAST WARNING: \(state.rawValue) body pair "
                    + "\(pair.textName) on \(pair.groundName) is "
                    + "\(String(format: "%.2f", ratio)):1 — under the 7:1 body-text target"
                )
            }
        }
    }

    /// Transition legibility contract. At sunrise and maghrib the ink
    /// and the ground swap luminance polarity, so any continuous
    /// crossfade provably passes them through equal luminance — AA
    /// cannot hold at every instant of a smooth transition. The
    /// structural mitigation is `inkHalo`: whenever ink contrast dips,
    /// the opposite-pole halo must be active. This test pins all three
    /// sides of that deal:
    ///
    /// 1. wherever the halo is off, ink meets AA against every ground;
    /// 2. the sub-AA passage is confined to narrow slivers of the
    ///    cycle (< 6% total);
    /// 3. wherever contrast is genuinely low, the halo is strong.
    @Test
    func inkDipsOnlyUnderActiveHaloAndBriefly() {
        let steps = 4_000
        var subAASteps = 0
        for step in 0..<steps {
            let phase = SkyPhase(unit: Double(step) / Double(steps))
            let tokens = PaletteState.resolved(for: phase)
            let worst = [tokens.groundTopValue, tokens.groundBottomValue, tokens.panelFillValue]
                .map { tokens.inkValue.contrastRatio(against: $0) }
                .min() ?? 0

            if worst < 4.5 {
                subAASteps += 1
                #expect(
                    tokens.inkHaloStrength > 0.05,
                    "ink at \(worst):1 with no halo at phase \(phase.unit)"
                )
            }
            if worst < 3.0 {
                #expect(
                    tokens.inkHaloStrength >= 0.5,
                    "ink at \(worst):1 with weak halo (\(tokens.inkHaloStrength)) at phase \(phase.unit)"
                )
            }
        }
        let subAAFraction = Double(subAASteps) / Double(steps)
        #expect(subAAFraction < 0.06, "sub-AA passage covers \(subAAFraction) of the cycle")
    }

    /// The keyline must be FULLY drawn wherever the palette alone leaves
    /// text under 3:1.
    ///
    /// The test above pins the halo; this pins the outline that replaced
    /// it, and it is the rule the strength curve is tuned against rather
    /// than a number someone liked. Partial strength is not good enough
    /// at these phases: the rings are drawn at `inkOutlineStrength`
    /// opacity, so a half-strength ring is a half-transparent ring that
    /// composites toward the very ground it is meant to separate the
    /// glyph from. Below 3:1 the ground has stopped doing any of the
    /// work, so the ring has to do all of it.
    ///
    /// `>= 0.99` rather than `== 1` because the curve reaches full
    /// strength asymptotically through a `min`, and float equality on a
    /// `sin` is not a contract worth writing.
    ///
    /// The grounds are the two SKY grounds only, deliberately —
    /// `panelFill` is not a trigger here even though the sibling test
    /// above includes it. Text on a panel never receives the keyline
    /// (the sky-vs-panel rule; it is why 26 `.shadow` sites in
    /// `ihsan/Repair/**` were left alone), so raising the multiplier
    /// cannot help one pixel of it and a failure naming a panel pair
    /// would send the reader after a fix that does not exist. Worse, it
    /// could make this test structurally unsatisfiable: the remedy is
    /// gated on `inkHaloStrength`, which is identically zero on every
    /// plateau and keyed to `groundBottomValue`'s polarity, whereas
    /// `panelFill` blends on the figure band — the two share no
    /// structural relationship, so a panel dip on a plateau could not be
    /// answered by any multiplier. Ground pairs at least move with the
    /// quantity that gates the remedy.
    ///
    /// Panel text under 3:1 is a real gap — 23 phases of the cycle show
    /// it — but it needs its own contract naming its own remedy, and it
    /// is recorded in `POLISH_FINDINGS.md` rather than smuggled in here.
    @Test
    func theOutlineIsFullyDrawnWhereverContrastCollapses() {
        let steps = 4_000
        var worstStrengthWhereNeeded = 1.0
        var haloThere = 1.0
        var worstUnit = 0.0
        var worstRatio = 0.0

        for step in 0..<steps {
            let phase = SkyPhase(unit: Double(step) / Double(steps))
            let tokens = PaletteState.resolved(for: phase)
            let grounds = [tokens.groundTopValue, tokens.groundBottomValue]
            let inks = [tokens.inkValue, tokens.inkSecondaryValue]
            let worst = inks
                .flatMap { ink in grounds.map { ink.contrastRatio(against: $0) } }
                .min() ?? 0

            guard worst < 3.0 else { continue }
            if tokens.inkOutlineStrength < worstStrengthWhereNeeded {
                worstStrengthWhereNeeded = tokens.inkOutlineStrength
                haloThere = tokens.inkHaloStrength
                worstUnit = phase.unit
                worstRatio = worst
            }
        }

        // A dip where the halo is identically zero cannot be answered by
        // any multiplier — `inkOutlineStrength` is `min(1, halo × k)`.
        // Say so, rather than printing a `required` of ~4.9e307 and
        // sending the reader to tune a constant that cannot help.
        if worstStrengthWhereNeeded < 0.99 && haloThere == 0 {
            Issue.record("""
                an ink/ground pair sits at \(worstRatio):1 at phase \(worstUnit), \
                where inkHaloStrength is 0 — no multiplier in \
                SkyPhase.inkOutlineStrength can raise the outline there. \
                The palette itself has to change, or this pair needs a \
                different remedy.
                """)
            return
        }

        // Derived from the raw halo strength, so the message stays true
        // whatever the multiplier currently is.
        let required = 0.99 / max(haloThere, .leastNonzeroMagnitude)
        #expect(
            worstStrengthWhereNeeded >= 0.99,
            """
            an ink/ground pair sits at \(worstRatio):1 at phase \(worstUnit) \
            while the outline is only \(worstStrengthWhereNeeded) drawn — \
            the multiplier in SkyPhase.inkOutlineStrength must be at least \(required)
            """
        )
    }

    /// The parchment overlay is capped at 8% in every state — parchment
    /// exists only as texture, never as a surface.
    @Test(arguments: PaletteState.allCases)
    func panelTextureStaysUnderCap(state: PaletteState) {
        #expect(state.tokens.panelTextureOpacity <= 0.08)
        #expect(state.tokens.panelTextureOpacity > 0.0)
    }

    /// No token in any state may be pure black or pure white.
    @Test(arguments: PaletteState.allCases)
    func noPureBlackOrWhiteAnywhere(state: PaletteState) {
        let t = state.tokens
        let all: [(String, SRGBValue)] = [
            ("groundTop", t.groundTopValue), ("groundBottom", t.groundBottomValue),
            ("horizonWash", t.horizonWashValue), ("ink", t.inkValue),
            ("inkSecondary", t.inkSecondaryValue), ("metal", t.metalValue),
            ("metalHighlight", t.metalHighlightValue), ("glow", t.glowValue),
            ("panelFill", t.panelFillValue), ("panelStroke", t.panelStrokeValue),
            ("panelTexture", t.panelTextureValue), ("positive", t.positiveValue),
            ("attention", t.attentionValue), ("subterranean", t.subterraneanValue),
            ("inkHalo", t.inkHaloValue)
        ]
        for (name, value) in all {
            let sum = value.red + value.green + value.blue
            #expect(sum > 0.001, "\(state.rawValue).\(name) is pure black")
            #expect(sum < 2.999, "\(state.rawValue).\(name) is pure white")
        }
    }

    /// The daytime grounds must stay COOL-or-neutral near-whites. If a
    /// ground drifts warm enough to read as beige the state has failed
    /// its brief; this pins the failure mathematically: in OKLab, the
    /// b axis (blue↔yellow) of every morning/afternoon ground stop must
    /// stay within a tight band around neutral, and lightness must stay
    /// luminous (≥ 0.93).
    @Test(arguments: [PaletteState.morning, PaletteState.afternoon])
    func daytimeGroundsAreLuminousNotBeige(state: PaletteState) {
        for ground in [state.tokens.groundTopValue, state.tokens.groundBottomValue] {
            let lab = ground.oklab
            #expect(lab.l >= 0.93, "\(state.rawValue) ground too dim to read as luminous")
            #expect(lab.b <= 0.02, "\(state.rawValue) ground drifted yellow (OKLab b = \(lab.b)) — reads beige")
        }
    }

    /// Jewel grounds must actually be jewel — chromatic, not gray, and
    /// deep, with the night ground never approaching pure black.
    @Test(arguments: [PaletteState.night, PaletteState.sunset])
    func jewelGroundsAreDeepAndChromatic(state: PaletteState) {
        for ground in [state.tokens.groundTopValue, state.tokens.groundBottomValue] {
            let lab = ground.oklab
            let chroma = (lab.a * lab.a + lab.b * lab.b).squareRoot()
            #expect(lab.l < 0.5, "\(state.rawValue) ground not deep enough")
            #expect(lab.l > 0.10, "\(state.rawValue) ground close to pure black")
            #expect(chroma > 0.02, "\(state.rawValue) ground reads gray, not jewel")
        }
    }
}
