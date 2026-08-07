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

    /// Transition legibility contract: atmosphere can interpolate, but
    /// the complete figure palette chooses one readable pole. Both ink
    /// roles clear AA against their caption backing. Any remaining raw
    /// sky dip must engage that backing; the outline stays gone.
    @Test
    func adaptiveFigurePaletteUsesBackingWithoutAnOutline() {
        let steps = 4_000
        for step in 0..<steps {
            let phase = SkyPhase(unit: Double(step) / Double(steps))
            let tokens = PaletteState.resolved(for: phase)
            let surfaces = [
                tokens.skyZenithValue,
                tokens.groundTopValue,
                tokens.groundBottomValue,
                tokens.groundPlaneValue,
                tokens.panelFillValue,
            ]
            let worst = [tokens.inkValue, tokens.inkSecondaryValue]
                .flatMap { ink in surfaces.map { ink.contrastRatio(against: $0) } }
                .min() ?? 0
            if worst < 4.5 {
                #expect(
                    tokens.inkHaloStrength > 0.05,
                    "ink at \(worst):1 without a caption backing at phase \(phase.unit)"
                )
            }
            #expect(tokens.inkOutlineStrength == 0)
        }
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
    @Test(arguments: [PaletteState.firstLight, PaletteState.morning, PaletteState.afternoon])
    func daytimeGroundsAreLuminousNotBeige(state: PaletteState) {
        for ground in [state.tokens.groundTopValue, state.tokens.groundBottomValue] {
            let lab = ground.oklab
            #expect(lab.l >= 0.93, "\(state.rawValue) ground too dim to read as luminous")
            #expect(lab.b <= 0.02, "\(state.rawValue) ground drifted yellow (OKLab b = \(lab.b)) — reads beige")
        }
    }

    /// Jewel grounds must actually be jewel — chromatic, not gray, and
    /// deep, with the night ground never approaching pure black.
    /// Dawn must be its own page, not night with a warm horizon.
    ///
    /// Before corrective I, dawn sat 1.30× night on `groundTop` and
    /// 1.38× on `groundPlane` — inside the noise. At 5:00 AM the plate
    /// read as late night. Night is near-black indigo and sunset is
    /// plum-vermillion; dawn is lapis-violet, and has to be measurably
    /// distinct from BOTH.
    @Test
    func dawnSeparatesFromNight() {
        let night = PaletteState.night.tokens
        let dawn = PaletteState.dawn.tokens
        let pairs: [(String, SRGBValue, SRGBValue, Double)] = [
            ("skyZenith", night.skyZenithValue, dawn.skyZenithValue, 2.0),
            ("groundTop", night.groundTopValue, dawn.groundTopValue, 2.2),
            ("groundBottom", night.groundBottomValue, dawn.groundBottomValue, 3.0),
            ("groundPlane", night.groundPlaneValue, dawn.groundPlaneValue, 1.8),
            ("horizonWash", night.horizonWashValue, dawn.horizonWashValue, 3.0)
        ]
        for (name, nightValue, dawnValue, factor) in pairs {
            let ratio = dawnValue.relativeLuminance / max(nightValue.relativeLuminance, 1e-6)
            #expect(
                ratio >= factor,
                Comment(rawValue: "dawn.\(name) is only \(String(format: "%.2f", ratio))× night's — "
                    + "needs at least \(factor)× to read as its own state")
            )
        }
    }

    /// And dawn must be more chromatic than night, so the separation
    /// is a change of colour and not just of brightness.
    @Test
    func dawnIsMoreChromaticThanNight() {
        func chroma(_ value: SRGBValue) -> Double {
            let lab = value.oklab
            return (lab.a * lab.a + lab.b * lab.b).squareRoot()
        }
        #expect(
            chroma(PaletteState.dawn.tokens.groundBottomValue)
                > chroma(PaletteState.night.tokens.groundBottomValue),
            "dawn's ground is no more chromatic than night's"
        )
    }

    @Test(arguments: [PaletteState.night, PaletteState.dawn, PaletteState.sunset])
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
