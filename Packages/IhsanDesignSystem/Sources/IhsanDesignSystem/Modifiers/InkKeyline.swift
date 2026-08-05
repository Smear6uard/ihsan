import SwiftUI

/// The legibility keyline for text standing on the sky.
///
/// At sunrise and maghrib the ink and the ground swap luminance
/// polarity. Both are continuous, so contrast provably passes through
/// 1:1 — no timing avoids it (see `SkyPhase.figureHalfWidth`). The
/// mitigation therefore cannot be a tuned curve; it has to change what
/// the glyph sits on.
///
/// So the glyph stops being the only mark. Through the crossing it
/// gains a hard-edged two-tone outline: a deepened keyline immediately
/// against the glyph, a light ring outside that. The rings occupy
/// DIFFERENT PIXELS, which is the whole difference from the blurred
/// double-shadow this replaces — two blurs centred on the same glyph
/// overlap and average to mid-grey exactly where separation is needed.
/// Whatever value the glyph currently holds, one band within 2 pt of it
/// is far from that value:
///
/// | glyph          | vs near ring | vs far ring |
/// |----------------|--------------|-------------|
/// | light (jewel)  | ~15:1        | merges      |
/// | mid (crossing) | ~5.2:1       | 3.8:1       |
/// | dark (day)     | ~1.36:1      | ~15:1       |
///
/// Only the near ring's own darkness makes the middle row work, and it
/// is the row the whole treatment exists for: at the crossing the ink
/// passes through the geometric mean of the two poles, the one value
/// maximally far from both at once. Against the shipped
/// `inkHaloDarkValue` that row measures 3.76:1, not 5:1 — which is why
/// the near ring is `keylineValue` deepened rather than a halo pole.
///
/// This is not a new device: it is the palette's own KEYLINE rule —
/// "the fine dark boundary of every gilded form … the dark edge is
/// what makes gold read as gold rather than tan" — applied to text for
/// the one moment it needs it. An edge, not a shadow, so the flat +
/// luminous rule holds.
///
/// Free on a plateau: at strength 0 the content passes through
/// untouched. That is **86.65%** of the cycle — not the 99% this
/// comment used to claim. Measured over 4,000 phases, the modifier is
/// ACTIVE (content duplicated, eight `radius: 0` shadows drawn) for
/// **13.35%**, the ring is at half strength or more for 8.55%, and it
/// is fully drawn for 6.95%. In wall-clock terms for Chicago on
/// 2026-08-02 that is roughly **2.7 hours a day** live, 85 minutes of
/// it fully drawn.
///
/// Worth stating plainly because the old figure was what licensed not
/// worrying about two real costs: `content` is rendered twice here, and
/// no performance test exercises this modifier at all. Those costs run
/// for hours a day, not minutes.
///
/// Reduce Motion / Reduce Transparency need no branch — nothing here
/// moves and nothing here is a gradient.
public struct InkKeyline: ViewModifier {

    /// Effective dilation per ring. Four diagonal offsets at `r` produce
    /// a lattice of translated copies reaching ~1.41 · r on each axis:
    /// 0.30 → a ~0.42 pt near keyline, 1.15 → a far ring out to
    /// ~1.63 pt. Both stay inside the 2 pt within which the legibility
    /// test looks for a contrasting band.
    ///
    /// The near ring has to stay FINE, and not merely for looks. Where
    /// the ink is dark the near ring is dark too, so it is the far light
    /// ring that does the separating — and 2 pt is measured from each
    /// stem PIXEL, not from the glyph's edge. A fat near ring pushes the
    /// far one out of reach of pixels in the middle of a stem: at 0.55
    /// the worst dark-ink phase measured 2.07:1, at 0.30 it clears.
    /// Below ~0.25 the near ring stops covering the light ring's inner
    /// edge and light ink loses its own keyline, so this is a floor as
    /// well as a ceiling.
    private static let nearOffset: CGFloat = 0.30
    private static let farOffset: CGFloat = 1.15

    let tokens: SkyPaletteTokens

    /// The near ring's luminance ceiling.
    ///
    /// At the crossing the ink passes through L ≈ 0.2138, the geometric
    /// mean of the two poles — the one value maximally far, in contrast
    /// terms, from BOTH of them at once. Clearing 4.5:1 there requires a
    /// near ring at L ≤ 0.008622. `inkHaloDarkValue` (L = 0.0201) gives
    /// only 3.76:1 and `keylineValue` (L = 0.0167) 3.96:1, so the ring
    /// is deepened past both. 0.0010 puts the ceiling at 5.17:1 — most
    /// of the way to the 5.28:1 an ideal black would give, and the
    /// margin is needed: antialiasing costs ~11%, so the composited
    /// measurement lands just over 4.5 rather than on it.
    private static let nearCeiling = 0.0010

    /// The near ring: this state's OWN keyline, deepened.
    ///
    /// Deriving it per state keeps each one's tint — a very dark indigo
    /// at dawn, a very dark plum at sunset — where a single black
    /// literal would be the only untinted neutral in the app. At these
    /// luminances the deepening is invisible as colour (sRGB ≈ 0.125 →
    /// 0.090 on a hairline); the only thing it changes is that the text
    /// gets crisp. No new hue enters the palette, so that constraint
    /// holds by construction.
    ///
    /// Derived here rather than by deepening `keylineValue` itself,
    /// because that token draws the boundary of every gilded form in the
    /// app; editing it would repaint all of them to fix text.
    /// Exposed at package level so the legibility tests can pin the
    /// arithmetic that makes the 4.5 threshold reachable at all.
    package var nearRingValue: SRGBValue {
        Self.deepened(tokens.keylineValue, to: Self.nearCeiling)
    }

    /// Scale a value down to `target` luminance with its hue intact.
    /// Relative luminance is linear in the linearised components, so
    /// scaling all three by the same factor scales luminance by exactly
    /// that factor and leaves their ratios — the hue — untouched.
    private static func deepened(_ value: SRGBValue, to target: Double) -> SRGBValue {
        let current = value.relativeLuminance
        guard current > target, current > 0 else { return value }
        let scale = target / current
        func linear(_ c: Double) -> Double {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        func encode(_ c: Double) -> Double {
            c <= 0.00304 ? c * 12.92 : 1.055 * pow(c, 1 / 2.4) - 0.055
        }
        return SRGBValue(
            red: encode(linear(value.red) * scale),
            green: encode(linear(value.green) * scale),
            blue: encode(linear(value.blue) * scale)
        )
    }

    public func body(content: Content) -> some View {
        let strength = tokens.inkOutlineStrength
        if strength <= 0.001 {
            content
        } else {
            // TWO INDEPENDENTLY DILATED COPIES, the wide light ring
            // behind the narrow dark one. This cannot be expressed by
            // chaining both poles onto a single copy: each `.shadow`
            // dilates the ACCUMULATED rendering, including any ring
            // already drawn, and paints over it — so the pole applied
            // last wins every pixel and the result is a single-tone
            // ring, whichever order you use. (Measured on a test bar:
            // chaining dark-then-light is pixel-identical to drawing the
            // light pole alone.) Stacking separate copies is what
            // actually puts the poles in DIFFERENT PIXELS, which is the
            // entire mechanism.
            //
            // `.background`, NOT a `ZStack` of two siblings. Both put
            // the far copy behind the near one with identical geometry,
            // but this keeps the NEAR copy the layout-defining view, so
            // its alignment guides — `.firstTextBaseline` above all —
            // reach the caller by documented semantics rather than by
            // luck. It matters because the branch is gated on
            // `strength`: a layout difference here would appear and
            // vanish abruptly at engage and disengage, three times per
            // crossing, on any row aligning keylined text against
            // anything else.
            //
            // Honest footnote: a `ZStack` was measured to pass
            // `keylinedTextKeepsItsBaselineInAnAlignedRow` as well, so
            // this is defence-in-depth rather than a bug that was
            // observed. Still prefer it — and that test will catch any
            // composition here that is not layout-neutral, whichever
            // container it uses.
            Self.dilate(
                content,
                color: nearRingValue.color.opacity(strength),
                offset: Self.nearOffset
            )
            .background {
                Self.dilate(
                    content,
                    color: tokens.inkHaloLightValue.color.opacity(strength),
                    offset: Self.farOffset
                )
                // The far copy is scaffolding for the ring only — the
                // near copy carries the readable glyph. Without this the
                // content's accessibility element appears twice at any
                // call site that does not establish its own container.
                .accessibilityHidden(true)
            }
        }
    }

    /// A hard-edged dilation: four diagonal `radius: 0` shadows. Radius
    /// zero means no blur, which is the entire point — a blur is what
    /// fogged the glyph before.
    private static func dilate(
        _ view: some View, color: Color, offset r: CGFloat
    ) -> some View {
        let d = r * 0.7071
        return view
            .shadow(color: color, radius: 0, x: d, y: d)
            .shadow(color: color, radius: 0, x: -d, y: d)
            .shadow(color: color, radius: 0, x: d, y: -d)
            .shadow(color: color, radius: 0, x: -d, y: -d)
    }
}

public extension View {
    /// Keep this text legible through the sunrise and maghrib
    /// crossings. No-op on every palette plateau. Apply to any text
    /// that stands on the sky or the ground — never to text on a
    /// panel, which has its own fill.
    ///
    /// Fading the text? Put `.opacity(…)` OUTSIDE this modifier, not on
    /// the `foregroundStyle`. Through a crossing the content is drawn
    /// twice — once per ring — so a translucent foreground composites
    /// with itself (0.72 becomes 0.92) and, worse, the near ring of the
    /// upper copy washes near-black through the lower copy's glyph.
    /// Outside, the glyph and both rings fade together as one mark,
    /// which is what "fading the text" should mean anyway.
    func inkKeyline(_ tokens: SkyPaletteTokens) -> some View {
        modifier(InkKeyline(tokens: tokens))
    }
}
