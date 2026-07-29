import CoreGraphics
import Foundation

/// The plate's night extension: between Maghrib and the next true Fajr the
/// instrument gains a second arc, mirrored beneath the horizon chord — the
/// sun's unseen road. Night time maps onto it from sunset (west, right) to
/// dawn (east, left), so nisf al-layl lands at the arc's deepest point, the
/// sun's anti-transit.
///
/// Everything here is additive: the day arc, markers, and bodies above are
/// untouched, and every returned position stays inside the plate.
public extension PlateGeometry {

    /// Anchors for the divided night: the nisf al-layl filament, the start
    /// of the last third, and where their small-caps labels sit. All points
    /// are below the horizon chord and inside the plate.
    struct NightGeometry: Sendable, Equatable {
        public let midnightPoint: CGPoint
        public let lastThirdStartPoint: CGPoint
        public let midnightLabelAnchor: CGPoint
        public let lastThirdLabelAnchor: CGPoint
    }

    /// Depth of the night arc below the chord — the same budget
    /// `bodyPosition` uses for submerged bodies, so the two systems
    /// never disagree about how deep the plate goes.
    var nightDepth: CGFloat {
        max(16, rect.maxY - markerClearance - horizonY)
    }

    /// A point on the night arc at parameter `v` in `0...1`
    /// (0 = west end at the chord, 0.5 = deepest, 1 = east end).
    internal func nightArcPoint(at v: Double) -> CGPoint {
        let theta = Double.pi * v
        return CGPoint(
            x: rect.midX + nightSemiWidth * CGFloat(cos(theta)),
            y: horizonY + nightDepth * CGFloat(sin(theta))
        )
    }

    private var nightSemiWidth: CGFloat {
        max(12, rect.width / 2 - markerClearance - 4)
    }

    /// Position on the night arc for an instant of the night. Times are
    /// clamped to `nightStart...nightEnd`, then mapped into the same
    /// angular inset the day arc uses — inside the plate for ANY input.
    func nightPosition(for time: Date, nightStart: Date, nightEnd: Date) -> CGPoint {
        let span = max(60, nightEnd.timeIntervalSince(nightStart))
        let fraction = max(0.0, min(1.0, time.timeIntervalSince(nightStart) / span))
        let v = angularInsetFraction + fraction * (1 - 2 * angularInsetFraction)
        return nightArcPoint(at: v)
    }

    /// The night arc as a drawable path across the inset span.
    func nightArcPath(samples: Int = 64) -> CGPath {
        let path = CGMutablePath()
        guard samples >= 2 else { return path }
        let insetSpan = 1 - 2 * angularInsetFraction
        for i in 0...samples {
            let v = angularInsetFraction + insetSpan * Double(i) / Double(samples)
            let point = nightArcPoint(at: v)
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }

    /// The region between the last third's start and dawn, bounded by the
    /// chord above and the night arc below — the surface that receives the
    /// quiet luminance lift.
    func lastThirdRegionPath(
        nightStart: Date,
        lastThirdStart: Date,
        nightEnd: Date,
        samples: Int = 48
    ) -> CGPath {
        let span = max(60, nightEnd.timeIntervalSince(nightStart))
        let startFraction = max(0.0, min(1.0, lastThirdStart.timeIntervalSince(nightStart) / span))
        let vStart = angularInsetFraction + startFraction * (1 - 2 * angularInsetFraction)
        let vEnd = 1 - angularInsetFraction

        let path = CGMutablePath()
        guard samples >= 2, vEnd > vStart else { return path }

        let first = nightArcPoint(at: vStart)
        path.move(to: CGPoint(x: first.x, y: horizonY))
        for i in 0...samples {
            let v = vStart + (vEnd - vStart) * Double(i) / Double(samples)
            path.addLine(to: nightArcPoint(at: v))
        }
        let last = nightArcPoint(at: vEnd)
        path.addLine(to: CGPoint(x: last.x, y: horizonY))
        path.closeSubpath()
        return path
    }

    /// The divided night's anchors for a concrete set of night instants.
    func nightGeometry(
        nightStart: Date,
        nisfAlLayl: Date,
        lastThirdStart: Date,
        nightEnd: Date
    ) -> NightGeometry {
        let midnight = nightPosition(for: nisfAlLayl, nightStart: nightStart, nightEnd: nightEnd)
        let lastThirdPoint = nightPosition(for: lastThirdStart, nightStart: nightStart, nightEnd: nightEnd)

        // The midnight inscription floats just above its filament; the last
        // third's sits inside the lifted region, midway to dawn.
        let span = max(60, nightEnd.timeIntervalSince(nightStart))
        let lastFraction = max(0.0, min(1.0, lastThirdStart.timeIntervalSince(nightStart) / span))
        let vLast = angularInsetFraction + lastFraction * (1 - 2 * angularInsetFraction)
        let vMid = (vLast + 1 - angularInsetFraction) / 2
        let regionMid = nightArcPoint(at: vMid)

        return NightGeometry(
            midnightPoint: midnight,
            lastThirdStartPoint: lastThirdPoint,
            midnightLabelAnchor: CGPoint(
                x: midnight.x,
                y: max(horizonY + 12, midnight.y - 16)
            ),
            lastThirdLabelAnchor: CGPoint(
                x: regionMid.x,
                y: horizonY + (regionMid.y - horizonY) * 0.55
            )
        )
    }

    /// The nisf al-layl mark: a fine vertical lens crossing the night arc,
    /// to be FILLED in metal — the same tapered construction as the
    /// horizon's terrain filament, turned upright.
    func midnightFilamentPath(
        at point: CGPoint,
        length: CGFloat = 12,
        thickness: CGFloat = 1.4
    ) -> CGPath {
        let top = CGPoint(x: point.x, y: point.y - length / 2)
        let bottom = CGPoint(x: point.x, y: point.y + length / 2)
        let path = CGMutablePath()
        let midY = point.y
        path.move(to: top)
        path.addQuadCurve(to: bottom, control: CGPoint(x: point.x + thickness, y: midY))
        path.addQuadCurve(to: top, control: CGPoint(x: point.x - thickness, y: midY))
        path.closeSubpath()
        return path
    }
}
