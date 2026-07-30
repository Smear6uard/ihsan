import IhsanDesignSystem
import SwiftUI

// The instrument's three marks: the gilded qibla lancet riding the
// ring, the fixed index filament, and the Khatam hub. Kept together —
// they are one composition and share the ring's coordinate grammar
// (all lengths in fractions of the ring radius).

// MARK: - The qibla lancet

/// The one gold element on the instrument: a tapered lancet seated in
/// the tick band at the qibla bearing, its point reaching inward past
/// the inner hairline — toward the index it will meet. Gilded in the
/// manuscript treatment (solid leaf bounded by the ultramarine
/// keyline) and carrying a faint standing glow even at rest, so it is
/// visually senior to everything else on the ring.
struct QiblaLancetMark: View {
    let tokens: SkyPaletteTokens
    let ringRadius: CGFloat
    /// Glow strength `0...1` — Phase 3's approach choreography ramps
    /// this; at rest it stands faint but present.
    var glowStrength: Double = 0.22

    private var length: CGFloat { ringRadius * 0.175 }
    private var width: CGFloat { ringRadius * 0.062 }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            warmGlow.opacity(0.55 * glowStrength),
                            warmGlow.opacity(0.18 * glowStrength),
                            warmGlow.opacity(0),
                        ],
                        center: .center,
                        startRadius: width * 0.4,
                        endRadius: length * 1.6
                    )
                )
                .frame(width: length * 3.2, height: length * 3.2)

            LancetShape()
                .fill(tokens.leafGold)
                .overlay {
                    LancetShape()
                        .stroke(tokens.keyline, lineWidth: 0.75)
                }
                .frame(width: width, height: length)
        }
        .offset(y: -(ringRadius - length / 2))
        .accessibilityHidden(true)
    }

    /// The plate's warm, metal-toned glow convention — never neutral.
    private var warmGlow: Color {
        SRGBValue.mix(tokens.glowValue, tokens.metalValue, amount: 0.45).color
    }
}

/// Elongated kite: crown seated at the rim, shoulders in the band,
/// long point reaching inward.
struct LancetShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.30))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.30))
        path.closeSubpath()
        return path
    }
}

// MARK: - The fixed index

/// The direction the user faces: a fine tapered filament rising from
/// the hub to the inner band. It never rotates — the world turns
/// around it. `warmth` (Phase 3) blends it from engraved metal toward
/// the lancet's gold as the two forms close.
struct QiblaIndexMark: View {
    let tokens: SkyPaletteTokens
    let ringRadius: CGFloat
    /// `0...1` — 0 is engraved metal at rest, 1 is fused gold.
    var warmth: Double = 0

    var body: some View {
        TaperedFilamentShape()
            .fill(indexColor)
            .frame(width: 2.4, height: ringRadius * (0.84 - 0.15))
            .offset(y: -ringRadius * (0.15 + (0.84 - 0.15) / 2))
            .accessibilityHidden(true)
    }

    private var indexColor: Color {
        SRGBValue.mix(
            tokens.metalHighlightValue,
            tokens.leafGoldValue,
            amount: warmth
        ).color.opacity(0.78 + 0.22 * warmth)
    }
}

/// A continuous tapered filament — wide at the base, fine at the tip.
/// (Arcs and lines in this design system are tapered metal, never
/// dashed.)
struct TaperedFilamentShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tipHalf: CGFloat = 0.25
        let baseHalf: CGFloat = rect.width / 2
        path.move(to: CGPoint(x: rect.midX - tipHalf, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX + tipHalf, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX + baseHalf, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX - baseHalf, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - The hub

/// The eight-pointed Khatam at center — small, engraved, holding the
/// composition the way the rosette holds the plate.
struct QiblaHubMark: View {
    let tokens: SkyPaletteTokens
    let ringRadius: CGFloat

    var body: some View {
        ZStack {
            EightPointedStar()
                .stroke(tokens.metal.opacity(0.65), lineWidth: 0.9)
                .frame(width: ringRadius * 0.17, height: ringRadius * 0.17)
            Circle()
                .fill(tokens.metal.opacity(0.8))
                .frame(width: 2.5, height: 2.5)
        }
        .accessibilityHidden(true)
    }
}
