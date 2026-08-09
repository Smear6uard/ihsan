import Foundation

/// Pure resolution of an entered iqamah against a computed adhan.
///
/// No clock is read here and no state is held: callers hand in the adhan
/// instant and the place's timezone and get back an absolute instant to
/// format at the UI layer.
public enum IqamahSchedule {

    /// The iqamah instant for one entry, or nil when none is recorded.
    public static func resolve(
        entry: IqamahEntry,
        adhan: Date,
        timeZone: TimeZone
    ) -> Date? {
        switch entry.mode {
        case .none:
            return nil
        case .offset:
            guard let minutes = entry.offsetMinutes else { return nil }
            return adhan.addingTimeInterval(TimeInterval(minutes * 60))
        case .fixed:
            guard let minutes = entry.fixedMinutesFromMidnight else { return nil }
            return resolveFixed(
                minutesFromMidnight: minutes, onOrAfter: adhan, timeZone: timeZone
            )
        }
    }

    /// The first occurrence of a wall-clock time at or after `adhan`, within
    /// twenty-four hours.
    ///
    /// This is the definition, not a correction heuristic: an iqamah follows
    /// its adhan. Resolving on the adhan's *civil day* instead breaks
    /// wherever the iqamah crosses midnight — at 60°N in June an Isha adhan
    /// at 22:30 with a board time of 00:15 would land twenty-two hours
    /// BEFORE its own adhan.
    ///
    /// Searching forward day by day, rather than computing one candidate and
    /// nudging it, also disposes of both DST cases for free: a wall time
    /// inside a spring-forward gap simply has no match on that day and the
    /// next day's occurrence is returned, and a repeated hour resolves to
    /// the first of its two instants, which is the one the board means.
    public static func resolveFixed(
        minutesFromMidnight: Int,
        onOrAfter adhan: Date,
        timeZone: TimeZone
    ) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let hour = minutesFromMidnight / 60
        let minute = minutesFromMidnight % 60

        // The adhan's own civil day, then the two that follow. Three is
        // enough for any real timezone: a wall time missing on one day
        // (a spring-forward gap) exists on the next.
        for dayOffset in 0...2 {
            guard
                let day = calendar.date(byAdding: .day, value: dayOffset, to: adhan),
                let candidate = calendar.date(
                    bySettingHour: hour,
                    minute: minute,
                    second: 0,
                    of: day,
                    matchingPolicy: .nextTime,
                    repeatedTimePolicy: .first,
                    direction: .forward
                )
            else { continue }

            if candidate >= adhan, candidate.timeIntervalSince(adhan) < 24 * 3600 {
                return candidate
            }
        }
        return nil
    }

    // MARK: - Storage

    /// Sorted keys so the stored payload is byte-stable across processes.
    /// Tests still compare decoded values, never this string.
    public static func encode(_ entries: [IqamahEntry]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(entries),
              let json = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return json
    }

    public static func decode(_ json: String) -> [IqamahEntry] {
        guard let data = json.data(using: .utf8),
              let entries = try? JSONDecoder().decode([IqamahEntry].self, from: data)
        else {
            return []
        }
        return entries
    }

    /// One unset entry per prayer, in the day's own order.
    public static var empty: [IqamahEntry] {
        Prayer.allCases.map { IqamahEntry(prayer: $0) }
    }
}
