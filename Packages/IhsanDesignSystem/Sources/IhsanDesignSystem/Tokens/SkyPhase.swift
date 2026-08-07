import Foundation

/// The five solar events that anchor the day's palette. The package
/// never computes prayer times — the caller (which already owns an
/// Adhan-derived schedule) supplies these, and everything downstream
/// resolves from them. Clock hours are never consulted.
public struct SolarDayEvents: Sendable, Equatable {

    /// Dawn twilight begins here, not at a clock hour. Not to be
    /// confused with `PaletteState.firstLight`, which is the chapter
    /// AFTER sunrise — the sun is still below the horizon at fajr.
    public var fajr: Date
    public var sunrise: Date
    public var solarNoon: Date
    public var maghrib: Date
    public var isha: Date

    public init(fajr: Date, sunrise: Date, solarNoon: Date, maghrib: Date, isha: Date) {
        self.fajr = fajr
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
/// 0.050  fajr              (night → dawn transition center)
/// 0.105  dawn heart        (plateau center)
/// 0.160  sunrise           (dawn → first light transition center)
/// 0.2275 first light       (plateau center)
/// 0.295  first light ends  (first light → morning transition center)
/// 0.3475 mid-morning       (plateau center)
/// 0.400  solar noon        (morning → afternoon transition center)
/// 0.525  mid-afternoon     (plateau center)
/// 0.650  maghrib           (afternoon → sunset transition center)
/// 0.7625 sunset heart      (plateau center)
/// 0.875  isha              (sunset → night transition center)
/// ```
///
/// `resolve(at:events:)` maps a real moment onto this scale by
/// piecewise-linear interpolation between the supplied solar events,
/// so the palette transitions always straddle the actual fajr /
/// sunrise / noon / maghrib / isha moments regardless of season or
/// latitude. Tokens are then continuous functions of `unit` (see
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

    /// Palette-space positions of the six anchors. Six states need six
    /// boundaries; every adjacent pair sits more than
    /// `2 * atmosphereHalfWidth` apart so no two transition bands
    /// overlap and every state keeps a genuine plateau.
    static let fajrUnit = 0.050
    static let sunriseUnit = 0.160
    /// The morning's mirror of isha: where the first-light chapter
    /// hands over to the settled morning. Derived from the schedule,
    /// not supplied — see `firstLightEnd(for:)`.
    static let firstLightEndUnit = 0.295
    static let solarNoonUnit = 0.400
    static let maghribUnit = 0.650
    static let ishaUnit = 0.875

    /// Chrome fallback for surfaces that have no solar schedule (a
    /// cold launch before any schedule resolves): maps the local
    /// clock onto palette space through fixed anchor hours — 4:45
    /// fajr, 6:00 sunrise, 7:15 first light's end (6:00 plus the 1:15
    /// dawn these anchors describe — the same mirror
    /// `firstLightEnd(for:)` derives), 13:00 solar noon, 19:00
    /// maghrib, 20:30 isha. Surfaces that DO know the day's real
    /// events must use `resolve(at:events:)`; secondary-page chrome
    /// rides the real events through
    /// `IhsanPageChrome.publish(_:)` and falls back
    /// here only before the first schedule arrives. This mapping is
    /// deliberately coarse, and only ever drives ground/panel tints —
    /// never the celestial plate.
    public static func approximate(
        at date: Date, timeZone: TimeZone = .current
    ) -> SkyPhase {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let midnight = calendar.startOfDay(for: date)
        let seconds = date.timeIntervalSince(midnight)

        // (hour anchor, palette unit), with the previous isha and the
        // next fajr wrapping the night exactly like resolve(at:).
        let anchors: [(time: TimeInterval, unit: Double)] = [
            (20.5 * 3600 - 86_400, ishaUnit - 1.0),
            (4.75 * 3600, fajrUnit),
            (6.0 * 3600, sunriseUnit),
            (7.25 * 3600, firstLightEndUnit),
            (13.0 * 3600, solarNoonUnit),
            (19.0 * 3600, maghribUnit),
            (20.5 * 3600, ishaUnit),
            (4.75 * 3600 + 86_400, fajrUnit + 1.0),
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

    /// Where the first-light chapter ends.
    ///
    /// The evening's sunset chapter is bounded by two real events —
    /// maghrib and isha. The morning has only one, so the closing
    /// anchor is derived: FIRST LIGHT LASTS AS LONG AS THE DAWN THAT
    /// PRECEDED IT. Both spans are governed by the same thing — how
    /// fast the sun's altitude changes at this latitude and season —
    /// so the mirror is astronomical, not arbitrary.
    ///
    /// Capped at 35% of the way to solar noon so a polar dawn, which
    /// can run for hours, cannot swallow the morning.
    static func firstLightEnd(for events: SolarDayEvents) -> Date {
        let dawnSpan = events.sunrise.timeIntervalSince(events.fajr)
        let toNoon = events.solarNoon.timeIntervalSince(events.sunrise)
        let span = min(max(dawnSpan, 0), max(toNoon, 0) * 0.35)
        return events.sunrise.addingTimeInterval(span)
    }

    /// Map a real moment onto palette space using the day's solar
    /// events. Times before fajr interpolate from the previous
    /// night's isha (approximated one day earlier); times after isha
    /// interpolate toward the next fajr (one day later). Degenerate
    /// event orderings (extreme-latitude schedules where a caller
    /// supplies near-coincident events) are guarded by a minimum
    /// segment length so the mapping stays monotonic and finite.
    public static func resolve(at date: Date, events: SolarDayEvents) -> SkyPhase {
        let day: TimeInterval = 86_400
        let minSegment: TimeInterval = 60

        // Control points as (time, palette unit), strictly increasing
        // in both coordinates. The night wraps: previous isha sits one
        // day before this day's, the next fajr one day after.
        var points: [(time: TimeInterval, unit: Double)] = []
        var cursor = events.isha.timeIntervalSinceReferenceDate - day
        points.append((cursor, ishaUnit - 1.0))

        for (time, unit) in [
            (events.fajr.timeIntervalSinceReferenceDate, fajrUnit),
            (events.sunrise.timeIntervalSinceReferenceDate, sunriseUnit),
            (firstLightEnd(for: events).timeIntervalSinceReferenceDate, firstLightEndUnit),
            (events.solarNoon.timeIntervalSinceReferenceDate, solarNoonUnit),
            (events.maghrib.timeIntervalSinceReferenceDate, maghribUnit),
            (events.isha.timeIntervalSinceReferenceDate, ishaUnit),
            (events.fajr.timeIntervalSinceReferenceDate + day, fajrUnit + 1.0)
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
        case .dawn: return SkyPhase(unit: 0.105)
        case .firstLight: return SkyPhase(unit: 0.2275)
        case .morning: return SkyPhase(unit: 0.3475)
        case .afternoon: return SkyPhase(unit: 0.525)
        case .sunset: return SkyPhase(unit: 0.7625)
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
        (SkyPhase.fajrUnit, .night, .dawn),
        (SkyPhase.sunriseUnit, .dawn, .firstLight),
        (SkyPhase.firstLightEndUnit, .firstLight, .morning),
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
        // Plateau — pick the state whose span contains the phase.
        switch u {
        case ..<Self.fajrUnit: return (.night, .night, 0)
        case ..<Self.sunriseUnit: return (.dawn, .dawn, 0)
        case ..<Self.firstLightEndUnit: return (.firstLight, .firstLight, 0)
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

    /// Legacy compatibility value. Text no longer draws a glyph outline;
    /// the palette and a restrained transition backing provide contrast.
    public var inkOutlineStrength: Double { 0 }

    /// The perceptually dominant state at this phase.
    public var dominantState: PaletteState {
        let mix = blend
        return mix.amount < 0.5 ? mix.from : mix.to
    }

    /// How "night" this phase is, `0...1` — drives the star field and
    /// other night-only atmospherics so they fade with the palette
    /// rather than popping at a threshold.
    ///
    /// Across the dawn passage the stars do not vanish with the
    /// night→dawn palette blend: they fade PROGRESSIVELY over the
    /// whole fajr→sunrise span, from full at the passage's start to
    /// gone as the sun crests — dawn twilight keeps its last stars.
    /// Outside that span the palette blend decides, exactly as
    /// before.
    public var nightness: Double {
        let hw = Self.atmosphereHalfWidth
        let dawnStart = Self.fajrUnit - hw
        let dawnEnd = Self.sunriseUnit + hw
        if unit >= dawnStart && unit <= dawnEnd {
            return 1.0 - Self.smootherstep((unit - dawnStart) / (dawnEnd - dawnStart))
        }
        let mix = blend
        let fromWeight = mix.from == .night ? 1.0 - mix.amount : 0.0
        let toWeight = mix.to == .night ? mix.amount : 0.0
        return fromWeight + toWeight
    }

    /// How strongly the dawn wash paints right now, `0...1` — 0 until
    /// fajr, growing to 1 as the sun crests at sunrise, then handing
    /// off to the risen sun's own bloom across the sunrise transition
    /// band. The sky view scales the pre-dawn horizon glow by this,
    /// so first light grows toward sunrise instead of arriving all at
    /// once.
    public var dawnProgress: Double {
        let hw = Self.atmosphereHalfWidth
        if unit >= Self.fajrUnit && unit <= Self.sunriseUnit {
            return Self.smootherstep(
                (unit - Self.fajrUnit) / (Self.sunriseUnit - Self.fajrUnit)
            )
        }
        if unit > Self.sunriseUnit && unit <= Self.sunriseUnit + hw {
            return 1.0 - Self.smootherstep((unit - Self.sunriseUnit) / hw)
        }
        return 0.0
    }

    /// C²-continuous ease — zero first and second derivatives at both
    /// ends, so token values glide into and out of transitions.
    static func smootherstep(_ x: Double) -> Double {
        let t = max(0.0, min(1.0, x))
        return t * t * t * (t * (t * 6 - 15) + 10)
    }
}
