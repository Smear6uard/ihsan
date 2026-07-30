import Foundation

/// The four solar events that anchor the day's palette. The package
/// never computes prayer times — the caller (which already owns an
/// Adhan-derived schedule) supplies these, and everything downstream
/// resolves from them. Clock hours are never consulted.
public struct SolarDayEvents: Sendable, Equatable {

    public var sunrise: Date
    public var solarNoon: Date
    public var maghrib: Date
    public var isha: Date

    public init(sunrise: Date, solarNoon: Date, maghrib: Date, isha: Date) {
        self.sunrise = sunrise
        self.solarNoon = solarNoon
        self.maghrib = maghrib
        self.isha = isha
    }
}

/// A continuous position in palette space.
///
/// `unit` runs `[0, 1)` around one solar day:
///
/// ```
/// 0.000  deep night        (plateau center)
/// 0.125  sunrise           (night → morning transition center)
/// 0.250  mid-morning       (plateau center)
/// 0.375  solar noon        (morning → afternoon transition center)
/// 0.500  mid-afternoon     (plateau center)
/// 0.625  maghrib           (afternoon → sunset transition center)
/// 0.750  sunset heart      (plateau center)
/// 0.875  isha              (sunset → night transition center)
/// ```
///
/// `resolve(at:events:)` maps a real moment onto this scale by
/// piecewise-linear interpolation between the supplied solar events,
/// so the palette transitions always straddle the actual sunrise /
/// noon / maghrib / isha moments regardless of season or latitude.
/// Tokens are then continuous functions of `unit` (see
/// `PaletteState.resolved(for:)`) — there is no boundary at which
/// colors can snap.
public struct SkyPhase: Sendable, Equatable, Hashable {

    /// Palette-space position, wrapped into `[0, 1)`.
    public var unit: Double

    public init(unit: Double) {
        self.unit = Self.wrap(unit)
    }

    /// Wrap any real number into `[0, 1)`.
    static func wrap(_ value: Double) -> Double {
        let r = value.truncatingRemainder(dividingBy: 1.0)
        return r < 0 ? r + 1.0 : r
    }

    // MARK: - Resolution from solar events

    /// Palette-space positions of the four solar events.
    static let sunriseUnit = 0.125
    static let solarNoonUnit = 0.375
    static let maghribUnit = 0.625
    static let ishaUnit = 0.875

    /// Chrome fallback for surfaces that have no solar schedule (the
    /// secondary pages, whose grounds follow the hour, not the sun):
    /// maps the local clock onto palette space through fixed anchor
    /// hours — 6:00 sunrise, 13:00 solar noon, 19:00 maghrib, 20:30
    /// isha. Surfaces that DO know the day's real events must use
    /// `resolve(at:events:)`; this is deliberately coarse, and only
    /// ever drives ground/panel tints — never the celestial plate.
    public static func approximate(
        at date: Date, timeZone: TimeZone = .current
    ) -> SkyPhase {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let midnight = calendar.startOfDay(for: date)
        let seconds = date.timeIntervalSince(midnight)

        // (hour anchor, palette unit), with the previous isha and the
        // next sunrise wrapping the night exactly like resolve(at:).
        let anchors: [(time: TimeInterval, unit: Double)] = [
            (20.5 * 3600 - 86_400, ishaUnit - 1.0),
            (6.0 * 3600, sunriseUnit),
            (13.0 * 3600, solarNoonUnit),
            (19.0 * 3600, maghribUnit),
            (20.5 * 3600, ishaUnit),
            (6.0 * 3600 + 86_400, sunriseUnit + 1.0),
        ]

        if seconds <= anchors[0].time {
            return SkyPhase(unit: anchors[0].unit)
        }
        for i in 0..<(anchors.count - 1) {
            let a = anchors[i], b = anchors[i + 1]
            if seconds <= b.time {
                let f = (seconds - a.time) / (b.time - a.time)
                return SkyPhase(unit: a.unit + f * (b.unit - a.unit))
            }
        }
        return SkyPhase(unit: anchors[anchors.count - 1].unit)
    }

    /// Map a real moment onto palette space using the day's solar
    /// events. Times before sunrise interpolate from the previous
    /// night's isha (approximated one day earlier); times after isha
    /// interpolate toward the next sunrise (one day later). Degenerate
    /// event orderings (extreme-latitude schedules where a caller
    /// supplies near-coincident events) are guarded by a minimum
    /// segment length so the mapping stays monotonic and finite.
    public static func resolve(at date: Date, events: SolarDayEvents) -> SkyPhase {
        let day: TimeInterval = 86_400
        let minSegment: TimeInterval = 60

        // Control points as (time, palette unit), strictly increasing
        // in both coordinates. The night wraps: previous isha sits one
        // day before this day's, the next sunrise one day after.
        var points: [(time: TimeInterval, unit: Double)] = []
        var cursor = events.isha.timeIntervalSinceReferenceDate - day
        points.append((cursor, ishaUnit - 1.0))

        for (time, unit) in [
            (events.sunrise.timeIntervalSinceReferenceDate, sunriseUnit),
            (events.solarNoon.timeIntervalSinceReferenceDate, solarNoonUnit),
            (events.maghrib.timeIntervalSinceReferenceDate, maghribUnit),
            (events.isha.timeIntervalSinceReferenceDate, ishaUnit),
            (events.sunrise.timeIntervalSinceReferenceDate + day, sunriseUnit + 1.0)
        ] {
            cursor = max(time, cursor + minSegment)
            points.append((cursor, unit))
        }

        let t = date.timeIntervalSinceReferenceDate

        if t <= points[0].time {
            return SkyPhase(unit: points[0].unit)
        }
        for i in 0..<(points.count - 1) {
            let a = points[i], b = points[i + 1]
            if t <= b.time {
                let f = (t - a.time) / (b.time - a.time)
                return SkyPhase(unit: a.unit + f * (b.unit - a.unit))
            }
        }
        return SkyPhase(unit: points[points.count - 1].unit)
    }

    /// The phase at the exact center of a canonical state's plateau —
    /// the fixed-state override for previews and tests.
    public static func fixed(_ state: PaletteState) -> SkyPhase {
        switch state {
        case .night: return SkyPhase(unit: 0.0)
        case .morning: return SkyPhase(unit: 0.25)
        case .afternoon: return SkyPhase(unit: 0.50)
        case .sunset: return SkyPhase(unit: 0.75)
        }
    }

    // MARK: - State weighting

    /// Half-width of each ATMOSPHERE transition band in palette space.
    /// `0.035` of the cycle ≈ ±50 minutes of real time on a six-hour
    /// quarter — long enough to read as sky changing, short enough
    /// that each state holds a clear plateau identity. Ground, wash,
    /// glow, and metal drift across this band.
    static let atmosphereHalfWidth = 0.035

    /// Half-width of the FIGURE transition band — ink, panel fill, and
    /// status colors. Deliberately narrower than the atmosphere band:
    /// at sunrise and maghrib the ink and the ground swap luminance
    /// polarity, and any continuous crossfade must pass them through
    /// each other (intermediate value theorem — there is provably an
    /// instant of 1:1 contrast; no timing trick avoids it). Keeping
    /// the figure flip narrow confines that low-contrast passage to a
    /// short "the lamps come on" moment while the sky drifts on its
    /// own longer clock, and `inkHaloStrength` covers legibility
    /// through the passage. Still smootherstep-eased and fully
    /// continuous — the flip is quick, never a snap. 0.005 of the
    /// cycle keeps the whole flip inside ±9 real minutes around
    /// maghrib on a mid-latitude summer day.
    static let figureHalfWidth = 0.005

    private static let boundaries: [(center: Double, from: PaletteState, to: PaletteState)] = [
        (SkyPhase.sunriseUnit, .night, .morning),
        (SkyPhase.solarNoonUnit, .morning, .afternoon),
        (SkyPhase.maghribUnit, .afternoon, .sunset),
        (SkyPhase.ishaUnit, .sunset, .night)
    ]

    private func blend(halfWidth hw: Double) -> (from: PaletteState, to: PaletteState, amount: Double) {
        let u = unit
        for boundary in Self.boundaries where abs(u - boundary.center) <= hw {
            let raw = (u - (boundary.center - hw)) / (2 * hw)
            return (boundary.from, boundary.to, Self.smootherstep(raw))
        }
        // Plateau — pick the state whose quarter contains the phase.
        switch u {
        case ..<Self.sunriseUnit: return (.night, .night, 0)
        case ..<Self.solarNoonUnit: return (.morning, .morning, 0)
        case ..<Self.maghribUnit: return (.afternoon, .afternoon, 0)
        case ..<Self.ishaUnit: return (.sunset, .sunset, 0)
        default: return (.night, .night, 0)
        }
    }

    /// Atmosphere blend — the two states this phase sits between and
    /// the drift amount toward the second. On a plateau the amount is
    /// exactly 0.
    public var blend: (from: PaletteState, to: PaletteState, amount: Double) {
        blend(halfWidth: Self.atmosphereHalfWidth)
    }

    /// Figure blend — the narrower window in which ink, panels, and
    /// status colors cross. See `figureHalfWidth` for why this is
    /// separate from the atmosphere.
    public var figureBlend: (from: PaletteState, to: PaletteState, amount: Double) {
        blend(halfWidth: Self.figureHalfWidth)
    }

    /// How strongly text needs its opposite-pole halo right now,
    /// `0...1`. Zero on every plateau; rises over the atmosphere band
    /// of the two polarity-crossing boundaries (sunrise, maghrib),
    /// peaking as the figure flip crosses mid-tone ground. Text-bearing
    /// components apply `tokens.inkHalo` at this strength so glyphs
    /// stay legible through the crossing that continuous interpolation
    /// cannot mathematically avoid.
    public var inkHaloStrength: Double {
        let mix = blend
        guard mix.amount > 0, mix.from != mix.to else { return 0 }
        let fromDark = mix.from.tokens.groundBottomValue.relativeLuminance < 0.5
        let toDark = mix.to.tokens.groundBottomValue.relativeLuminance < 0.5
        guard fromDark != toDark else { return 0 }
        return sin(.pi * mix.amount)
    }

    /// The perceptually dominant state at this phase.
    public var dominantState: PaletteState {
        let mix = blend
        return mix.amount < 0.5 ? mix.from : mix.to
    }

    /// How "night" this phase is, `0...1` — drives the star field and
    /// other night-only atmospherics so they fade with the palette
    /// rather than popping at a threshold.
    public var nightness: Double {
        let mix = blend
        let fromWeight = mix.from == .night ? 1.0 - mix.amount : 0.0
        let toWeight = mix.to == .night ? mix.amount : 0.0
        return fromWeight + toWeight
    }

    /// C²-continuous ease — zero first and second derivatives at both
    /// ends, so token values glide into and out of transitions.
    static func smootherstep(_ x: Double) -> Double {
        let t = max(0.0, min(1.0, x))
        return t * t * t * (t * (t * 6 - 15) + 10)
    }
}
