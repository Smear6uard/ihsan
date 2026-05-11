import SwiftUI

/// The horizon line — a thin brass rule with optional warm and rose-
/// gold glow bands above and below.
///
/// The rule itself is **always visible** as a permanent visual element
/// of the celestial scene, regardless of time of day. It divides the
/// scene into an above-horizon sky region (where the sun, moon, and
/// above-horizon prayer markers render) and a below-horizon
/// subterranean region (where below-horizon prayer markers render with
/// muted treatment).
///
/// The warm / rose-gold glow bands are gated by the `glowOpacity`
/// parameter. The scene fades them in only during the Fajr-to-sunrise
/// and Maghrib-to-Isha transition windows — when the sun is within
/// ±10° of the horizon — so dawn and dusk get their chromatic warmth
/// without the rest of the day reading the line as a hot band.
///
/// Vertically composed:
///
/// - **Top 120pt:** warm glow fading from transparent at the top to
///   `horizonGlow` `#E8945C` at the rule. Visible only when the sun is
///   near the horizon (`glowOpacity > 0`).
/// - **1pt rule:** brass at ~50% opacity, ends feathered to transparent
///   so the rule reads as a thread laid on the page rather than a
///   hard UI line. Always visible.
/// - **Bottom 80pt:** rose-gold glow fading from `horizonRose`
///   `#C77B5C` at the rule to transparent at the bottom. Same gating
///   as the warm band above.
///
/// The glow bands blend `.plusLighter` so at maghrib they lift the
/// sky's existing vermillion / indigo at the horizon rather than
/// overwriting it. The brass rule blends normally so its line work
/// stays crisp regardless of sky luminance.
public struct HorizonLine: View {

    /// Opacity of the warm / rose-gold glow bands above and below the
    /// rule. `0.0` hides the glow entirely (the rule still renders);
    /// `1.0` shows the glow at peak intensity. The scene drives this
    /// from sun altitude via `glowOpacity(forSunAltitude:)`.
    public let glowOpacity: Double

    /// Pixels of warm glow above the rule.
    public static let aboveGlowHeight: CGFloat = 120

    /// Pixels of rose-gold glow below the rule.
    public static let belowGlowHeight: CGFloat = 80

    /// The whole horizon band's vertical extent (rule + both glows).
    public static let totalHeight: CGFloat = aboveGlowHeight + 1 + belowGlowHeight

    public init(glowOpacity: Double = 1.0) {
        self.glowOpacity = glowOpacity
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Warm glow above the horizon. Gated by `glowOpacity` so
            // it fades in only during the transition windows.
            LinearGradient(
                colors: [
                    .clear,
                    IhsanCelestialPalette.horizonGlow.opacity(0.10),
                    IhsanCelestialPalette.horizonGlow.opacity(0.25)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: Self.aboveGlowHeight)
            .opacity(glowOpacity)
            .blendMode(.plusLighter)

            // The brass rule itself — always visible. 1pt, peaks at
            // 50% opacity at the centre, feathered ends so it
            // dissolves into the page rather than terminating in hard
            // endpoints.
            LinearGradient(
                colors: [
                    .clear,
                    IhsanCelestialPalette.day.accent.opacity(0.35),
                    IhsanCelestialPalette.day.accent.opacity(0.50),
                    IhsanCelestialPalette.day.accent.opacity(0.35),
                    .clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 1)

            // Rose-gold glow below the horizon — also gated by
            // `glowOpacity`.
            LinearGradient(
                colors: [
                    IhsanCelestialPalette.horizonRose.opacity(0.20),
                    IhsanCelestialPalette.horizonRose.opacity(0.08),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: Self.belowGlowHeight)
            .opacity(glowOpacity)
            .blendMode(.plusLighter)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Convenience: glow opacity from sun altitude

public extension HorizonLine {
    /// Compute the glow-band opacity from the sun's current altitude.
    /// The glow is fully present when the sun is within ±5° of the
    /// horizon; it fades to transparent over a ±10° envelope so the
    /// dawn / dusk warmth never reads as a hard band toggle.
    ///
    /// During the Fajr-to-sunrise window the sun sweeps from ~-15°
    /// up to 0°, so this returns increasing values through that
    /// window. During Maghrib-to-Isha it sweeps from ~0° down to
    /// -15°, so the opacity decreases through that window. Outside
    /// the ±10° envelope the glow is fully transparent (only the
    /// brass rule remains).
    static func glowOpacity(forSunAltitude altitude: Double) -> Double {
        let plateauHalfWidth: Double = 5.0   // ±5°: full opacity
        let envelopeHalfWidth: Double = 10.0 // ±10°: fades to zero
        let abs = Swift.abs(altitude)
        if abs <= plateauHalfWidth {
            return 1.0
        }
        if abs >= envelopeHalfWidth {
            return 0.0
        }
        let t = (abs - plateauHalfWidth)
            / (envelopeHalfWidth - plateauHalfWidth)
        // Linear ramp out from 1.0 at plateau edge to 0.0 at envelope edge.
        return 1.0 - t
    }
}

#Preview("Horizon line — over a sky gradient") {
    ZStack {
        LinearGradient(
            colors: [
                IhsanCelestialPalette.day.sky,
                IhsanCelestialPalette.horizonGlow,
                IhsanCelestialPalette.horizonRose,
                IhsanCelestialPalette.night.sky
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        VStack(spacing: 60) {
            HorizonLine(glowOpacity: 1.0)
            HorizonLine(glowOpacity: 0.5)
            HorizonLine(glowOpacity: 0.0) // rule only
        }
    }
}
