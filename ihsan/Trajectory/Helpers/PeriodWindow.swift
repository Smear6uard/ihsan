import Foundation

/// Window options for the Trajectory screen. The day count is what feeds the
/// heatmap layout; the formatted range becomes the screen subtitle.
enum TrajectoryPeriod: CaseIterable, Identifiable, Hashable, Sendable {
    case sevenDays
    case thirtyDays
    case ninetyDays
    case year

    var id: Self { self }

    /// The range a capture run asked for, if any.
    static var debugStaged: TrajectoryPeriod? {
        switch DebugLaunch.value(after: "-IhsanDebugPeriod") {
        case "7":   return .sevenDays
        case "30":  return .thirtyDays
        case "90":  return .ninetyDays
        case "365": return .year
        default:    return nil
        }
    }

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

    /// Inclusive `[start, end]` window where `end` is the CYCLE in
    /// progress and `start` is `dayCount - 1` cycles earlier.
    ///
    /// Columns are cycles, not civil days: the rightmost one is the
    /// day whose Fajr has most recently opened, so at 1 AM the pattern
    /// still ends on the evening a person is standing in rather than
    /// sprouting an empty column for a day that has not begun.
    func window(
        cycleDate: Date,
        calendar: Calendar = .current
    ) -> (start: Date, end: Date) {
        let end = calendar.startOfDay(for: cycleDate)
        guard let start = calendar.date(
            byAdding: .day,
            value: -(dayCount - 1),
            to: end
        ) else {
            return (end, end)
        }
        return (start, end)
    }

    /// "APR 9 – MAY 9, 2026" — small caps, used as the screen subtitle.
    func formattedRange(
        cycleDate: Date,
        calendar: Calendar = .current
    ) -> String {
        let (start, end) = window(cycleDate: cycleDate, calendar: calendar)
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
