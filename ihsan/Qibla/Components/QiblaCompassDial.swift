import SwiftUI
import IhsanDesignSystem

/// The hero element. A circular glass dial whose tick ring counter-rotates
/// with the device heading so N always points to true north — the iOS
/// Compass-app convention. The Kaaba indicator rides the same rotation,
/// offset to its fixed bearing relative to N. The center "you" pin never
/// moves; it represents the user's standing position.
struct QiblaCompassDial: View {
    /// Bearing from the user's location to the Kaaba, 0–360. Fixed for a
    /// given location.
    let qiblaBearing: Double
    /// Smoothed device heading from true north, 0–360.
    let currentHeading: Double
    /// True when |currentHeading - qiblaBearing| ≤ 3°. Drives the Kaaba glow.
    let isAligned: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let dialDiameter: CGFloat = 280

    var body: some View {
        ZStack {
            dialBackground
            tickRing
            cardinalLabels
            kaabaOnDial
            centerPin
        }
        .frame(width: dialDiameter, height: dialDiameter)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Compass dial. Qibla bearing \(Int(qiblaBearing.rounded())) degrees from true north."
        )
        .accessibilityValue(isAligned ? "Aligned with qibla" : "Rotate device to align with qibla")
    }

    // MARK: - Layers

    private var dialBackground: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay {
                    Circle()
                        .strokeBorder(IhsanColor.atmospheric, lineWidth: 0.5)
                }
            // Inner ring — quiet instrument detail, not competing with ticks.
            Circle()
                .strokeBorder(IhsanColor.atmospheric.opacity(0.6), lineWidth: 0.5)
                .padding(IhsanSpacing.lg)
        }
        .frame(width: dialDiameter, height: dialDiameter)
    }

    private var tickRing: some View {
        ZStack {
            ForEach(0..<24) { i in
                tick(at: i)
            }
        }
    }

    @ViewBuilder
    private func tick(at index: Int) -> some View {
        let angle = Double(index) * 15
        let isCardinal = index % 6 == 0
        let isInter = index % 3 == 0

        Capsule()
            .fill(IhsanColor.textMuted.opacity(isCardinal ? 0.95 : isInter ? 0.55 : 0.28))
            .frame(
                width: isCardinal ? 2 : 1,
                height: isCardinal ? 14 : isInter ? 10 : 6
            )
            .offset(y: -dialDiameter / 2 + (isCardinal ? 16 : 14))
            .rotationEffect(.degrees(angle - currentHeading))
    }

    private var cardinalLabels: some View {
        ZStack {
            cardinalLabel("N", angle: 0, primary: true)
            cardinalLabel("E", angle: 90)
            cardinalLabel("S", angle: 180)
            cardinalLabel("W", angle: 270)
        }
    }

    private func cardinalLabel(_ text: String, angle: Double, primary: Bool = false) -> some View {
        Text(text)
            .font(IhsanFont.smallCaps)
            .tracking(1.5)
            .foregroundStyle(
                primary ? IhsanColor.textPrimary : IhsanColor.textMuted.opacity(0.7)
            )
            .offset(y: -dialDiameter / 2 + 36)
            .rotationEffect(.degrees(angle - currentHeading))
    }

    private var kaabaOnDial: some View {
        KaabaIndicator(alignmentGlow: isAligned ? 1 : 0)
            .offset(y: -dialDiameter / 2 + 38)
            .rotationEffect(.degrees(qiblaBearing - currentHeading))
            .animation(
                // Standard UI spring — alignment feedback comes from the
                // brass halo + scale lift on KaabaIndicator, not from
                // bounce in the rotation itself.
                reduceMotion
                    ? nil
                    : .spring(response: 0.4, dampingFraction: 0.85),
                value: isAligned
            )
    }

    private var centerPin: some View {
        ZStack {
            // Soft halo — layered translucent ring, not a blur, so it stays
            // crisp on the device.
            Circle()
                .fill(IhsanColor.textPrimary.opacity(0.12))
                .frame(width: 22, height: 22)
            Circle()
                .fill(IhsanColor.textPrimary.opacity(0.22))
                .frame(width: 14, height: 14)
            Circle()
                .fill(IhsanColor.textPrimary)
                .frame(width: 6, height: 6)
        }
        .accessibilityHidden(true)
    }
}

#Preview("Dial — facing north") {
    QiblaCompassDial(qiblaBearing: 47, currentHeading: 0, isAligned: false)
        .padding(IhsanSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ihsanBackground()
}

#Preview("Dial — aligned") {
    QiblaCompassDial(qiblaBearing: 47, currentHeading: 47, isAligned: true)
        .padding(IhsanSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ihsanBackground()
}
