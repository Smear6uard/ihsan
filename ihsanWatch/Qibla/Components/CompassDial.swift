import SwiftUI
import IhsanCore
import IhsanDesignSystem

/// Watch-tuned compass dial. Smaller diameter than iOS, with
/// simplified ticks (no degree numerals) so the Kaaba indicator
/// stays the focal point at glance distance.
///
/// `currentHeading` is the device's smoothed true heading in degrees.
/// `qiblaBearing` is the bearing from the user's location to the
/// Kaaba. The dial rotates by `-currentHeading` (so North stays
/// North) and the Kaaba indicator sits at `qiblaBearing` on that
/// rotated frame, which mathematically lands the indicator at
/// `(qiblaBearing - currentHeading)` in screen coordinates — i.e.,
/// pointing wherever Kaaba actually is relative to where you're
/// facing.
struct CompassDial: View {
    let qiblaBearing: Double
    let currentHeading: Double
    let isAligned: Bool

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let radius = size / 2
            let kaabaAngle = qiblaBearing - currentHeading

            ZStack {
                outerRing(radius: radius)
                cardinalTicks(radius: radius)
                cardinalLabels(radius: radius, dialRotation: -currentHeading)
                kaabaPointer(radius: radius, angle: kaabaAngle)
                centerDot
                if isAligned {
                    alignmentGlow(radius: radius)
                }
            }
            .frame(width: size, height: size)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .accessibilityElement()
        .accessibilityLabel("Qibla compass")
        .accessibilityValue(accessibilityValueText)
    }

    // MARK: - Layers

    private func outerRing(radius: CGFloat) -> some View {
        Circle()
            .strokeBorder(IhsanColor.atmospheric.opacity(0.6), lineWidth: 1.5)
            .frame(width: radius * 2, height: radius * 2)
    }

    /// 8 ticks: 4 cardinal + 4 ordinal, only the cardinal ones get
    /// the long stroke. Watch space is too small for 12 or 16 ticks.
    private func cardinalTicks(radius: CGFloat) -> some View {
        ZStack {
            ForEach(0..<8) { i in
                let angle = Double(i) * 45 - currentHeading
                let isCardinal = i % 2 == 0
                Rectangle()
                    .fill(IhsanColor.textMuted.opacity(isCardinal ? 0.85 : 0.35))
                    .frame(
                        width: isCardinal ? 1.5 : 1,
                        height: isCardinal ? 8 : 4
                    )
                    .offset(y: -(radius - 6))
                    .rotationEffect(.degrees(angle))
            }
        }
    }

    private func cardinalLabels(radius: CGFloat, dialRotation: Double) -> some View {
        ZStack {
            cardinalLabel("N", angle: 0, radius: radius, dialRotation: dialRotation)
            cardinalLabel("E", angle: 90, radius: radius, dialRotation: dialRotation)
            cardinalLabel("S", angle: 180, radius: radius, dialRotation: dialRotation)
            cardinalLabel("W", angle: 270, radius: radius, dialRotation: dialRotation)
        }
    }

    private func cardinalLabel(
        _ label: String,
        angle: Double,
        radius: CGFloat,
        dialRotation: Double
    ) -> some View {
        let placementAngle = angle + dialRotation
        let radians = placementAngle * .pi / 180
        let inset: CGFloat = 18
        let r = radius - inset
        return Text(label)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(
                label == "N"
                    ? IhsanColor.textPrimary
                    : IhsanColor.textMuted
            )
            .offset(x: CGFloat(sin(radians)) * r, y: -CGFloat(cos(radians)) * r)
    }

    private func kaabaPointer(radius: CGFloat, angle: Double) -> some View {
        let pointerLength = radius * 0.55
        return ZStack {
            // Soft halo behind the indicator — picks up adaptive tint
            // so the dial reads the time of day.
            Circle()
                .fill(IhsanColor.adaptiveTint().opacity(isAligned ? 0.45 : 0.18))
                .frame(width: 18, height: 18)
                .offset(y: -pointerLength)
                .blur(radius: 6)

            KaabaTriangle()
                .fill(IhsanColor.statusQada)
                .frame(width: 14, height: 16)
                .offset(y: -pointerLength)
        }
        .rotationEffect(.degrees(angle))
        .animation(reduceMotion ? nil : .interpolatingSpring(stiffness: 80, damping: 12),
                   value: angle)
    }

    private func alignmentGlow(radius: CGFloat) -> some View {
        Circle()
            .stroke(IhsanColor.statusQada.opacity(0.6), lineWidth: 2)
            .frame(width: radius * 2, height: radius * 2)
            .shadow(color: IhsanColor.statusQada.opacity(0.6), radius: 8)
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.25), value: isAligned)
    }

    private var centerDot: some View {
        Circle()
            .fill(IhsanColor.textPrimary.opacity(0.7))
            .frame(width: 4, height: 4)
    }

    private var accessibilityValueText: String {
        let bearingInt = Int(qiblaBearing.rounded())
        return isAligned
            ? "Aligned with qibla, bearing \(bearingInt) degrees"
            : "Bearing \(bearingInt) degrees from north"
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
}

private struct KaabaTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.3))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
