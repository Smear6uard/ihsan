import Foundation

/// A span of the day inside which one remembrance set is offered.
///
/// Windows are the whole shape of this feature. A set exists during its
/// window and nowhere else — there is no list to open, no search, no
/// way to reach the evening adhkar at nine in the morning. That is not
/// a restriction bolted on; it is what "the day's remembrance" means.
public struct AdhkarWindow: Sendable, Hashable {
    public let start: Date
    public let end: Date

    public var interval: DateInterval {
        DateInterval(start: start, end: end)
    }

    public func contains(_ date: Date) -> Bool {
        date >= start && date < end
    }

    /// Returns nil rather than an inverted or empty span. At extreme
    /// latitudes the solar events can collapse into each other, and a
    /// window with no duration must be no window at all — a card that
    /// appears and vanishes in the same second is worse than no card.
    public init?(start: Date, end: Date) {
        guard start < end else { return nil }
        self.start = start
        self.end = end
    }
}

/// Where each set's window falls, given the day's real solar events.
///
/// Every bound here is derived from prayer times, never from a clock
/// hour, exactly like the rest of the app. The two settable offsets
/// carry the places the schools differ; both defaults sit between the
/// positions rather than taking one.
public enum AdhkarWindowResolver {

    /// Fajr until some way past sunrise.
    ///
    /// The morning remembrance belongs to the first part of the day.
    /// Where that part ends is disputed — at sunrise for some, into
    /// mid-morning for others — so the end is an offset past sunrise
    /// that the person sets. It is clamped at Dhuhr regardless: past
    /// noon it is no longer morning by any reckoning, and on a
    /// compressed high-latitude day a generous offset would otherwise
    /// run the morning card into the afternoon.
    public static func morning(
        fajr: Date,
        sunrise: Date,
        dhuhr: Date,
        endsAfterSunrise: TimeInterval
    ) -> AdhkarWindow? {
        let end = min(sunrise.addingTimeInterval(max(0, endsAfterSunrise)), dhuhr)
        return AdhkarWindow(start: fajr, end: end)
    }

    /// Maghrib into the early night.
    ///
    /// The product's time-of-day surface follows the visible turn into
    /// evening, not a coarse afternoon clock bucket. It therefore does
    /// not expose the evening set at 4 PM simply because ʿAṣr has begun.
    /// The end is clamped at ʿIshāʾ so the evening and sleep sets never
    /// compete for the same moment.
    public static func evening(
        maghrib: Date,
        isha: Date,
        extendsAfterMaghrib: TimeInterval
    ) -> AdhkarWindow? {
        let end = min(maghrib.addingTimeInterval(max(0, extendsAfterMaghrib)), isha)
        return AdhkarWindow(start: maghrib, end: end)
    }

    /// ʿIshāʾ until the coming Fajr.
    ///
    /// Time is only half of this one: the surface additionally waits
    /// for ʿIshāʾ to be logged, because the sleep remembrance follows
    /// the prayer rather than the hour.
    public static func sleep(isha: Date, nextFajr: Date) -> AdhkarWindow? {
        AdhkarWindow(start: isha, end: nextFajr)
    }
}
