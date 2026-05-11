import SwiftUI

/// The horizon line — a thin brass rule with a warm glow above and a
/// rose-gold cool glow below, visible only when the sun is near the
/// horizon (the Fajr-to-sunrise and Maghrib-to-Isha transition
/// windows).
///
/// Vertically composed:
///
/// - **Top 120pt:** warm glow fading from transparent at the top to
///   `horizonGlow` `#E8945C` at the rule.
/// - **1pt rule:** brass at 60% opacity, ends feathered to transparent
///   so the rule reads as a thread laid on the page rather than a
///   hard UI line.
/// - **Bottom 80pt:** rose-gold glow fading from `horizonRose`
///   `#C77B5C` at the rule to transparent at the bottom.
///
/// The whole band blends `.plusLighter` so it lifts the sky's colour
/// at the horizon rather than overwriting it — at maghrib the warm
/// glow stacks onto the vermillion already in the sky gradient,
/// giving a chromatically real sunset effect without needing per-time
/// keyframes.
///
/// The horizon's y-position is at altitude 0 in the celestial scene's
/// mapping. The sun and moon ornaments cross this line naturally as
/// they rise and set.
public struct HorizonLine: View {

    /// Total opacity of the band. The scene fades this in / out as the
    /// sun enters and leaves the transition window so the line doesn't
    /// pop into existence at a hard threshold.
    public let opacity: Double

    /// Pixels of warm glow above the rule.
    public static let aboveGlowHeight: CGFloat = 120

    /// Pixels of rose-gold glow below the rule.
    public static let belowGlowHeight: CGFloat = 80

    /// The whole horizon band's vertical extent.
    public static let totalHeight: CGFloat = aboveGlowHeight + 1 + belowGlowHeight

    public init(opacity: Double = 1.0) {
        self.opacity = opacity
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Warm glow above the horizon. Linear gradient fades from
            // transparent at the top to the peak glow colour right at
            // the rule.
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

            // The brass rule itself — 1pt, ~60% opacity at the centre,
            // feathered ends so it dissolves into the page rather than
            // terminating in hard endpoints.
            LinearGradient(
                colors: [
                    .clear,
                    IhsanCelestialPalette.day.accent.opacity(0.45),
                    IhsanCelestialPalette.day.accent.opacity(0.60),
                    IhsanCelestialPalette.day.accent.opacity(0.45),
                    .clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 1)

            // Rose-gold glow below the horizon — peaks at the rule,
            // fades downward into the indigo / vermillion sky below.
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
        }
        .opacity(opacity)
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Convenience: opacity from sun altitude

public extension HorizonLine {
    /// Compute the horizon band's opacity from the sun's current
    /// altitude. The line is fully present when the sun is within
    /// ±5° of the horizon; it fades to transparent over a ±10°
    /// envelope so the appearance / disappearance is never an
    /// instantaneous pop.
    ///
    /// During the Fajr-to-sunrise window the sun sweeps from ~-15°
    /// up to 0°, so this returns increasing opacity through that
    /// window. During Maghrib-to-Isha it sweeps from ~0° down to
    /// -15°, so the opacity decreases through that window. Outside
    /// the ±10° envelope the line is fully transparent (the scene
    /// drops the view entirely).
    static func opacity(forSunAltitude altitude: Double) -> Double {
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
        VStack {
            Spacer()
            HorizonLine(opacity: 1.0)
            Spacer()
        }
    }
}
