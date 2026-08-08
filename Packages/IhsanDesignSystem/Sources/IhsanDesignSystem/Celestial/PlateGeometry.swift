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

    /// The sunrise mark is part of the plate's bounded layout, not a
    /// view-local offset. `point` is the exact time-position on the day
    /// arc; `labelFrame` is the nearest clear inscription frame that
    /// remains inside the plate and outside every marker knockout.
    public struct SunriseMarkLayout: Sendable, Equatable {
        public let point: CGPoint
        public let labelFrame: CGRect

        public init(point: CGPoint, labelFrame: CGRect) {
            self.point = point
            self.labelFrame = labelFrame
        }
    }

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
        // label, below) inside the rect. The lowest markers are the
        // arc's endpoint events, which sit ABOVE the chord by
        // rise·sin(π·inset) — so the chord itself may go deeper than
        // the marker-safe line by exactly that margin. Solving
        //   chord − (chord − topSafe)·s ≤ bottomSafe,  s = sin(π·inset)
        // for the chord gives the true bound.
        let topSafeY = rect.minY + markerClearance + 4
        let bottomSafeY = rect.maxY - markerClearance - labelClearance
        let s = CGFloat(sin(.pi * self.angularInsetFraction))
        let chordBound = min(
            (bottomSafeY - topSafeY * s) / max(1 - s, 0.01),
            rect.maxY - 4
        )
        let preferred = rect.minY + rect.height * min(max(horizonFraction, 0.10), 0.98)
        let base = min(preferred, max(bottomSafeY, chordBound))
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
        arcPoint(at: arcParameter(for: time))
    }

    /// Bounded sunrise placement, including the pre-Fajr case where
    /// the displayed markers belong to the previous prayer cycle but
    /// sunrise belongs to the coming morning.
    ///
    /// The sunrise-to-Fajr/Dhuhr ratio comes from the displayed solar
    /// schedule. That ratio is then laid onto the plate's visible
    /// Fajr-to-Dhuhr segment. This keeps the mark at its real morning
    /// time-position without ever treating a next-day absolute instant
    /// as an event after Isha and clamping it to the arc end.
    ///
    /// `markerFajr` and `markerDhuhr` are the instants used by the two
    /// visible prayer markers. During the civil day they equal `fajr`
    /// and `dhuhr`; before Fajr they belong to the previous cycle.
    public func sunriseMarkLayout(
        sunrise: Date,
        fajr: Date,
        dhuhr: Date,
        markerFajr: Date,
        markerDhuhr: Date,
        labelSize: CGSize = CGSize(width: 112, height: 18),
        avoiding markerKnockouts: [CGRect] = [],
        ornamentClearance: CGFloat = 7
    ) -> SunriseMarkLayout {
        let solarSpan = max(60, dhuhr.timeIntervalSince(fajr))
        let morningFraction = max(
            0.0,
            min(1.0, sunrise.timeIntervalSince(fajr) / solarSpan)
        )
        let fajrParameter = arcParameter(for: markerFajr)
        let dhuhrParameter = arcParameter(for: markerDhuhr)
        let parameter = fajrParameter + morningFraction * (dhuhrParameter - fajrParameter)
        let point = arcPoint(at: parameter)
        let labelFrame = clearInscriptionFrame(
            beside: point,
            size: labelSize,
            avoiding: markerKnockouts,
            clearance: ornamentClearance
        )
        return SunriseMarkLayout(point: point, labelFrame: labelFrame)
    }

    /// Convenience for the ordinary civil-day case, where the solar
    /// anchors and the visible prayer-marker anchors are identical.
    public func sunriseMarkLayout(
        sunrise: Date,
        fajr: Date,
        dhuhr: Date,
        labelSize: CGSize = CGSize(width: 112, height: 18),
        avoiding markerKnockouts: [CGRect] = [],
        ornamentClearance: CGFloat = 7
    ) -> SunriseMarkLayout {
        sunriseMarkLayout(
            sunrise: sunrise,
            fajr: fajr,
            dhuhr: dhuhr,
            markerFajr: fajr,
            markerDhuhr: dhuhr,
            labelSize: labelSize,
            avoiding: markerKnockouts,
            ornamentClearance: ornamentClearance
        )
    }

    /// The sunrise tick uses the plate's filament knockout discipline:
    /// it is cut into tapered kept runs before it can cross a prayer
    /// ornament or label. When sunrise is extremely close to Fajr, the
    /// ornament wins and the occluded portion of the subordinate tick
    /// disappears instead of drawing through it.
    public func sunriseTickFilamentSegments(
        at point: CGPoint,
        avoiding markerKnockouts: [CGRect],
        ornamentClearance: CGFloat = 7,
        length: CGFloat = 12,
        samples: Int = 24,
        maxThickness: CGFloat = 1.2
    ) -> [CGPath] {
        guard samples >= 2 else { return [] }
        let startY = point.y - length / 2
        let points = (0...samples).map { index in
            CGPoint(
                x: point.x,
                y: startY + length * CGFloat(index) / CGFloat(samples)
            )
        }
        return Self.segments(
            of: points,
            avoiding: markerKnockouts,
            clearance: ornamentClearance
        ).map { Self.taperedRibbonPath(along: $0, maxThickness: maxThickness) }
    }

    private func arcParameter(for time: Date) -> Double {
        let fraction = max(
            0.0,
            min(1.0, (time.timeIntervalSinceReferenceDate - domainStart) / domainSpan)
        )
        return angularInsetFraction + fraction * (1 - 2 * angularInsetFraction)
    }

    /// Finds the nearest label frame that satisfies the same 7-point
    /// marker-clearance discipline as the plate's engraved filaments.
    /// Candidate frames are clamped before collision testing, so the
    /// returned frame is inside `rect` by construction.
    private func clearInscriptionFrame(
        beside point: CGPoint,
        size: CGSize,
        avoiding markerKnockouts: [CGRect],
        clearance: CGFloat
    ) -> CGRect {
        let width = min(max(1, size.width), max(1, rect.width - 4))
        let height = min(max(1, size.height), max(1, rect.height - 4))
        let safeRect = rect.insetBy(dx: 2, dy: 2)
        let zones = markerKnockouts.map {
            $0.insetBy(dx: -clearance, dy: -clearance)
        }

        func boundedFrame(x: CGFloat, y: CGFloat) -> CGRect {
            let boundedX = min(max(x, safeRect.minX), safeRect.maxX - width)
            let boundedY = min(max(y, safeRect.minY), safeRect.maxY - height)
            return CGRect(x: boundedX, y: boundedY, width: width, height: height)
        }

        func isClear(_ frame: CGRect) -> Bool {
            !zones.contains { $0.intersects(frame) }
        }

        let preferred = CGPoint(x: point.x + 10, y: point.y + 8)
        let xOrigins = [
            preferred.x,
            point.x - width - 10,
            point.x - width / 2
        ]
        let yOrigins = [
            preferred.y,
            point.y - height - 8,
            point.y + 30,
            point.y - height - 30,
            point.y + 52,
            point.y - height - 52
        ]

        var candidates: [CGRect] = []
        for y in yOrigins {
            for x in xOrigins {
                let candidate = boundedFrame(x: x, y: y)
                if !candidates.contains(candidate) { candidates.append(candidate) }
            }
        }
        if let candidate = candidates.first(where: isClear) {
            return candidate
        }

        // Dense scenes (especially the watch plate) can exhaust the
        // nearby placements. Search the whole bounded plate, then keep
        // the clear frame nearest the preferred inscription origin.
        var nearest: (frame: CGRect, distance: CGFloat)?
        let xStep = max(2, min(6, width / 16))
        let yStep = max(2, min(6, height / 3))
        var y = safeRect.minY
        while y <= safeRect.maxY - height + 0.01 {
            var x = safeRect.minX
            while x <= safeRect.maxX - width + 0.01 {
                let candidate = CGRect(x: x, y: y, width: width, height: height)
                if isClear(candidate) {
                    let distance = hypot(candidate.minX - preferred.x, candidate.minY - preferred.y)
                    if nearest == nil || distance < nearest!.distance {
                        nearest = (candidate, distance)
                    }
                }
                x += xStep
            }
            y += yStep
        }
        if let nearest { return nearest.frame }

        // A plate physically too dense to fit this inscription still
        // gets a bounded frame; callers can shorten copy, but geometry
        // never returns an off-screen label.
        return boundedFrame(x: preferred.x, y: preferred.y)
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
    /// terrain mark. `insetFraction` widens for the ground-plane
    /// echoes below the chord, which shorten as they deepen.
    public static func filamentPath(
        in rect: CGRect,
        horizonY: CGFloat,
        thickness: CGFloat = 1.4,
        insetFraction: CGFloat = 0.06
    ) -> CGPath {
        let inset = rect.width * insetFraction
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

    // MARK: - Engraved filaments

    /// A tapered ribbon along a polyline: full `maxThickness` at the
    /// middle, dissolving to a point at both ends — the engraved-
    /// filament construction. To be FILLED, never stroked, so the
    /// line genuinely tapers instead of ending in a butt cap.
    static func taperedRibbonPath(
        along points: [CGPoint],
        maxThickness: CGFloat
    ) -> CGPath {
        let path = CGMutablePath()
        guard points.count >= 2 else { return path }

        var upper: [CGPoint] = []
        var lower: [CGPoint] = []
        let last = points.count - 1
        for (i, p) in points.enumerated() {
            let t = Double(i) / Double(last)
            // sin taper: zero-width at both ends, eased so the middle
            // holds its hairline weight for most of the run.
            let halfWidth = maxThickness * CGFloat(pow(sin(.pi * t), 0.7)) / 2
            let previous = points[max(0, i - 1)]
            let next = points[min(last, i + 1)]
            let dx = next.x - previous.x
            let dy = next.y - previous.y
            let length = max(0.0001, (dx * dx + dy * dy).squareRoot())
            let nx = -dy / length
            let ny = dx / length
            upper.append(CGPoint(x: p.x + nx * halfWidth, y: p.y + ny * halfWidth))
            lower.append(CGPoint(x: p.x - nx * halfWidth, y: p.y - ny * halfWidth))
        }

        path.move(to: upper[0])
        for p in upper.dropFirst() { path.addLine(to: p) }
        for p in lower.reversed() { path.addLine(to: p) }
        path.closeSubpath()
        return path
    }

    /// The day arc as an engraved filament — a continuous hairline in
    /// metal, tapered at both ends, passing through every marker
    /// position (markers sit on this arc by construction).
    public func arcFilamentPath(
        samples: Int = 64,
        maxThickness: CGFloat = 1.6
    ) -> CGPath {
        guard samples >= 2 else { return CGMutablePath() }
        let insetSpan = 1 - 2 * angularInsetFraction
        let points = (0...samples).map { i in
            arcPoint(at: angularInsetFraction + insetSpan * Double(i) / Double(samples))
        }
        return Self.taperedRibbonPath(along: points, maxThickness: maxThickness)
    }

    // MARK: - Filament knockouts

    /// Engraved lines never pass through ornaments: on classical
    /// instruments, linework terminates at medallions. A knockout is
    /// the bounding form of an ornament or its label; every filament
    /// the plate draws terminates `clearance` points short of it.
    ///
    /// Segmentation is real geometry — the polyline is cut into kept
    /// runs and each run is rebuilt as its own tapered ribbon, so the
    /// line dissolves to a point at every termination. No
    /// background-colored patches anywhere.
    static func segments(
        of points: [CGPoint],
        avoiding knockouts: [CGRect],
        clearance: CGFloat
    ) -> [[CGPoint]] {
        guard !knockouts.isEmpty else { return points.count >= 2 ? [points] : [] }
        let zones = knockouts.map { $0.insetBy(dx: -clearance, dy: -clearance) }

        var runs: [[CGPoint]] = []
        var current: [CGPoint] = []
        for point in points {
            if zones.contains(where: { $0.contains(point) }) {
                if current.count >= 2 { runs.append(current) }
                current = []
            } else {
                current.append(point)
            }
        }
        if current.count >= 2 { runs.append(current) }
        return runs
    }

    /// Sample points along the day arc's inset angular span.
    func arcPolyline(samples: Int) -> [CGPoint] {
        guard samples >= 2 else { return [] }
        let insetSpan = 1 - 2 * angularInsetFraction
        return (0...samples).map { i in
            arcPoint(at: angularInsetFraction + insetSpan * Double(i) / Double(samples))
        }
    }

    /// The day arc as engraved filament segments that terminate short
    /// of every knockout — one tapered ribbon per kept run.
    public func arcFilamentSegments(
        avoiding knockouts: [CGRect],
        clearance: CGFloat = 7,
        samples: Int = 128,
        maxThickness: CGFloat = 1.6
    ) -> [CGPath] {
        Self.segments(
            of: arcPolyline(samples: samples),
            avoiding: knockouts,
            clearance: clearance
        ).map { Self.taperedRibbonPath(along: $0, maxThickness: maxThickness) }
    }

    /// One almucantar as engraved filament segments, same termination
    /// rule as the day arc.
    public func almucantarFilamentSegments(
        riseFraction: CGFloat,
        avoiding knockouts: [CGRect],
        clearance: CGFloat = 7,
        samples: Int = 96,
        maxThickness: CGFloat = 0.8
    ) -> [CGPath] {
        guard samples >= 2 else { return [] }
        let fraction = max(0.05, min(0.95, riseFraction))
        let insetSpan = 1 - 2 * angularInsetFraction
        let points = (0...samples).map { i -> CGPoint in
            let u = angularInsetFraction + insetSpan * Double(i) / Double(samples)
            let theta = Double.pi * (1 - u)
            return CGPoint(
                x: centerX + semiWidth * CGFloat(cos(theta)),
                y: horizonY - rise * fraction * CGFloat(sin(theta))
            )
        }
        return Self.segments(of: points, avoiding: knockouts, clearance: clearance)
            .map { Self.taperedRibbonPath(along: $0, maxThickness: maxThickness) }
    }

    /// The sun's engraved ray collar as filament segments — the
    /// Shamsa's twelve-fold construction (see `EngravedSunRays`) run
    /// through the plate's one linework rule.
    ///
    /// `center` is the sun's own plate position, so the collar travels
    /// with the sun and never rotates. Around solar noon the sun
    /// stands on Dhuhr's marker, which is exactly when the knockout
    /// matters: the rays terminate short of the Shamsa and its label
    /// rather than crossing them, the same way the day arc does.
    public func sunRayFilamentSegments(
        around center: CGPoint,
        bodyDiameter: CGFloat,
        avoiding knockouts: [CGRect],
        clearance: CGFloat = 7,
        maxThickness: CGFloat = 0.9
    ) -> [CGPath] {
        EngravedSunRays
            .rayPolylines(around: center, bodyDiameter: bodyDiameter)
            .flatMap {
                Self.segments(of: $0, avoiding: knockouts, clearance: clearance)
            }
            .map { Self.taperedRibbonPath(along: $0, maxThickness: maxThickness) }
    }

    /// One almucantar: the altitude line at `riseFraction` of the
    /// arc's rise, nested under the day arc — the structural linework
    /// that makes the sky read as an instrument plate.
    public func almucantarPath(
        riseFraction: CGFloat,
        samples: Int = 48
    ) -> CGPath {
        let path = CGMutablePath()
        guard samples >= 2 else { return path }
        let fraction = max(0.05, min(0.95, riseFraction))
        let insetSpan = 1 - 2 * angularInsetFraction
        for i in 0...samples {
            let u = angularInsetFraction + insetSpan * Double(i) / Double(samples)
            let theta = Double.pi * (1 - u)
            let point = CGPoint(
                x: centerX + semiWidth * CGFloat(cos(theta)),
                y: horizonY - rise * fraction * CGFloat(sin(theta))
            )
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
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
