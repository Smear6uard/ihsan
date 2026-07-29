import IhsanCore
import SwiftUI

/// How an ornament's path is constructed.
///
/// - `outline` builds the compass-and-straightedge construction —
///   interlocking triangles, rotated squares, scallop arcs — as open
///   or nested subpaths meant to be STROKED, so the drawing reads as
///   drafted geometry.
/// - `filled` builds the union silhouette (with even-odd interior
///   cutouts) meant to be FILLED.
public enum OrnamentRenderMode: Sendable, Equatable {
    case outline
    case filled
}

/// The five marker ornaments, one per prayer, all derived from the
/// same compass-and-straightedge construction language but each with a
/// distinct silhouette — the acceptance criterion this library exists
/// to meet:
///
/// - **Fajr — Warda.** Six-petal rosette: the classical compass-drawn
///   flower — six circle-arcs about a center, petals converging at
///   the heart. Open linework petals only: no rays, no medallion, no
///   enclosing circle. The simplest form; first light.
/// - **Dhuhr — Shamsa.** Twelve-lobed sun rosette with radiating
///   rays — the manuscript illuminator's "little sun," the richest
///   form, for the zenith. The one deliberate manuscript quotation
///   in the set.
/// - **Asr — Khatam.** Eight-pointed star of two rotated squares.
///   Clean, angular, late-afternoon geometry.
/// - **Maghrib — Lawzina.** A tapered vertical almond with a fine
///   interior line — the descending form.
/// - **Isha — ten-pointed star within a circle.** The finest
///   linework, for the night prayer.
///
/// Not an SF Symbol among them; every path below is explicit
/// geometry. Use `PrayerMarkerOrnament` for stateful rendering; use
/// this shape directly for silhouette tests and custom compositions.
public struct PrayerOrnamentShape: Shape {

    public let prayer: Prayer
    public var mode: OrnamentRenderMode

    public init(prayer: Prayer, mode: OrnamentRenderMode = .filled) {
        self.prayer = prayer
        self.mode = mode
    }

    public func path(in rect: CGRect) -> Path {
        switch prayer {
        case .fajr: return SixPetalRosette.path(in: rect, mode: mode)
        case .dhuhr: return Self.shamsa(in: rect, mode: mode)
        case .asr: return Self.khatam(in: rect, mode: mode)
        case .maghrib: return Self.lawzina(in: rect, mode: mode)
        case .isha: return Self.nightStar(in: rect, mode: mode)
        }
    }

    // MARK: - Shared construction helpers

    static func point(
        around center: CGPoint,
        radius: CGFloat,
        degrees: Double
    ) -> CGPoint {
        let radians = degrees * .pi / 180.0
        return CGPoint(
            x: center.x + radius * CGFloat(cos(radians)),
            y: center.y + radius * CGFloat(sin(radians))
        )
    }

    /// A closed star polygon: `count` outer points at `outerRadius`
    /// alternating with troughs at `innerRadius`, first point at
    /// `startDegrees`.
    static func starPolygon(
        center: CGPoint,
        count: Int,
        outerRadius: CGFloat,
        innerRadius: CGFloat,
        startDegrees: Double
    ) -> Path {
        var path = Path()
        let step = 360.0 / Double(count)
        for i in 0..<count {
            let outer = point(around: center, radius: outerRadius, degrees: startDegrees + Double(i) * step)
            let inner = point(
                around: center, radius: innerRadius,
                degrees: startDegrees + (Double(i) + 0.5) * step
            )
            if i == 0 { path.move(to: outer) } else { path.addLine(to: outer) }
            path.addLine(to: inner)
        }
        path.closeSubpath()
        return path
    }

    /// A closed regular polygon.
    static func regularPolygon(
        center: CGPoint,
        sides: Int,
        radius: CGFloat,
        startDegrees: Double
    ) -> Path {
        var path = Path()
        let step = 360.0 / Double(sides)
        for i in 0..<sides {
            let vertex = point(around: center, radius: radius, degrees: startDegrees + Double(i) * step)
            if i == 0 { path.move(to: vertex) } else { path.addLine(to: vertex) }
        }
        path.closeSubpath()
        return path
    }

    /// A thin closed spike (for silhouette rays): a sliver triangle
    /// pointing outward from `fromRadius` to `toRadius` at `degrees`.
    static func spike(
        center: CGPoint,
        fromRadius: CGFloat,
        toRadius: CGFloat,
        degrees: Double,
        halfWidthDegrees: Double
    ) -> Path {
        var path = Path()
        path.move(to: point(around: center, radius: fromRadius, degrees: degrees - halfWidthDegrees))
        path.addLine(to: point(around: center, radius: toRadius, degrees: degrees))
        path.addLine(to: point(around: center, radius: fromRadius, degrees: degrees + halfWidthDegrees))
        path.closeSubpath()
        return path
    }

    // MARK: - Dhuhr: Shamsa (twelve-lobed rosette, radiating rays)

    static func shamsa(in rect: CGRect, mode: OrnamentRenderMode) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let side = min(rect.width, rect.height)
        let cuspRadius = side * 0.285
        let lobeControlRadius = side * 0.46   // quad control; apex lands ≈ 0.37
        let rayStart = side * 0.375
        let rayEnd = side * 0.495
        let heartRadius = side * 0.085

        // The scalloped medallion edge: twelve outward lobes drawn
        // cusp-to-cusp as quadratic arcs.
        var lobes = Path()
        let first = point(around: center, radius: cuspRadius, degrees: -90)
        lobes.move(to: first)
        for i in 0..<12 {
            let cuspDegrees = -90.0 + Double(i + 1) * 30.0
            let controlDegrees = -90.0 + (Double(i) + 0.5) * 30.0
            lobes.addQuadCurve(
                to: point(around: center, radius: cuspRadius, degrees: cuspDegrees),
                control: point(around: center, radius: lobeControlRadius, degrees: controlDegrees)
            )
        }
        lobes.closeSubpath()

        var path = Path()
        path.addPath(lobes)
        switch mode {
        case .outline:
            // Rays at the cusps, alternating long and short, plus the
            // small heart circle of the medallion.
            for i in 0..<12 {
                let degrees = -90.0 + Double(i) * 30.0
                let end = i.isMultiple(of: 2) ? rayEnd : rayEnd - side * 0.045
                path.move(to: point(around: center, radius: rayStart, degrees: degrees))
                path.addLine(to: point(around: center, radius: end, degrees: degrees))
            }
            path.addEllipse(in: CGRect(
                x: center.x - heartRadius, y: center.y - heartRadius,
                width: heartRadius * 2, height: heartRadius * 2
            ))
        case .filled:
            for i in 0..<12 {
                let degrees = -90.0 + Double(i) * 30.0
                let end = i.isMultiple(of: 2) ? rayEnd : rayEnd - side * 0.045
                path.addPath(spike(
                    center: center, fromRadius: rayStart - side * 0.02, toRadius: end,
                    degrees: degrees, halfWidthDegrees: 2.0
                ))
            }
            // Even-odd heart cutout so the medallion keeps its center
            // at large sizes; it closes up gracefully at 16 pt.
            path.addEllipse(in: CGRect(
                x: center.x - heartRadius, y: center.y - heartRadius,
                width: heartRadius * 2, height: heartRadius * 2
            ))
        }
        return path
    }

    // MARK: - Asr: Khatam (eight-pointed star, two rotated squares)

    static func khatam(in rect: CGRect, mode: OrnamentRenderMode) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let side = min(rect.width, rect.height)
        let radius = side * 0.46

        var path = Path()
        switch mode {
        case .outline:
            // The construction: the two rotated squares themselves.
            path.addPath(regularPolygon(center: center, sides: 4, radius: radius, startDegrees: -90))
            path.addPath(regularPolygon(center: center, sides: 4, radius: radius, startDegrees: -45))
        case .filled:
            // Union silhouette: 16-vertex star; the trough radius of
            // two overlapped squares is R·cos45°/cos22.5° ≈ 0.7654 R.
            path.addPath(starPolygon(
                center: center, count: 8,
                outerRadius: radius,
                innerRadius: radius * 0.7654,
                startDegrees: -90
            ))
        }
        return path
    }

    // MARK: - Maghrib: Lawzina (pointed almond, fine interior line)

    static func lawzina(in rect: CGRect, mode: OrnamentRenderMode) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let side = min(rect.width, rect.height)
        let halfHeight = side * 0.48
        let halfWidth = side * 0.21

        func almond(hh: CGFloat, hw: CGFloat) -> Path {
            var path = Path()
            let top = CGPoint(x: center.x, y: center.y - hh)
            let bottom = CGPoint(x: center.x, y: center.y + hh)
            // Cubic pairs give the tapered almond profile — fuller at
            // the waist, drawn to true points at both tips.
            path.move(to: top)
            path.addCurve(
                to: bottom,
                control1: CGPoint(x: center.x + hw * 1.35, y: center.y - hh * 0.38),
                control2: CGPoint(x: center.x + hw * 1.35, y: center.y + hh * 0.38)
            )
            path.addCurve(
                to: top,
                control1: CGPoint(x: center.x - hw * 1.35, y: center.y + hh * 0.38),
                control2: CGPoint(x: center.x - hw * 1.35, y: center.y - hh * 0.38)
            )
            path.closeSubpath()
            return path
        }

        var path = Path()
        path.addPath(almond(hh: halfHeight, hw: halfWidth))
        switch mode {
        case .outline:
            // The fine interior line, stopped short of the tips.
            path.move(to: CGPoint(x: center.x, y: center.y - halfHeight * 0.62))
            path.addLine(to: CGPoint(x: center.x, y: center.y + halfHeight * 0.62))
        case .filled:
            // Interior line as a slender even-odd almond cutout, so
            // the ground shows through as drawn linework.
            path.addPath(almond(hh: halfHeight * 0.60, hw: halfWidth * 0.13))
        }
        return path
    }

    // MARK: - Isha: ten-pointed star within a circle

    static func nightStar(in rect: CGRect, mode: OrnamentRenderMode) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let side = min(rect.width, rect.height)
        let ringOuter = side * 0.49
        let ringInner = side * 0.435
        let starOuter = side * 0.375
        // {10/4}-sharp trough ratio for fine, starlike points.
        let starInner = starOuter * 0.5257

        var path = Path()
        switch mode {
        case .outline:
            path.addEllipse(in: CGRect(
                x: center.x - ringOuter, y: center.y - ringOuter,
                width: ringOuter * 2, height: ringOuter * 2
            ))
            path.addPath(starPolygon(
                center: center, count: 10,
                outerRadius: starOuter, innerRadius: starInner,
                startDegrees: -90
            ))
        case .filled:
            // Even-odd: outer + inner circles make the ring an
            // annulus; the star fills separately inside it.
            path.addEllipse(in: CGRect(
                x: center.x - ringOuter, y: center.y - ringOuter,
                width: ringOuter * 2, height: ringOuter * 2
            ))
            path.addEllipse(in: CGRect(
                x: center.x - ringInner, y: center.y - ringInner,
                width: ringInner * 2, height: ringInner * 2
            ))
            path.addPath(starPolygon(
                center: center, count: 10,
                outerRadius: starOuter, innerRadius: starInner,
                startDegrees: -90
            ))
        }
        return path
    }
}

// MARK: - Six-petal rosette (Fajr — Warda)

/// The classical compass-drawn six-petal rosette.
///
/// True construction, not an approximation: six circles of radius `r`
/// centered on the vertices of a hexagon of circumradius `r` all pass
/// through the shared center, and each adjacent pair intersects again
/// at radius `r·√3`. Each petal is the vesica between two adjacent
/// arcs — so all six petals converge at the heart and reach their
/// tips at `r·√3`, exactly as drawn with a compass on vellum.
///
/// Petals only, per the ornament spec: no rays, no lobed medallion,
/// no enclosing circle — at 16 pt this reads as a flower where the
/// Dhuhr Shamsa reads as a sun.
public struct SixPetalRosette: Shape {

    public var mode: OrnamentRenderMode

    public init(mode: OrnamentRenderMode = .filled) {
        self.mode = mode
    }

    public func path(in rect: CGRect) -> Path {
        Self.path(in: rect, mode: mode)
    }

    /// Both render modes trace the same six petal boundaries; the
    /// outline is the construction, the fill is its union (petals are
    /// disjoint except at the shared center, so even-odd is safe).
    static func path(in rect: CGRect, mode: OrnamentRenderMode) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let side = min(rect.width, rect.height)
        let tipRadius = side * 0.46
        let compassRadius = tipRadius / sqrt(3.0)

        var path = Path()
        for k in 0..<6 {
            let phi = -90.0 + Double(k) * 60.0
            path.addPath(petal(
                center: center,
                compassRadius: compassRadius,
                tipDegrees: phi
            ))
        }
        return path
    }

    /// One petal: from the shared center out to the tip along the arc
    /// of the circle at `tipDegrees − 30°`, back along the arc of the
    /// circle at `tipDegrees + 30°`. Arcs are sampled as fine
    /// polylines so the construction is coordinate-convention-proof;
    /// at marker sizes the sampling is far below a pixel.
    private static func petal(
        center: CGPoint,
        compassRadius r: CGFloat,
        tipDegrees phi: Double
    ) -> Path {
        let samples = 14
        var path = Path()
        path.move(to: center)

        // Outbound edge: circle centered at the hexagon vertex at
        // φ − 30°; the center sits on it at angle φ + 150°, the tip at
        // angle φ + 30°.
        let c1 = PrayerOrnamentShape.point(around: center, radius: r, degrees: phi - 30)
        for i in 1...samples {
            let t = Double(i) / Double(samples)
            let degrees = (phi + 150) - 120 * t
            path.addLine(to: PrayerOrnamentShape.point(around: c1, radius: r, degrees: degrees))
        }

        // Return edge: circle centered at φ + 30°; the tip sits on it
        // at angle φ − 30°, the center at angle φ − 150°.
        let c2 = PrayerOrnamentShape.point(around: center, radius: r, degrees: phi + 30)
        for i in 1...samples {
            let t = Double(i) / Double(samples)
            let degrees = (phi - 30) - 120 * t
            path.addLine(to: PrayerOrnamentShape.point(around: c2, radius: r, degrees: degrees))
        }

        path.closeSubpath()
        return path
    }
}
