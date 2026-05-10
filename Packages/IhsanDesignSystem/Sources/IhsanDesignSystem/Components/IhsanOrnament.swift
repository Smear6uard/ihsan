import SwiftUI

// MARK: - Star ornaments
//
// All manuscript ornamental marks are drawn natively in SwiftUI Path so
// the design never depends on raster assets. The two shapes here are the
// only ornamental forms used across the Today screen: a four-pointed
// star (for prayer dots, divider flourishes, and corner ornaments) and
// an eight-pointed star (for the current-time marker on the prayer arc).
//
// Both shapes render inside `rect` with their center at `rect.midX,
// rect.midY` and their outer radius at `min(rect.width, rect.height) /
// 2`. Callers control size by sizing the host frame.

/// A four-pointed star — a stretched lozenge with concave inner points.
/// The classical "rub el hizb" / Islamic divider mark. Used everywhere a
/// small ornamental marker is needed: prayer dots on the arc, divider
/// flourishes between sections, corner ornaments on hero panels.
///
/// The `innerRatio` controls how slender the star is. The default `0.32`
/// gives a clean diamond with crisp points at every iPhone scale.
public struct FourPointedStar: Shape {
    public var innerRatio: CGFloat

    public init(innerRatio: CGFloat = 0.32) {
        self.innerRatio = innerRatio
    }

    public func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2.0
        let innerRadius = outerRadius * innerRatio

        // 8 points: alternating outer (cardinal) and inner (diagonal).
        // Outer points at -90°, 0°, 90°, 180° (top, right, bottom, left).
        // Inner points at -45°, 45°, 135°, 225° (corners).
        var points: [CGPoint] = []
        for i in 0..<8 {
            let isOuter = i % 2 == 0
            let radius = isOuter ? outerRadius : innerRadius
            // Start at -90° (top), step 45° per index.
            let angle = (-90.0 + Double(i) * 45.0) * .pi / 180.0
            points.append(CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius,
                y: center.y + CGFloat(sin(angle)) * radius
            ))
        }

        var path = Path()
        path.move(to: points[0])
        for p in points.dropFirst() {
            path.addLine(to: p)
        }
        path.closeSubpath()
        return path
    }
}

/// An eight-pointed star — the classical Islamic "khatim" / Star of
/// Lakshmi, formed by overlaying two squares at 45°. Used for the
/// current-time marker on the prayer arc and other "this is happening
/// right now" highlights.
///
/// The `innerRatio` default `0.52` gives the recognizable rounded-petal
/// outline; tighter values (0.4) produce sharper spikes that read as
/// "compass" rather than "manuscript ornament".
public struct EightPointedStar: Shape {
    public var innerRatio: CGFloat

    public init(innerRatio: CGFloat = 0.52) {
        self.innerRatio = innerRatio
    }

    public func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2.0
        let innerRadius = outerRadius * innerRatio

        // 16 points: alternating outer (8 cardinal + ordinal) and inner
        // (8 between-cardinals). Step 22.5° per index, starting at -90°
        // (top).
        var points: [CGPoint] = []
        for i in 0..<16 {
            let isOuter = i % 2 == 0
            let radius = isOuter ? outerRadius : innerRadius
            let angle = (-90.0 + Double(i) * 22.5) * .pi / 180.0
            points.append(CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius,
                y: center.y + CGFloat(sin(angle)) * radius
            ))
        }

        var path = Path()
        path.move(to: points[0])
        for p in points.dropFirst() {
            path.addLine(to: p)
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Composed ornamental elements

/// A small four-pointed star ornament rendered in brass. Used as the
/// flourish at the centre of dividers and at the corners of hero panels.
///
/// The `tint` defaults to `IhsanColor.brass` but callers can override —
/// e.g. the active prayer's inner ornament might use gold.
public struct OrnamentalFlourish: View {
    public let size: CGFloat
    public let tint: Color
    public let opacity: Double

    public init(
        size: CGFloat = 8,
        tint: Color = IhsanColor.brass,
        opacity: Double = 0.70
    ) {
        self.size = size
        self.tint = tint
        self.opacity = opacity
    }

    public var body: some View {
        FourPointedStar()
            .fill(tint.opacity(opacity))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// A horizontal divider rule with an ornamental four-pointed star
/// centered on the line. Used inside the hero countdown card (separating
/// the prayer name from the countdown) and beneath the page header.
///
/// The rule is a feathered gradient (transparent → brass → transparent)
/// so it reads as a thread laid on the page rather than a hard UI rule.
public struct OrnamentalDivider: View {
    public let tint: Color
    public let opacity: Double
    public let starSize: CGFloat
    public let ruleWidth: CGFloat?

    public init(
        tint: Color = IhsanColor.brass,
        opacity: Double = 0.40,
        starSize: CGFloat = 8,
        ruleWidth: CGFloat? = nil
    ) {
        self.tint = tint
        self.opacity = opacity
        self.starSize = starSize
        self.ruleWidth = ruleWidth
    }

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    .clear,
                    tint.opacity(opacity * 0.7),
                    tint.opacity(opacity),
                    tint.opacity(opacity * 0.7),
                    .clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: IhsanSpacing.hairline)

            FourPointedStar()
                .fill(tint.opacity(min(1.0, opacity * 1.6)))
                .frame(width: starSize, height: starSize)
                // The star punches a small clear band on the rule so the
                // shape reads cleanly even when the rule passes behind it.
                .background {
                    Capsule()
                        .fill(IhsanColor.panelDay.opacity(0.001))
                }
        }
        .frame(maxWidth: ruleWidth)
        .accessibilityHidden(true)
    }
}

// MARK: - Preview

#Preview("Ornaments") {
    VStack(spacing: IhsanSpacing.xl) {
        HStack(spacing: IhsanSpacing.xl) {
            FourPointedStar()
                .fill(IhsanColor.brass)
                .frame(width: 24, height: 24)
            FourPointedStar()
                .stroke(IhsanColor.brass, lineWidth: 1)
                .frame(width: 24, height: 24)
            EightPointedStar()
                .fill(IhsanColor.gold)
                .frame(width: 28, height: 28)
            EightPointedStar()
                .stroke(IhsanColor.brass, lineWidth: 1)
                .frame(width: 28, height: 28)
        }

        OrnamentalDivider()
            .frame(maxWidth: 220)

        OrnamentalFlourish(size: 6, tint: IhsanColor.brass, opacity: 0.60)
    }
    .padding()
    .background(IhsanColor.panelDay)
}
