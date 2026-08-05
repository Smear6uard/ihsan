import Foundation

// MARK: - Clock 1 from the shared schedule cache

public extension PrayerTimesCache {

    var fajr: Date? {
        entries.first { $0.prayerRaw == Prayer.fajr.rawValue }?.scheduledTime
    }

    func scheduledTime(for prayer: Prayer) -> Date? {
        entries.first { $0.prayerRaw == prayer.rawValue }?.scheduledTime
    }

    /// The prayer cycle this cache describes, when it contains
    /// `instant`.
    ///
    /// A cache entry IS one cycle: it holds a day's five prayers plus
    /// the Fajr that closes them. So the containment test is the cycle
    /// itself — `[fajr, nextDayFajr)` — and needs no reasoning about
    /// which civil day the instant fell on. A cache written yesterday
    /// still answers correctly at 1 AM, which is precisely the hour the
    /// midnight boundary got wrong.
    func cycle(at instant: Date) -> PrayerCycle? {
        guard let fajr, let nextDayFajr, instant >= fajr, instant < nextDayFajr else {
            return nil
        }
        var calendar = Calendar(identifier: .gregorian)
        if let timeZone = TimeZone(identifier: timeZoneIdentifier) {
            calendar.timeZone = timeZone
        }
        return PrayerCycle(date: calendar.startOfDay(for: fajr), rollsAt: nextDayFajr)
    }
}

public extension PrayerCycleClock {

    /// The cycle containing `instant` according to the App Group
    /// schedule cache, or `nil` when no cached schedule covers it.
    ///
    /// This is how surfaces with no coordinates in hand — the intent
    /// funnel, the remembrance sheets, a makeup entry — still key their
    /// records to the prayer cycle. Coordinates are never persisted, so
    /// the cache's derived boundaries are the only schedule those
    /// callers can have, and they are exact.
    static func sharedCycle(
        at instant: Date,
        cache: PrayerTimesCache? = PrayerTimesCacheStore.read()
    ) -> PrayerCycle? {
        cache?.cycle(at: instant)
    }

    /// The cycle date for `instant`, falling back to the civil day when
    /// no cached schedule covers it.
    ///
    /// The fallback is reached only before a device has ever resolved a
    /// schedule, or when a cache has gone stale by more than a day. It
    /// is the old behaviour, kept as a floor rather than as a rule: a
    /// record has to land on some day, and inventing a Fajr would be
    /// worse than naming the civil one.
    static func sharedCycleDate(
        at instant: Date,
        calendar: Calendar = .current,
        cache: PrayerTimesCache? = PrayerTimesCacheStore.read()
    ) -> Date {
        sharedCycle(at: instant, cache: cache)?.date ?? calendar.startOfDay(for: instant)
    }
}
