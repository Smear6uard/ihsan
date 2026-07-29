import CoreGraphics
import Foundation

/// The bounded composition of the celestial instrument.
///
/// v1 treated the Today scene as a chart: times projected linearly
/// across the viewport, so Fajr and Isha clipped at the screen edges.
/// `PlateGeometry` is the corrective. It defines an astrolabe-like
/// plate: a day arc bowed over a horizon chord, with every position it
/// returns guaranteed to fall fully inside the plate — including the
/// domain's first and last events, which land at an angular inset of
/// 8–10% from the arc's ends, never at the frame.
///
/// Pure math, no SwiftUI. The scene view and the property tests share
/// this single source of positioning truth.
public struct PlateGeometry: Sendable, Equatable {

    // MARK: Inputs

    /// The scene rectangle the plate composes within.
    public let rect: CGRect
    /// Angular inset at each end of the day arc, as a fraction of the
    /// arc's angular span. Clamped to `0.08...0.10` per the instrument
    /// spec.
    public let angularInsetFraction: Double
    /// Half-extent reserved around every returned position for the
    /// ornament at its largest size. No marker's box may cross the
    /// frame.
    public let markerClearance: CGFloat
    /// Extra vertical room reserved BELOW marker positions for their
    /// time labels.
    public let labelClearance: CGFloat

    // MARK: Derived composition

    /// The y-coordinate of the horizon chord.
    public let horizonY: CGFloat

    private let domainStart: TimeInterval
    private let domainSpan: TimeInterval
    private let centerX: CGFloat
    private let semiWidth: CGFloat
    private let rise: CGFloat

    /// - Parameters:
    ///   - rect: The scene rectangle. Guarantees assume a rect at
    ///     least ~120 pt on each side; watch-size scenes qualify.
    ///   - eventTimes: The day's event instants. The arc's time domain
    ///     is their min…max; order and count are otherwise free.
    ///   - horizonFraction: Preferred horizon height as a fraction of
    ///     the rect. The chord is pulled up automatically if the
    ///     bottom clearances demand it.
    ///   - angularInsetFraction: See the stored property.
    ///   - markerClearance: See the stored property.
    ///   - labelClearance: See the stored property.
    public init(
        rect: CGRect,
        eventTimes: [Date],
        horizonFraction: CGFloat = 0.62,
        angularInsetFraction: Double = 0.09,
        markerClearance: CGFloat = 32,
        labelClearance: CGFloat = 44
    ) {
        self.rect = rect
        self.angularInsetFraction = min(0.10, max(0.08, angularInsetFraction))
        self.markerClearance = markerClearance
        self.labelClearance = labelClearance

        let times = eventTimes.map(\.timeIntervalSinceReferenceDate)
        let start = times.min() ?? 0
        let end = times.max() ?? 0
        domainStart = start
        domainSpan = max(60, end - start)

        // The safe frame: positions must keep a full marker box (and
        // label, below) inside the rect.
        let topSafeY = rect.minY + markerClearance + 4
        let bottomSafeY = rect.maxY - markerClearance - labelClearance
        let preferred = rect.minY + rect.height * min(max(horizonFraction, 0.10), 0.95)
        let base = min(preferred, bottomSafeY)
        horizonY = max(base, topSafeY + 24)

        centerX = rect.midX
        semiWidth = max(12, rect.width / 2 - markerClearance - 4)
        rise = max(12, horizonY - topSafeY)
    }

    // MARK: - Day arc

    /// Position on the day arc for an event time. Times are clamped
    /// to the domain, then mapped into the inset angular span — so
    /// the returned point sits strictly inside the plate for ANY
    /// input, including the domain endpoints and out-of-range times.
    public func markerPosition(for time: Date) -> CGPoint {
        let fraction = max(
            0.0,
            min(1.0, (time.timeIntervalSinceReferenceDate - domainStart) / domainSpan)
        )
        let u = angularInsetFraction + fraction * (1 - 2 * angularInsetFraction)
        return arcPoint(at: u)
    }

    /// A point on the arc at angular parameter `u` in `0...1`
    /// (0 = left end, 1 = right end, 0.5 = apex).
    func arcPoint(at u: Double) -> CGPoint {
        let theta = Double.pi * (1 - u)
        return CGPoint(
            x: centerX + semiWidth * CGFloat(cos(theta)),
            y: horizonY - rise * CGFloat(sin(theta))
        )
    }

    /// The apex of the day arc.
    public var arcApex: CGPoint {
        arcPoint(at: 0.5)
    }

    /// The day arc as a drawable path (sampled ellipse segment across
    /// the full angular span, insets included).
    public func arcPath(samples: Int = 64) -> CGPath {
        let path = CGMutablePath()
        guard samples >= 2 else { return path }
        let insetSpan = 1 - 2 * angularInsetFraction
        for i in 0...samples {
            let u = angularInsetFraction + insetSpan * Double(i) / Double(samples)
            let point = arcPoint(at: u)
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }

    // MARK: - Horizon

    /// Endpoints of the horizon chord — inset from the plate edges,
    /// never edge-to-edge.
    public var horizonChord: (start: CGPoint, end: CGPoint) {
        let inset = rect.width * 0.06
        return (
            CGPoint(x: rect.minX + inset, y: horizonY),
            CGPoint(x: rect.maxX - inset, y: horizonY)
        )
    }

    /// The terrain filament: a lens-shaped path along the horizon
    /// chord with tapered ends, to be FILLED (in metal) rather than
    /// stroked, so the line genuinely tapers to points.
    public func filamentPath(thickness: CGFloat = 1.4) -> CGPath {
        Self.filamentPath(in: rect, horizonY: horizonY, thickness: thickness)
    }

    /// Shared filament construction — `CelestialSkyView` uses this
    /// directly so the atmosphere and the plate draw the identical
    /// terrain mark.
    public static func filamentPath(
        in rect: CGRect,
        horizonY: CGFloat,
        thickness: CGFloat = 1.4
    ) -> CGPath {
        let inset = rect.width * 0.06
        let start = CGPoint(x: rect.minX + inset, y: horizonY)
        let end = CGPoint(x: rect.maxX - inset, y: horizonY)
        let path = CGMutablePath()
        let midX = (start.x + end.x) / 2
        path.move(to: start)
        path.addQuadCurve(to: end, control: CGPoint(x: midX, y: horizonY - thickness))
        path.addQuadCurve(to: start, control: CGPoint(x: midX, y: horizonY + thickness))
        path.closeSubpath()
        return path
    }

    // MARK: - Celestial bodies

    /// Map a body's (altitude, azimuth) into plate space.
    ///
    /// - Parameters:
    ///   - altitudeDegrees: Degrees above the horizon. Positive maps
    ///     between the chord and the arc's apex height; negative maps
    ///     below the chord — still inside the plate — reaching full
    ///     depth at astronomical twilight (−18°).
    ///   - azimuthUnit: Horizontal position across the plate in
    ///     `0...1` (the caller maps its hour-angle convention into
    ///     this; the plate does not care which).
    ///   - apexAltitudeDegrees: The day's solar culmination altitude.
    ///     The vertical scale is normalised to it, so at solar noon
    ///     the sun sits exactly at the arc's apex — the arc is the
    ///     day's own road, not a fixed 90° protractor. Bodies higher
    ///     than the apex (a high moon) clamp to the apex height. The
    ///     default keeps the legacy 90° scale for callers that have
    ///     no ephemeris.
    public func bodyPosition(
        altitudeDegrees: Double,
        azimuthUnit: Double,
        apexAltitudeDegrees: Double = 90.0
    ) -> CGPoint {
        let clampedAzimuth = max(0.0, min(1.0, azimuthUnit))
        let x = centerX + semiWidth * CGFloat(clampedAzimuth * 2 - 1)
        if altitudeDegrees >= 0 {
            let apex = max(1.0, min(90.0, apexAltitudeDegrees))
            let a = min(1.0, min(90.0, altitudeDegrees) / apex)
            return CGPoint(x: x, y: horizonY - rise * CGFloat(a))
        }
        let depth = max(8, rect.maxY - markerClearance - horizonY)
        let a = min(18.0, -altitudeDegrees) / 18.0
        return CGPoint(x: x, y: horizonY + depth * CGFloat(a))
    }
}
