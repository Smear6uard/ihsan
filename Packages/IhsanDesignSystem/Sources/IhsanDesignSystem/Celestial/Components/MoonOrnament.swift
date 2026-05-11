import SwiftUI

/// The moon rendered at its real position with its real current phase.
///
/// The lit area is drawn natively in SwiftUI via a `CrescentShape` so
/// the orientation and width respect the actual illuminated fraction
/// continuously — the eight-bucket SF Symbol mapping was too coarse for
/// a flagship-quality moon. The lit area is filled in bone cream
/// (`nightAccentMoon`); the dark portion stays transparent so the sky
/// behind reads through as the moon's shadow.
///
/// A soft halo sits behind the lit area, and at full moon a subtle
/// pulse modulates the halo opacity over a 3-second cycle. Reduce-
/// motion users get the static halo.
public struct MoonOrnament: View {

    /// The lunar position carrying altitude, illuminated fraction, and
    /// waxing / waning direction.
    public let position: LunarPosition

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(position: LunarPosition) {
        self.position = position
    }

    /// 40pt at horizon → 56pt at zenith, linear in altitude.
    private var size: CGFloat {
        let clampedAlt = max(0.0, min(90.0, position.altitude))
        let t = CGFloat(clampedAlt / 90.0)
        return 40.0 + t * 16.0
    }

    /// Halo radius — proportional to the body.
    private var haloRadius: CGFloat { size * 1.6 }

    /// Spec: "On full moon, slight pulsing glow."
    /// `0.95` and above counts as visually full.
    private var isFull: Bool { position.illuminatedFraction >= 0.95 }

    public var body: some View {
        ZStack {
            halo
            crescentBody
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Moon, \(phaseLabel)")
    }

    /// Soft warm halo. At full moon, slowly pulse the opacity to give
    /// the moon a quiet "breathing" presence; for any other phase the
    /// halo is static.
    @ViewBuilder
    private var halo: some View {
        if isFull && !reduceMotion {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                let elapsed = context.date.timeIntervalSinceReferenceDate
                // 3-second cycle, ±15% opacity around the base 0.18.
                let phase = elapsed * (2 * .pi / 3.0)
                let pulse = 0.18 + 0.05 * sin(phase)
                staticHalo(maxOpacity: pulse)
            }
        } else {
            staticHalo(maxOpacity: 0.18)
        }
    }

    private func staticHalo(maxOpacity: Double) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        IhsanCelestialPalette.night.accent.opacity(maxOpacity),
                        IhsanCelestialPalette.night.accent.opacity(maxOpacity * 0.3),
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

    /// The lit area of the moon. Drawn natively via `CrescentShape` so
    /// the phase rendering is continuous across the synodic month.
    @ViewBuilder
    private var crescentBody: some View {
        CrescentShape(
            illuminatedFraction: position.illuminatedFraction,
            isWaxing: position.isWaxing
        )
        .fill(IhsanCelestialPalette.night.accentMoon)
        .frame(width: size, height: size)
        .shadow(
            color: IhsanCelestialPalette.night.accent.opacity(0.35),
            radius: 2,
            x: 0,
            y: 0
        )
    }

    private var phaseLabel: String {
        let f = position.illuminatedFraction
        if f < 0.05 {
            return "new moon"
        } else if f < 0.30 {
            return position.isWaxing ? "waxing crescent" : "waning crescent"
        } else if f < 0.55 {
            return position.isWaxing ? "first quarter" : "last quarter"
        } else if f < 0.95 {
            return position.isWaxing ? "waxing gibbous" : "waning gibbous"
        } else {
            return "full moon"
        }
    }
}

/// The lit portion of the lunar disc for a given illuminated fraction.
///
/// The terminator (boundary between lit and shadow on the moon's
/// surface) projects to a semi-ellipse on the disc when viewed from
/// Earth. The lit area is bounded by:
///
/// - The half of the disc's limb on the lit side (right for waxing,
///   left for waning), and
/// - The terminator semi-ellipse, whose semi-x axis is
///   `R · |2f − 1|` and whose semi-y axis is `R`.
///
/// For crescent phases (`f < 0.5`) the terminator pokes INTO the lit
/// half-disc, carving out a thin sliver. For gibbous phases (`f > 0.5`)
/// the terminator pokes INTO the dark half-disc, leaving most of the
/// moon lit. The Bezier control offsets `kappa · semi` use the
/// canonical magic number 0.5522847 so the ellipse approximation is
/// indistinguishable from a true ellipse at any size we render.
struct CrescentShape: Shape {
    let illuminatedFraction: Double
    let isWaxing: Bool

    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width, rect.height) / 2.0
        let center = CGPoint(x: rect.midX, y: rect.midY)

        var path = Path()

        let f = max(0.0, min(1.0, illuminatedFraction))

        // Edge cases.
        if f <= 0.001 {
            return path
        }
        if f >= 0.999 {
            path.addEllipse(in: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            ))
            return path
        }

        // Terminator semi-minor axis.
        //
        // The terminator (boundary between lit and shadow on the moon)
        // projects to a semi-ellipse on the disc. Its equator-point
        // x-coordinate is `R · (1 − 2f)`, taken on the lit side of
        // the disc:
        //
        // - New moon (`f = 0`): terminator at `+R` (the right limb itself)
        //   — nothing lit on the right of it.
        // - Waxing crescent (`f < 0.5`): terminator at positive x; the
        //   curve bulges INTO the lit half-disc, carving a thin sliver.
        // - First quarter (`f = 0.5`): terminator at `0`; the right
        //   half-disc is lit cleanly.
        // - Waxing gibbous (`f > 0.5`): terminator at negative x; the
        //   curve bulges INTO the dark half-disc, extending the lit area
        //   past the meridian.
        //
        // The waxing / waning flag mirrors the x-sign so the lit side
        // sits on the left during the second half of the synodic month.
        let terminatorSemiX = radius * CGFloat(1.0 - 2.0 * f)

        // SwiftUI uses y-down: top of moon is at center.y - radius,
        // bottom is at center.y + radius. Limb arc on the lit side
        // goes from top to bottom around the appropriate hemisphere.
        let topPoint = CGPoint(x: center.x, y: center.y - radius)
        let bottomPoint = CGPoint(x: center.x, y: center.y + radius)

        path.move(to: topPoint)

        // Arc along the limb on the LIT side.
        if isWaxing {
            // Waxing: lit on right. Arc from top (-π/2) to bottom (+π/2)
            // going clockwise in standard math coords (through positive x).
            // In SwiftUI's y-down coords, this is "clockwise = false".
            path.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(-90),
                endAngle: .degrees(90),
                clockwise: false
            )
        } else {
            // Waning: lit on left. Arc from top through negative x.
            path.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(-90),
                endAngle: .degrees(90),
                clockwise: true
            )
        }

        // We're now at bottomPoint. Close the lit area by drawing the
        // terminator semi-ellipse from bottom back up to top.
        //
        // For waxing: the terminator's "near" point at the equator is
        // at `terminatorSemiX` on the x-axis (positive for gibbous,
        // negative for crescent). The lit-area sweep is the right half
        // of an ellipse with semi-x = |terminatorSemiX|, semi-y = R.
        //
        // For waning: mirror in x.
        let kappa: CGFloat = 0.5522847498307936
        let signedSemiX: CGFloat = isWaxing ? terminatorSemiX : -terminatorSemiX
        let dx = signedSemiX * kappa
        let dy = radius * kappa

        // Two cubic Bezier curves from bottom → equator → top, both
        // arcing through (center.x + signedSemiX, center.y).
        let equatorPoint = CGPoint(
            x: center.x + signedSemiX,
            y: center.y
        )

        // Bottom to equator.
        path.addCurve(
            to: equatorPoint,
            control1: CGPoint(x: bottomPoint.x + dx, y: bottomPoint.y),
            control2: CGPoint(x: equatorPoint.x, y: equatorPoint.y + dy)
        )
        // Equator to top.
        path.addCurve(
            to: topPoint,
            control1: CGPoint(x: equatorPoint.x, y: equatorPoint.y - dy),
            control2: CGPoint(x: topPoint.x + dx, y: topPoint.y)
        )

        path.closeSubpath()
        return path
    }
}

#Preview("Moon ornament — phase sweep") {
    HStack(spacing: 16) {
        ForEach(0..<8) { i in
            let f = Double(i) / 8.0
            let waxing = i < 4
            let moonF: Double = waxing ? f * 2 : (1.0 - (f - 0.5) * 2)
            let pos = LunarPosition(
                altitude: 60,
                azimuth: 180,
                hourAngle: 0,
                illuminatedFraction: moonF,
                isWaxing: waxing
            )
            VStack {
                MoonOrnament(position: pos)
                Text("\(Int(moonF * 100))%")
                    .font(.system(size: 9, weight: .semibold).smallCaps())
                    .tracking(1.0)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }
    .padding(32)
    .background(
        LinearGradient(
            colors: [IhsanCelestialPalette.night.skyDeep, IhsanCelestialPalette.night.sky],
            startPoint: .top,
            endPoint: .bottom
        )
    )
}
