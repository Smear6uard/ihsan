import Foundation

/// Window options for the Trajectory screen. The day count is what feeds the
/// heatmap layout; the formatted range becomes the screen subtitle.
enum TrajectoryPeriod: CaseIterable, Identifiable, Hashable, Sendable {
    case sevenDays
    case thirtyDays
    case ninetyDays
    case year

    var id: Self { self }

    var label: String {
        switch self {
        case .sevenDays: return "7D"
        case .thirtyDays: return "30D"
        case .ninetyDays: return "90D"
        case .year: return "Year"
        }
    }

    var dayCount: Int {
        switch self {
        case .sevenDays: return 7
        case .thirtyDays: return 30
        case .ninetyDays: return 90
        case .year: return 365
        }
    }

    /// Inclusive `[start, end]` window where `end` is the start of today and
    /// `start` is `dayCount - 1` days earlier.
    func window(
        now: Date = .now,
        calendar: Calendar = .current
    ) -> (start: Date, end: Date) {
        let endOfToday = calendar.startOfDay(for: now)
        guard let start = calendar.date(
            byAdding: .day,
            value: -(dayCount - 1),
            to: endOfToday
        ) else {
            return (endOfToday, endOfToday)
        }
        return (start, endOfToday)
    }

    /// "APR 9 – MAY 9, 2026" — small caps, used as the screen subtitle.
    func formattedRange(
        now: Date = .now,
        calendar: Calendar = .current
    ) -> String {
        let (start, end) = window(now: now, calendar: calendar)
        let monthDay = DateFormatter()
        monthDay.calendar = calendar
        monthDay.dateFormat = "MMM d"
        let year = DateFormatter()
        year.calendar = calendar
        year.dateFormat = "yyyy"
        let s = monthDay.string(from: start)
        let e = monthDay.string(from: end)
        let y = year.string(from: end)
        return "\(s) – \(e), \(y)"
    }
}
