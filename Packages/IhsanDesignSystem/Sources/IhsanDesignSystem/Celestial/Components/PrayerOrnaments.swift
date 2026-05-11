import IhsanCore
import SwiftUI

// MARK: - Public renderer

/// One of the five distinct ornaments used to mark prayers in the
/// celestial scene. Each ornament is hand-drawn in SwiftUI `Path` so
/// the visual stays a manuscript-quality vector form at every scale,
/// and so each prayer reads as the celestial moment it corresponds to:
///
/// - **Fajr** — a half-sun rising above the horizon with three short
///   radiating rays above (dawn).
/// - **Dhuhr** — an eight-pointed star, the classical Islamic solar
///   emblem at the zenith.
/// - **Asr** — a six-pointed star, geometrically distinct from Dhuhr
///   so the eye reads "sun descending, less than zenith".
/// - **Maghrib** — a half-sun on the horizon with three short rays
///   going downward beneath (sunset / descent). The Fajr shape mirrored
///   in spirit, not in geometry.
/// - **Isha** — a crescent (concave-right) with a small four-pointed
///   star set in the opening (night, when the moon and stars are
///   visible). Manuscript-traditional in its proportions and execution
///   — geometric and celestial, not flag-iconographic.
///
/// Apply the same `Style` to all five so the marker layer reads in one
/// chromatic key with the page borders. Rays in `Fajr` / `Maghrib` are
/// 1-D forms; they are always stroked with `style`'s base — regardless
/// of whether the 2-D regions are stroked or filled.
public struct PrayerOrnamentView: View {
    public let prayer: Prayer
    public let size: CGFloat
    public let style: PrayerOrnamentStyle

    public init(prayer: Prayer, size: CGFloat, style: PrayerOrnamentStyle) {
        self.prayer = prayer
        self.size = size
        self.style = style
    }

    public var body: some View {
        switch prayer {
        case .fajr:    FajrOrnament(size: size, style: style)
        case .dhuhr:   DhuhrOrnament(size: size, style: style)
        case .asr:     AsrOrnament(size: size, style: style)
        case .maghrib: MaghribOrnament(size: size, style: style)
        case .isha:    IshaOrnament(size: size, style: style)
        }
    }
}

/// How a `PrayerOrnamentView` is rendered. The same style applies to
/// the ornament's 2-D regions (sun, star, crescent body) and to its
/// 1-D parts (rays) — but the 2-D regions either fill or stroke
/// according to `mode`, while the 1-D parts always stroke.
public struct PrayerOrnamentStyle: Sendable {
    public let body: AnyShapeStyle
    public let mode: Mode
    public let lineWidth: CGFloat

    public enum Mode: Sendable {
        case stroked
        case filled
    }

    public init(body: AnyShapeStyle, mode: Mode, lineWidth: CGFloat = 1.0) {
        self.body = body
        self.mode = mode
        self.lineWidth = lineWidth
    }

    /// Convenience: a solid colour stroke at the given opacity.
    public static func stroked(_ color: Color, opacity: Double, lineWidth: CGFloat = 0.8) -> Self {
        Self(body: AnyShapeStyle(color.opacity(opacity)), mode: .stroked, lineWidth: lineWidth)
    }

    /// Convenience: a solid colour fill at the given opacity.
    public static func filled(_ color: Color, opacity: Double) -> Self {
        Self(body: AnyShapeStyle(color.opacity(opacity)), mode: .filled)
    }

    /// Convenience: any `ShapeStyle` (e.g. an iridescent angular
    /// gradient) used as the fill body. The 1-D ray strokes inherit
    /// the same style.
    public static func filledShape(_ shape: some ShapeStyle) -> Self {
        Self(body: AnyShapeStyle(shape), mode: .filled)
    }
}

// MARK: - Fajr — half-sun + rising rays

private struct FajrOrnament: View {
    let size: CGFloat
    let style: PrayerOrnamentStyle

    var body: some View {
        ZStack {
            // 2-D region — the upper hemisphere of the sun.
            switch style.mode {
            case .stroked:
                HalfSunShape(orientation: .rising)
                    .stroke(style.body, lineWidth: style.lineWidth)
            case .filled:
                HalfSunShape(orientation: .rising)
                    .fill(style.body)
            }

            // 1-D rays — always stroked with the same body style.
            UpwardRaysShape()
                .stroke(style.body, lineWidth: style.lineWidth)
        }
        .frame(width: size, height: size * 12 / 14)
    }
}

// MARK: - Dhuhr — eight-pointed Star of Lakshmi at the zenith

private struct DhuhrOrnament: View {
    let size: CGFloat
    let style: PrayerOrnamentStyle

    var body: some View {
        Group {
            switch style.mode {
            case .stroked:
                EightPointedStar()
                    .stroke(style.body, lineWidth: style.lineWidth)
            case .filled:
                EightPointedStar()
                    .fill(style.body)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Asr — six-pointed star (sun descending past its zenith)

private struct AsrOrnament: View {
    let size: CGFloat
    let style: PrayerOrnamentStyle

    var body: some View {
        Group {
            switch style.mode {
            case .stroked:
                SixPointedStar()
                    .stroke(style.body, lineWidth: style.lineWidth)
            case .filled:
                SixPointedStar()
                    .fill(style.body)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Maghrib — half-sun + descending rays (mirror of Fajr in spirit)

private struct MaghribOrnament: View {
    let size: CGFloat
    let style: PrayerOrnamentStyle

    var body: some View {
        ZStack {
            switch style.mode {
            case .stroked:
                HalfSunShape(orientation: .setting)
                    .stroke(style.body, lineWidth: style.lineWidth)
            case .filled:
                HalfSunShape(orientation: .setting)
                    .fill(style.body)
            }

            DownwardRaysShape()
                .stroke(style.body, lineWidth: style.lineWidth)
        }
        .frame(width: size, height: size * 12 / 14)
    }
}

// MARK: - Isha — crescent + star in the opening

private struct IshaOrnament: View {
    let size: CGFloat
    let style: PrayerOrnamentStyle

    var body: some View {
        ZStack {
            switch style.mode {
            case .stroked:
                OpenCrescentShape()
                    .stroke(style.body, lineWidth: style.lineWidth)
                FourPointedStar()
                    .stroke(style.body, lineWidth: max(style.lineWidth * 0.7, 0.5))
                    .frame(width: size * 0.28, height: size * 0.28)
                    .offset(x: size * 0.22, y: 0)
            case .filled:
                OpenCrescentShape()
                    .fill(style.body)
                FourPointedStar()
                    .fill(style.body)
                    .frame(width: size * 0.28, height: size * 0.28)
                    .offset(x: size * 0.22, y: 0)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Six-pointed star (hexagram outline)

/// A six-pointed star — two overlapping triangles drawn as one
/// 12-point polygon outline (alternating outer and inner radii). Used
/// by `Asr` to read as "sun past the zenith, less brilliant than Dhuhr".
public struct SixPointedStar: Shape {
    public var innerRatio: CGFloat

    public init(innerRatio: CGFloat = 0.50) {
        self.innerRatio = innerRatio
    }

    public func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * innerRatio

        // 12 points alternating outer (6 cardinal star points) and
        // inner (6 troughs between points). Step 30° per index.
        var points: [CGPoint] = []
        for i in 0..<12 {
            let isOuter = i % 2 == 0
            let radius = isOuter ? outerRadius : innerRadius
            let angle = (-90.0 + Double(i) * 30.0) * .pi / 180.0
            points.append(CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius,
                y: center.y + CGFloat(sin(angle)) * radius
            ))
        }

        var path = Path()
        path.move(to: points[0])
        for p in points.dropFirst() { path.addLine(to: p) }
        path.closeSubpath()
        return path
    }
}

// MARK: - Half-sun (upper hemisphere) shape

/// The upper hemisphere of a circle — the half-sun shape used by
/// `Fajr` and `Maghrib`. Renders centred horizontally with the curve
/// at the top and the diameter line at the bottom. The orientation
/// only changes the vertical anchoring so the ray companion shapes
/// sit at the right baseline.
public struct HalfSunShape: Shape {
    public enum Orientation: Sendable {
        /// Rising — sun anchored in the lower portion of the frame
        /// so rays have room above. Used by Fajr.
        case rising
        /// Setting — sun anchored in the upper portion of the frame
        /// so rays have room below. Used by Maghrib.
        case setting
    }

    public let orientation: Orientation

    public init(orientation: Orientation) {
        self.orientation = orientation
    }

    public func path(in rect: CGRect) -> Path {
        let center: CGPoint
        switch orientation {
        case .rising:
            center = CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.30)
        case .setting:
            center = CGPoint(x: rect.midX, y: rect.height * 0.40)
        }
        let radius = rect.width * 0.28

        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .zero,
            clockwise: false
        )
        // Close with a straight line back along the diameter so the
        // 'D' outline is complete — the diameter line is visible when
        // the shape is stroked, and bounds the fill region for the
        // filled state.
        path.closeSubpath()
        return path
    }
}

// MARK: - Rays

/// Three short rays emerging upward from the top of a half-sun.
/// Anchored to the same centre as `HalfSunShape(.rising)`.
public struct UpwardRaysShape: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.30)
        let sunRadius = rect.width * 0.28
        let rayLength = rect.height * 0.40
        let rayGap: CGFloat = 1.5  // small gap between sun and ray base

        // Three rays at -28°, 0°, +28° from straight up (270°).
        let angles: [Double] = [-28, 0, 28]
        for offset in angles {
            let angle = (-90.0 + offset) * .pi / 180.0
            let startX = center.x + CGFloat(cos(angle)) * (sunRadius + rayGap)
            let startY = center.y + CGFloat(sin(angle)) * (sunRadius + rayGap)
            let endX = center.x + CGFloat(cos(angle)) * (sunRadius + rayGap + rayLength)
            let endY = center.y + CGFloat(sin(angle)) * (sunRadius + rayGap + rayLength)
            path.move(to: CGPoint(x: startX, y: startY))
            path.addLine(to: CGPoint(x: endX, y: endY))
        }
        return path
    }
}

/// Three short vertical rays going downward from beneath a setting
/// half-sun. Anchored beneath `HalfSunShape(.setting)`.
public struct DownwardRaysShape: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let sunCenterY = rect.height * 0.40
        let sunRadius = rect.width * 0.28
        let startY = sunCenterY + 2  // just beneath the diameter line
        let rayLength = rect.height * 0.40
        let endY = startY + rayLength

        // Three vertical rays slightly fanned out, suggesting the sun
        // setting and casting its last light downward.
        let xOffsets: [CGFloat] = [-sunRadius * 0.55, 0, sunRadius * 0.55]
        for x in xOffsets {
            let startX = rect.midX + x
            let endX = rect.midX + x * 1.15  // slight outward splay
            path.move(to: CGPoint(x: startX, y: startY))
            path.addLine(to: CGPoint(x: endX, y: endY))
        }
        return path
    }
}

// MARK: - Crescent

/// A concave-right crescent — a moon circle with a shadow circle
/// subtracted from the right side, creating an opening toward the
/// right where the companion star sits.
public struct OpenCrescentShape: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) * 0.40
        let shadowOffset = r * 0.45

        let moon = Path(ellipseIn: CGRect(
            x: center.x - r,
            y: center.y - r,
            width: r * 2,
            height: r * 2
        ))
        let shadow = Path(ellipseIn: CGRect(
            x: center.x - r + shadowOffset,
            y: center.y - r,
            width: r * 2,
            height: r * 2
        ))
        return moon.subtracting(shadow)
    }
}

// MARK: - Preview

#Preview("Prayer ornaments — all five, all states") {
    let brass = IhsanColor.brass
    let stroked = PrayerOrnamentStyle.stroked(brass, opacity: 0.70, lineWidth: 1.0)
    let filled = PrayerOrnamentStyle.filled(brass, opacity: 0.85)

    return VStack(spacing: 32) {
        VStack(spacing: 4) {
            Text("OUTLINED (future)")
                .font(.system(size: 10, weight: .semibold).smallCaps())
                .tracking(1.0)
                .foregroundStyle(brass.opacity(0.70))
            HStack(spacing: 24) {
                ForEach(Prayer.allCases, id: \.self) { prayer in
                    VStack(spacing: 4) {
                        PrayerOrnamentView(prayer: prayer, size: 18, style: stroked)
                        Text(prayer.displayNameEnglish.uppercased())
                            .font(.system(size: 8, weight: .semibold).smallCaps())
                            .tracking(0.8)
                            .foregroundStyle(brass.opacity(0.50))
                    }
                }
            }
        }
        VStack(spacing: 4) {
            Text("FILLED (past)")
                .font(.system(size: 10, weight: .semibold).smallCaps())
                .tracking(1.0)
                .foregroundStyle(brass.opacity(0.70))
            HStack(spacing: 24) {
                ForEach(Prayer.allCases, id: \.self) { prayer in
                    PrayerOrnamentView(prayer: prayer, size: 18, style: filled)
                }
            }
        }
        VStack(spacing: 4) {
            Text("CURRENT (24pt, iridescent)")
                .font(.system(size: 10, weight: .semibold).smallCaps())
                .tracking(1.0)
                .foregroundStyle(brass.opacity(0.70))
            HStack(spacing: 36) {
                ForEach(Prayer.allCases, id: \.self) { prayer in
                    PrayerOrnamentView(
                        prayer: prayer,
                        size: 24,
                        style: .filledShape(IhsanIridescence.brassStroke())
                    )
                }
            }
        }
    }
    .padding(40)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(IhsanColor.panelDay)
}
