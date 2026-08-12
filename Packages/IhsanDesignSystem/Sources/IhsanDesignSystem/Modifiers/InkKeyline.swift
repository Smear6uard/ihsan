import SwiftUI

/// Compatibility modifier for text that stands on the celestial field.
///
/// Earlier builds drew eight hard shadow copies around every glyph near
/// sunrise and sunset. It kept a mathematically smooth colour crossfade
/// readable, but made the entire interface look outlined for hours.
/// `PaletteState.resolved(for:)` now chooses the stronger figure pole;
/// during the small remainder where a moving sky spans both luminance
/// families, text rests on a quiet panel-coloured backing. It reads like
/// a contemporary caption plate, never a stroke around each letter.
public struct InkKeyline: ViewModifier {
    let tokens: SkyPaletteTokens

    static func backingOpacity(for tokens: SkyPaletteTokens) -> Double {
        min(0.72, tokens.inkHaloStrength * 3.0)
    }

    /// What the backing is painted with. Through a crossing the panel
    /// colour takes the sky's own glow — its hue and chroma, at a
    /// lightness solved so the WCAG relative luminance equals the
    /// panel's exactly. Contrast is a pure luminance measure, so every
    /// ratio the render audit checks is identical to the plain panel's
    /// by construction; the warmth is chroma the AA margin never pays
    /// for. The lean rides `inkHaloStrength`, so on every plateau the
    /// backing is bit-identical to the panel. The render gate
    /// composites THIS value over the painted sky; view and audit
    /// cannot drift apart.
    static func backingValue(for tokens: SkyPaletteTokens) -> SRGBValue {
        let strength = tokens.inkHaloStrength
        guard strength > 0 else { return tokens.panelFillValue }
        let panel = tokens.panelFillValue.oklab
        let glow = tokens.glowValue.oklab
        let amount = 0.28 * strength
        var lean = panel
        lean.a = panel.a + (glow.a - panel.a) * amount
        lean.b = panel.b + (glow.b - panel.b) * amount

        // Solve OKLab L so the lean's relative luminance matches the
        // panel's. Y is monotone in L, so a short bisection lands well
        // inside the audit's tolerance.
        let target = tokens.panelFillValue.relativeLuminance
        var low = 0.0, high = 1.0
        for _ in 0..<24 {
            lean.l = (low + high) / 2
            if lean.srgb.relativeLuminance < target {
                low = lean.l
            } else {
                high = lean.l
            }
        }
        return lean.srgb
    }

    public func body(content: Content) -> some View {
        let opacity = Self.backingOpacity(for: tokens)
        if opacity <= 0.001 {
            content
        } else {
            content
                .background {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Self.backingValue(for: tokens).color.opacity(opacity))
                        .padding(.horizontal, -2)
                        .padding(.vertical, -1)
                        .blur(radius: 5)
                }
        }
    }
}

public extension View {
    /// Uses the palette's adaptive figure ink and, only through a
    /// luminance crossing, its restrained caption backing.
    func inkKeyline(_ tokens: SkyPaletteTokens) -> some View {
        modifier(InkKeyline(tokens: tokens))
    }
}
