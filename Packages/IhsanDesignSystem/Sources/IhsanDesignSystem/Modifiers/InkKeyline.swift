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

    public func body(content: Content) -> some View {
        let opacity = Self.backingOpacity(for: tokens)
        if opacity <= 0.001 {
            content
        } else {
            content
                .background {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(tokens.panelFill.opacity(opacity))
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
