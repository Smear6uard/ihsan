import Foundation

/// The divided night: today's Maghrib to tomorrow's true Fajr, split by pure
/// interval arithmetic on absolute instants. This is the established,
/// school-neutral computation — nisf al-layl is the midpoint of that span
/// (Islamic midnight, deliberately not clock midnight), and the thirds divide
/// it into three equal parts sharing exact boundary instants.
///
/// Because every value is an absolute UTC instant, DST transitions inside the
/// night and high-latitude compression need no special casing here: whenever
/// the fard times are resolvable under the user's high-latitude rule, this
/// division is too. Format at the UI layer in the user's timezone.
public struct NightIntervals: Sendable, Hashable {
    /// Today's Maghrib — the night begins.
    public let start: Date
    /// Tomorrow's true Fajr — the night ends.
    public let end: Date
    /// The exact midpoint of the night span.
    public let nisfAlLayl: Date
    public let firstThird: DateInterval
    public let middleThird: DateInterval
    public let lastThird: DateInterval

    /// Total night duration in seconds.
    public var span: TimeInterval {
        end.timeIntervalSince(start)
    }

    /// Start of the last third of the night.
    public var lastThirdStart: Date {
        lastThird.start
    }

    public init(maghrib: Date, nextFajr: Date) throws {
        guard nextFajr > maghrib else {
            throw PrayerTimesError.invalidDate(
                "Night requires Fajr (\(nextFajr)) to follow Maghrib (\(maghrib))."
            )
        }

        let span = nextFajr.timeIntervalSince(maghrib)
        // Boundary instants are computed once and shared between adjacent
        // intervals so the thirds partition the span with no float drift.
        let firstBoundary = maghrib.addingTimeInterval(span / 3)
        let secondBoundary = maghrib.addingTimeInterval(span * 2 / 3)

        self.start = maghrib
        self.end = nextFajr
        self.nisfAlLayl = maghrib.addingTimeInterval(span / 2)
        self.firstThird = DateInterval(start: maghrib, end: firstBoundary)
        self.middleThird = DateInterval(start: firstBoundary, end: secondBoundary)
        self.lastThird = DateInterval(start: secondBoundary, end: nextFajr)
    }
}

/// The forenoon window for duha: sunrise plus an offset until Dhuhr minus a
/// margin. Schools differ on both edges, so the offsets are parameters; the
/// 20-minute / 15-minute defaults are common, neutral choices, not a ruling.
public struct DuhaWindow: Sendable, Hashable {
    public let start: Date
    public let end: Date

    public var interval: DateInterval {
        DateInterval(start: start, end: end)
    }

    /// Returns nil when the offsets consume the whole forenoon (compressed
    /// high-latitude days) — no window rather than an inverted one.
    public init?(
        sunrise: Date,
        dhuhr: Date,
        sunriseOffset: TimeInterval = 20 * 60,
        dhuhrMargin: TimeInterval = 15 * 60
    ) {
        let start = sunrise.addingTimeInterval(sunriseOffset)
        let end = dhuhr.addingTimeInterval(-dhuhrMargin)
        guard start < end else { return nil }
        self.start = start
        self.end = end
    }
}
