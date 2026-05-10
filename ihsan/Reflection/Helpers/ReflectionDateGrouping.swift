import Foundation
import IhsanCore

/// Groups reflection records into date-bucketed sections for the feed.
///
/// Buckets:
///   - "THIS WEEK"   for entries inside the current calendar week
///   - "LAST WEEK"   for entries inside the previous calendar week
///   - "<MONTH YEAR>" for everything older, grouped by calendar month
///     (e.g. "APRIL 2026")
///
/// The same calendar (`Calendar.current`) is used everywhere so a
/// reflection logged at 11:55 PM doesn't land in a different week from
/// one logged at 12:05 AM in the user's local rhythm.
enum ReflectionDateGrouping {
    struct Section: Identifiable, Equatable {
        let id: String
        let title: String
        let entries: [Reflection]
    }

    /// Returns sections in display order (THIS WEEK first, then LAST WEEK,
    /// then months descending).
    static func sections(
        from reflections: [Reflection],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [Section] {
        guard !reflections.isEmpty else { return [] }

        let sortedDescending = reflections.sorted {
            $0.createdAt > $1.createdAt
        }

        let thisWeekInterval = calendar.dateInterval(
            of: .weekOfYear,
            for: now
        )
        let lastWeekStart = calendar.date(
            byAdding: .weekOfYear,
            value: -1,
            to: thisWeekInterval?.start ?? now
        )
        let lastWeekInterval = lastWeekStart.flatMap {
            calendar.dateInterval(of: .weekOfYear, for: $0)
        }

        var thisWeek: [Reflection] = []
        var lastWeek: [Reflection] = []
        var older: [Reflection] = []

        for entry in sortedDescending {
            let when = entry.createdAt
            if let thisWeekInterval, thisWeekInterval.contains(when) {
                thisWeek.append(entry)
            } else if let lastWeekInterval, lastWeekInterval.contains(when) {
                lastWeek.append(entry)
            } else {
                older.append(entry)
            }
        }

        var sections: [Section] = []
        if !thisWeek.isEmpty {
            sections.append(.init(
                id: "this-week",
                title: "THIS WEEK",
                entries: thisWeek
            ))
        }
        if !lastWeek.isEmpty {
            sections.append(.init(
                id: "last-week",
                title: "LAST WEEK",
                entries: lastWeek
            ))
        }

        // Group `older` by year+month, descending.
        let monthGroups = Dictionary(grouping: older) { entry -> DateComponents in
            calendar.dateComponents([.year, .month], from: entry.createdAt)
        }
        let orderedMonthKeys = monthGroups.keys.sorted { lhs, rhs in
            (lhs.year ?? 0, lhs.month ?? 0) > (rhs.year ?? 0, rhs.month ?? 0)
        }
        for components in orderedMonthKeys {
            guard let entries = monthGroups[components], !entries.isEmpty else {
                continue
            }
            sections.append(.init(
                id: "month-\(components.year ?? 0)-\(components.month ?? 0)",
                title: monthTitle(for: components, calendar: calendar),
                entries: entries
            ))
        }

        return sections
    }

    private static func monthTitle(
        for components: DateComponents,
        calendar: Calendar
    ) -> String {
        var date = DateComponents()
        date.year = components.year
        date.month = components.month
        date.day = 1
        guard let resolved = calendar.date(from: date) else { return "" }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: resolved).uppercased()
    }
}
