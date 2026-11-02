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

    /// The period's name, as the selector says it.
    var title: String {
        switch self {
        case .sevenDays: return "7 days"
        case .thirtyDays: return "30 days"
        case .ninetyDays: return "90 days"
        case .year: return "Year"
        }
    }

    /// The same, as a phrase: "Last 30 days".
    var phrase: String {
        self == .year ? "Last year" : "Last \(title)"
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

    /// "Apr 9 – May 9, 2026" — the screen's subtitle.
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
        // A window that crosses New Year, and every year-long one, has
        // two years in it: "Jul 31 – Jul 30, 2026" reads as nonsense.
        guard calendar.component(.year, from: start) == calendar.component(.year, from: end) else {
            return "\(s), \(year.string(from: start)) – \(e), \(y)"
        }
        return "\(s) – \(e), \(y)"
    }
}
