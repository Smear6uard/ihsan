import Foundation

// MARK: - Clock 1 from the shared schedule cache

public extension PrayerTimesCache {

    var fajr: Date? {
        Self.time(of: .fajr, in: entries)
    }

    var previousDayFajr: Date? {
        previousDayEntries.flatMap { Self.time(of: .fajr, in: $0) }
    }

    private static func time(of prayer: Prayer, in entries: [Entry]) -> Date? {
        entries.first { $0.prayerRaw == prayer.rawValue }?.scheduledTime
    }

    /// The prayer cycle containing `instant`, from the two cycles this
    /// cache spans.
    ///
    /// A cycle is `[fajr, nextFajr)` — the containment test IS the
    /// cycle, so it needs no reasoning about which civil day the
    /// instant fell on. That is why a cache written last night still
    /// answers correctly at 1 AM, which is exactly the hour the
    /// midnight boundary got wrong.
    func cycle(at instant: Date) -> PrayerCycle? {
        guard let fajr else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        if let timeZone = TimeZone(identifier: timeZoneIdentifier) {
            calendar.timeZone = timeZone
        }

        if let nextDayFajr, instant >= fajr, instant < nextDayFajr {
            return PrayerCycle(date: calendar.startOfDay(for: fajr), rollsAt: nextDayFajr)
        }
        if let previousDayFajr, instant >= previousDayFajr, instant < fajr {
            return PrayerCycle(date: calendar.startOfDay(for: previousDayFajr), rollsAt: fajr)
        }
        return nil
    }

    /// The five of the cycle containing `instant`.
    func cycleEntries(at instant: Date) -> [Entry]? {
        guard let fajr else { return nil }
        if let nextDayFajr, instant >= fajr, instant < nextDayFajr {
            return entries
        }
        if let previousDayEntries, let previousDayFajr,
           instant >= previousDayFajr, instant < fajr {
            return previousDayEntries
        }
        return nil
    }

    /// When `prayer`'s window opened in the cycle containing `instant`.
    func scheduledTime(for prayer: Prayer, at instant: Date) -> Date? {
        cycleEntries(at: instant).flatMap { Self.time(of: prayer, in: $0) }
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
    /// schedule, or when a cache has gone stale by more than a cycle.
    /// It is the old behaviour, kept as a floor rather than as a rule:
    /// a record has to land on some day, and inventing a Fajr would be
    /// worse than naming the civil one.
    static func sharedCycleDate(
        at instant: Date,
        calendar: Calendar = .current,
        cache: PrayerTimesCache? = PrayerTimesCacheStore.read()
    ) -> Date {
        sharedCycle(at: instant, cache: cache)?.date ?? calendar.startOfDay(for: instant)
    }
}
