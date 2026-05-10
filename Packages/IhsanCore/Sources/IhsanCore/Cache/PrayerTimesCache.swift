import Foundation

/// Lightweight App-Group cache for the day's prayer schedule.
///
/// Writers (the host iOS app, the watchOS app) call `write(_:)` every
/// time they recompute the day's prayer times. Readers (watchOS
/// complication timeline providers, share extensions) call
/// `read()` to avoid spinning up CoreLocation on a tight extension
/// budget.
///
/// This persists *derived* data only — the five `Date`s that prayer
/// fall at today, plus the city name. Coordinates are NOT cached;
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
    public let entries: [Entry]
    public let nextDayFajr: Date?
    public let writtenAt: Date

    public init(
        date: Date,
        timeZoneIdentifier: String,
        cityName: String?,
        entries: [Entry],
        nextDayFajr: Date?,
        writtenAt: Date = .now
    ) {
        self.date = date
        self.timeZoneIdentifier = timeZoneIdentifier
        self.cityName = cityName
        self.entries = entries
        self.nextDayFajr = nextDayFajr
        self.writtenAt = writtenAt
    }
}

public enum PrayerTimesCacheStore {
    public static let suiteName = "group.com.sameerstudios.ihsan"
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
