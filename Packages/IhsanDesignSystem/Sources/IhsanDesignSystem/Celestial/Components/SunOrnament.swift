import SwiftUI

/// The sun rendered as an iridescent eight-pointed star ornament at its
/// real altitude.
///
/// Builds on the existing `EightPointedStar` Path. The fill is the
/// shared iridescent brass gradient (`IhsanIridescence.brassStroke`)
/// rotated slowly so the ornament reads as gold leaf catching light
/// rather than as a flat brass disc. A radial warm core lifts the
/// centre into solar gold and a soft halo surrounds the body so the
/// sun reads as luminous against the parchment-cream day sky.
///
/// Reduce-motion users get a static gradient (no rotation), and the
/// halo's pulse is suppressed. Visual identity is preserved.
public struct SunOrnament: View {

    /// Altitude of the sun in degrees above the horizon. Drives the
    /// ornament size — 36pt at horizon, 48pt at zenith — so the sun
    /// feels visually "smaller" near the horizon, the same atmospheric-
    /// compression cue real photographs of low suns carry.
    public let altitude: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(altitude: Double) {
        self.altitude = altitude
    }

    /// 36pt at horizon → 48pt at zenith, linear in altitude.
    private var size: CGFloat {
        let clampedAlt = max(0.0, min(90.0, altitude))
        let t = CGFloat(clampedAlt / 90.0)
        return 36.0 + t * 12.0
    }

    /// Halo radius — proportional to the body so the halo always
    /// extends ~70% past the star's outer edge.
    private var haloRadius: CGFloat { size * 1.7 }

    public var body: some View {
        ZStack {
            halo
            starBody
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Sun, currently at \(Int(altitude.rounded())) degrees above horizon"
        )
    }

    /// Soft RadialGradient halo behind the star. ~20% peak opacity in
    /// the sun's gold so it lifts the body off the page without ever
    /// reading as glare.
    private var halo: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        IhsanCelestialPalette.day.accentMoon.opacity(0.30),
                        IhsanCelestialPalette.day.accentMoon.opacity(0.10),
                        .clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: haloRadius
                )
            )
            .frame(width: haloRadius * 2, height: haloRadius * 2)
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
    }

    /// The star body itself. The fill is the iridescent brass angular
    /// gradient, rotated slowly over a 4-second cycle. Overlaid with a
    /// radial warm core (solar gold at the centre fading to brass at
    /// the edges) and rimmed by a thin brass stroke that anchors the
    /// silhouette against the parchment / indigo sky behind it.
    @ViewBuilder
    private var starBody: some View {
        if reduceMotion {
            composedStar(rotationAngle: .zero)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                let elapsed = context.date.timeIntervalSinceReferenceDate
                // 4-second full rotation: 90°/s.
                let degrees = (elapsed * 90.0).truncatingRemainder(dividingBy: 360.0)
                composedStar(rotationAngle: .degrees(degrees))
            }
        }
    }

    @ViewBuilder
    private func composedStar(rotationAngle: Angle) -> some View {
        EightPointedStar()
            .fill(IhsanIridescence.brassStroke(angle: rotationAngle))
            .overlay {
                EightPointedStar()
                    .fill(
                        RadialGradient(
                            colors: [
                                IhsanCelestialPalette.day.accentMoon,
                                IhsanCelestialPalette.day.accentMoon.opacity(0.45),
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: size * 0.45
                        )
                    )
                    .blendMode(.plusLighter)
            }
            .overlay {
                EightPointedStar()
                    .stroke(IhsanCelestialPalette.day.accent.opacity(0.70), lineWidth: 0.6)
            }
            .frame(width: size, height: size)
            .shadow(
                color: IhsanCelestialPalette.day.accentMoon.opacity(0.45),
                radius: 4,
                x: 0,
                y: 0
            )
    }
}

#Preview("Sun ornament — altitudes") {
    HStack(spacing: 32) {
        ForEach([10, 30, 60, 90], id: \.self) { alt in
            VStack {
                SunOrnament(altitude: Double(alt))
                Text("\(alt)°")
                    .font(.system(size: 10, weight: .semibold).smallCaps())
                    .tracking(1.0)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }
    .padding(40)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(
        LinearGradient(
            colors: [IhsanCelestialPalette.day.sky, IhsanCelestialPalette.day.skyDeep],
            startPoint: .top,
            endPoint: .bottom
        )
    )
}
