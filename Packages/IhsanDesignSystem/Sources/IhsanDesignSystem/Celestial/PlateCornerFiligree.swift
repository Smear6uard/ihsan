import SwiftUI

/// GATED — corner pieces (clear-day seasoning, item 5).
///
/// Fine engraved filigree in the plate's top two corners: the
/// manuscript's own margin-ornament vocabulary at very low presence.
/// Each device is two nested quarter-arc filaments sprung from the
/// corner, five radial ticks between them, and a small drawn bud on
/// the diagonal — hairline metal linework, nothing filled, nothing
/// luminous.
///
/// The maintainer keeps or cuts this in one word. The kill switch is
/// `isEnabled`; if it reads as wallpaper or competes with anything, it
/// dies without appeal, and the plate goes back to bare corners.
///
/// Static by construction: no clock, no motion, nothing for Reduce
/// Motion to switch off.
public struct PlateCornerFiligree: View {
    /// The gate. Set false to cut the corner pieces everywhere.
    public static let isEnabled = true
    /// Presence band fixed by the gate's terms: metal at 15–20%.
    public static let metalOpacity: Double = 0.18
    /// The device fits inside this square, corner-anchored. Compact.
    public static let extent: CGFloat = 48
    /// Filament weights only.
    public static let maximumLineWidth: CGFloat = 1.1

    public let tokens: SkyPaletteTokens

    public init(tokens: SkyPaletteTokens) {
        self.tokens = tokens
    }

    public var body: some View {
        Canvas { context, size in
            let color = tokens.metalValue.color.opacity(Self.metalOpacity)
            draw(into: &context, corner: CGPoint(x: 0, y: 0), sign: 1, color: color)
            draw(into: &context, corner: CGPoint(x: size.width, y: 0), sign: -1, color: color)
        }
        .frame(height: Self.extent)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// One corner device. `sign` mirrors it for the right-hand corner.
    private func draw(
        into context: inout GraphicsContext,
        corner: CGPoint,
        sign: CGFloat,
        color: Color
    ) {
        let innerRadius: CGFloat = 26
        let outerRadius: CGFloat = 36

        func point(radius: CGFloat, degrees: Double) -> CGPoint {
            let radians = degrees * .pi / 180
            return CGPoint(
                x: corner.x + sign * radius * CGFloat(cos(radians)),
                y: corner.y + radius * CGFloat(sin(radians))
            )
        }

        // Two nested quarter arcs, the outer a shade lighter in weight.
        for (radius, width) in [(innerRadius, Self.maximumLineWidth), (outerRadius, 0.8)] {
            var arc = Path()
            arc.move(to: point(radius: radius, degrees: 0))
            for step in 1...24 {
                arc.addLine(to: point(radius: radius, degrees: Double(step) * 90.0 / 24.0))
            }
            context.stroke(arc, with: .color(color), lineWidth: width)
        }

        // Five radial ticks bridging the arcs, skipping the diagonal
        // where the bud sits.
        for degrees in [15.0, 30.0, 60.0, 75.0] {
            var tick = Path()
            tick.move(to: point(radius: innerRadius + 2, degrees: degrees))
            tick.addLine(to: point(radius: outerRadius - 2, degrees: degrees))
            context.stroke(tick, with: .color(color), lineWidth: 0.8)
        }

        // The bud: a small drawn almond on the diagonal, open, unfilled.
        let budCenter = point(radius: (innerRadius + outerRadius) / 2, degrees: 45)
        let budLong: CGFloat = 5.5
        let budShort: CGFloat = 2.6
        let axis = 45.0 * .pi / 180
        let ax = CGFloat(cos(axis)) * sign
        let ay = CGFloat(sin(axis))
        var bud = Path()
        let tip1 = CGPoint(x: budCenter.x + ax * budLong, y: budCenter.y + ay * budLong)
        let tip2 = CGPoint(x: budCenter.x - ax * budLong, y: budCenter.y - ay * budLong)
        let side1 = CGPoint(x: budCenter.x - ay * budShort * sign, y: budCenter.y + ax * budShort * sign)
        let side2 = CGPoint(x: budCenter.x + ay * budShort * sign, y: budCenter.y - ax * budShort * sign)
        bud.move(to: tip1)
        bud.addQuadCurve(to: tip2, control: side1)
        bud.addQuadCurve(to: tip1, control: side2)
        context.stroke(bud, with: .color(color), lineWidth: 0.9)
    }
}
