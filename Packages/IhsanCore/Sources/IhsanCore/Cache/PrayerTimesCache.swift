import Foundation

/// Lightweight App-Group cache for the day's prayer schedule.
///
/// Writers (the host iOS app, the watchOS app) call `write(_:)` every
/// time they recompute the day's prayer times. Readers (watchOS
/// complication timeline providers, share extensions) call
/// `read()` to avoid spinning up CoreLocation on a tight extension
/// budget.
///
/// This persists *derived* data only — the exact resolver boundaries,
/// place timezone/city, and qibla bearing. Coordinates are NOT cached;
/// the privacy contract on `LocatedPlace` forbids persisting raw
/// location to UserDefaults or any storage.
public struct PrayerTimesCache: Codable, Sendable, Equatable {
    public struct Entry: Codable, Sendable, Equatable {
        public let prayerRaw: String
        public let scheduledTime: Date

        public init(prayerRaw: String, scheduledTime: Date) {
            self.prayerRaw = prayerRaw
            self.scheduledTime = scheduledTime
        }
    }

    /// Civil date the cache is for, expressed as start-of-day in
    /// `timeZoneIdentifier`. Used by readers to detect rollover.
    public let date: Date
    public let timeZoneIdentifier: String
    public let cityName: String?
    public let qiblaBearingDegrees: Double?
    public let entries: [Entry]
    /// Adjacent and solar boundaries required by the shared prayer
    /// state resolver. Optional so an older on-device v1 payload
    /// decodes safely and is treated as stale by new readers.
    public let previousDayIsha: Date?
    public let sunrise: Date?
    public let nextDayFajr: Date?
    /// The previous day's five, so the cache spans two whole prayer
    /// cycles rather than one day plus its edges.
    ///
    /// Before dawn the cycle in progress is the previous day's, and a
    /// record written then has to name that day AND be measured against
    /// that day's window. Coordinates are never persisted, so a caller
    /// with no place in hand has only this cache to ask — and asking it
    /// about yesterday used to get today's answer.
    public let previousDayEntries: [Entry]?
    public let writtenAt: Date

    public init(
        date: Date,
        timeZoneIdentifier: String,
        cityName: String?,
        qiblaBearingDegrees: Double? = nil,
        entries: [Entry],
        previousDayIsha: Date? = nil,
        sunrise: Date? = nil,
        nextDayFajr: Date?,
        previousDayEntries: [Entry]? = nil,
        writtenAt: Date = .now
    ) {
        self.date = date
        self.timeZoneIdentifier = timeZoneIdentifier
        self.cityName = cityName
        self.qiblaBearingDegrees = qiblaBearingDegrees
        self.entries = entries
        self.previousDayIsha = previousDayIsha
        self.sunrise = sunrise
        self.nextDayFajr = nextDayFajr
        self.previousDayEntries = previousDayEntries
        self.writtenAt = writtenAt
    }
}

public enum PrayerTimesCacheStore {
    public static let suiteName = IhsanModelContainerFactory.appGroupIdentifier
    public static let key = "ihsan.prayer-times-cache.v1"

    public static func write(_ cache: PrayerTimesCache) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        guard let data = try? JSONEncoder().encode(cache) else { return }
        defaults.set(data, forKey: key)
    }

    public static func read() -> PrayerTimesCache? {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return nil }
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(PrayerTimesCache.self, from: data)
    }

    public static func clear() {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        defaults.removeObject(forKey: key)
    }
}
