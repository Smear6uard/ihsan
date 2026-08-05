import Foundation
import Synchronization

/// The process-wide Hijri display facts: the user's moonsighting
/// adjustment, and the evening boundaries the Hijri day actually turns
/// on. Published once from the settings row and the resolved schedule,
/// read by every surface that formats a Hijri date. Mirrors the
/// `IhsanPageChrome` publication pattern — one source, no per-view
/// plumbing, and inert defaults for extension processes that never
/// publish.
public enum HijriDisplay {

    /// The Maghrib of one civil day. The Hijri day begins here, not at
    /// midnight, so this is the instant a Hijri date turns over.
    ///
    /// Boundaries travel as data rather than as a resolver closure
    /// because only a handful of days can ever be known: the app
    /// republishes today and its neighbours whenever the day resolves,
    /// and a day with no published boundary tabulates civilly. That
    /// fallback is exactly right for the case it covers — a historical
    /// date is passed as a day START, and a day start is never at or
    /// past its own Maghrib.
    public struct EveningBoundary: Sendable, Equatable {
        public let civilDayStart: Date
        public let maghrib: Date

        public init(civilDayStart: Date, maghrib: Date) {
            self.civilDayStart = civilDayStart
            self.maghrib = maghrib
        }
    }

    private struct Facts: Sendable {
        var offsetDays: Int = 0
        var eveningBoundaries: [EveningBoundary] = []
        var timeZoneIdentifier: String?
    }

    private static let facts = Mutex(Facts())

    /// The current adjustment in days, clamped to the supported ±2.
    public static var offsetDays: Int {
        facts.withLock { $0.offsetDays }
    }

    /// Publish the user's adjustment (on launch and on change).
    public static func publish(offsetDays: Int) {
        let clamped = max(
            HijriConverter.offsetRange.lowerBound,
            min(HijriConverter.offsetRange.upperBound, offsetDays)
        )
        facts.withLock { $0.offsetDays = clamped }
    }

    /// Publish the evening boundaries for the days now in view, in the
    /// place's timezone. Replaces whatever was published before — a
    /// stale boundary would turn a date on the wrong sunset.
    public static func publish(
        eveningBoundaries: [EveningBoundary],
        timeZone: TimeZone
    ) {
        facts.withLock {
            $0.eveningBoundaries = eveningBoundaries
            $0.timeZoneIdentifier = timeZone.identifier
        }
    }

    /// The place's timezone, as published beside the boundaries. Every
    /// surface that formats "the Hijri date now" should resolve it in
    /// this zone: the turn is a fact about where the sun set, not
    /// about where the device thinks it is.
    public static var timeZone: TimeZone? {
        facts.withLock { $0.timeZoneIdentifier }.flatMap(TimeZone.init(identifier:))
    }

    /// The Maghrib of the civil day containing `date`, when it is
    /// known. `nil` means no boundary was published for that day and
    /// the caller tabulates civilly.
    ///
    /// `zone` must agree with the published one. A turn decided in one
    /// timezone and tabulated in another lands a day out — the anchor
    /// steps forward from an evening the second calendar has already
    /// counted — so a disagreement declines to turn rather than
    /// guessing.
    public static func maghrib(forCivilDayOf date: Date, in zone: TimeZone? = nil) -> Date? {
        let (boundaries, timeZoneIdentifier) = facts.withLock {
            ($0.eveningBoundaries, $0.timeZoneIdentifier)
        }
        guard
            !boundaries.isEmpty,
            let identifier = timeZoneIdentifier,
            let timeZone = TimeZone(identifier: identifier)
        else { return nil }
        if let zone, zone.secondsFromGMT(for: date) != timeZone.secondsFromGMT(for: date) {
            return nil
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return boundaries.first {
            calendar.isDate($0.civilDayStart, inSameDayAs: date)
        }?.maghrib
    }

    /// Drop every published boundary. Tests call this so one suite's
    /// evening cannot leak into another's.
    public static func clearEveningBoundaries() {
        facts.withLock {
            $0.eveningBoundaries = []
            $0.timeZoneIdentifier = nil
        }
    }
}
