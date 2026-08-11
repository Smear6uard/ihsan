import Foundation

/// Immutable inputs keep pacing deterministic, Sendable, and independent
/// of SwiftData observation or a particular screen.
public struct KhatamPacingPlan: Sendable, Equatable {
    public let id: UUID
    public let startDate: Date
    public let endDate: Date
    public let targetUnits: Int
    public let excusedDates: Set<Date>

    public init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date,
        targetUnits: Int,
        excusedDates: Set<Date> = []
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.targetUnits = max(1, targetUnits)
        self.excusedDates = excusedDates
    }
}

public struct KhatamPacingEntry: Sendable, Equatable {
    public let date: Date
    public let unitsRead: Int

    public init(date: Date, unitsRead: Int) {
        self.date = date
        self.unitsRead = max(0, unitsRead)
    }
}

public struct KhatamPace: Sendable, Equatable {
    public let remaining: Int
    public let suggestedToday: Int
    public let perPrayerSuggestion: Int
    public let forecastCompletionDate: Date?
    public let hasRecentPace: Bool

    public init(
        remaining: Int,
        suggestedToday: Int,
        perPrayerSuggestion: Int,
        forecastCompletionDate: Date?,
        hasRecentPace: Bool
    ) {
        self.remaining = remaining
        self.suggestedToday = suggestedToday
        self.perPrayerSuggestion = perPrayerSuggestion
        self.forecastCompletionDate = forecastCompletionDate
        self.hasRecentPace = hasRecentPace
    }
}

public enum KhatamPacing {
    /// Recent pace uses at most fourteen elapsed, unpaused civil days. That
    /// is long enough to be steady while still answering a changed rhythm.
    public static let recentDayWindow = 14

    public static func resolve(
        plan: KhatamPacingPlan,
        entries: [KhatamPacingEntry],
        today: Date,
        calendar: Calendar = .current
    ) -> KhatamPace {
        let day = calendar.startOfDay(for: today)
        let start = calendar.startOfDay(for: plan.startDate)
        let end = calendar.startOfDay(for: max(plan.startDate, plan.endDate))
        let excused = Set(plan.excusedDates.map(calendar.startOfDay(for:)))
        let relevantEntries = entries.filter {
            let entryDay = calendar.startOfDay(for: $0.date)
            return entryDay >= start && entryDay <= day
        }
        let read = relevantEntries.reduce(0) { $0 + $1.unitsRead }
        let remaining = max(0, plan.targetUnits - read)

        guard remaining > 0 else {
            return KhatamPace(
                remaining: 0,
                suggestedToday: 0,
                perPrayerSuggestion: 0,
                forecastCompletionDate: day,
                hasRecentPace: true
            )
        }

        let allPlanDays = activeDayCount(
            from: start, through: end, excluding: excused, calendar: calendar
        )
        let evenSplit = roundedUp(plan.targetUnits, by: max(1, allPlanDays))
        let isExcusedToday = excused.contains(day)

        let suggestion: Int
        if isExcusedToday || day < start {
            suggestion = 0
        } else if day <= end {
            let remainingDays = activeDayCount(
                from: day, through: end, excluding: excused, calendar: calendar
            )
            suggestion = min(
                remaining,
                max(evenSplit, roundedUp(remaining, by: max(1, remainingDays)))
            )
        } else {
            // The calendar may end; the plan does not. Preserve its original
            // humane cadence and let the factual forecast extend naturally.
            suggestion = min(remaining, evenSplit)
        }

        let recentStartCandidate = calendar.date(
            byAdding: .day, value: -(recentDayWindow - 1), to: day
        ) ?? day
        let recentStart = max(start, recentStartCandidate)
        let recentActiveDays = activeDayCount(
            from: recentStart, through: day, excluding: excused, calendar: calendar
        )
        let recentUnits = relevantEntries.reduce(into: 0) { sum, entry in
            let entryDay = calendar.startOfDay(for: entry.date)
            if entryDay >= recentStart && !excused.contains(entryDay) {
                sum += entry.unitsRead
            }
        }

        let forecast: Date?
        if recentActiveDays > 0, recentUnits > 0 {
            let pace = Double(recentUnits) / Double(recentActiveDays)
            let daysNeeded = max(1, Int(ceil(Double(remaining) / pace)))
            forecast = addingActiveDays(
                // Today's recorded units already contributed to the pace
                // and were removed from `remaining`; every needed day is
                // therefore a future active day.
                daysNeeded, from: day, excluding: excused, calendar: calendar
            )
        } else {
            forecast = nil
        }

        return KhatamPace(
            remaining: remaining,
            suggestedToday: suggestion,
            // This is an invitation around the five prayers, not five
            // mandatory equal installments. Nearest rounding preserves the
            // familiar 604 / 30 ≈ 20 / day ≈ 4 after each prayer arithmetic;
            // any remainder stays inside the day's flexible total.
            perPrayerSuggestion: suggestion == 0
                ? 0
                : max(1, Int((Double(suggestion) / 5).rounded())),
            forecastCompletionDate: forecast,
            hasRecentPace: forecast != nil
        )
    }

    private static func roundedUp(_ numerator: Int, by denominator: Int) -> Int {
        (numerator + denominator - 1) / denominator
    }

    private static func activeDayCount(
        from start: Date,
        through end: Date,
        excluding excused: Set<Date>,
        calendar: Calendar
    ) -> Int {
        guard start <= end else { return 0 }
        var count = 0
        var cursor = start
        while cursor <= end {
            if !excused.contains(cursor) { count += 1 }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return count
    }

    private static func addingActiveDays(
        _ count: Int,
        from start: Date,
        excluding excused: Set<Date>,
        calendar: Calendar
    ) -> Date {
        guard count > 0 else { return start }
        var remaining = count
        var cursor = start
        while remaining > 0 {
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
            if !excused.contains(cursor) { remaining -= 1 }
        }
        return cursor
    }
}

public extension KhatamPacingPlan {
    init(
        plan: KhatamPlan,
        pauses: [PauseInterval],
        through date: Date = .now,
        calendar: Calendar = .current
    ) {
        let start = calendar.startOfDay(for: plan.startDate)
        let end = calendar.startOfDay(for: max(max(plan.startDate, plan.endDate), date))
        var dates = Set<Date>()
        var cursor = start
        while cursor <= end {
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor
            if pauses.contains(where: {
                $0.startDate < dayEnd && ($0.endDate ?? .distantFuture) > cursor
            }) {
                dates.insert(cursor)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        self.init(
            id: plan.id,
            startDate: plan.startDate,
            endDate: plan.endDate,
            targetUnits: plan.targetUnits,
            excusedDates: dates
        )
    }
}

public extension KhatamPacingEntry {
    init(_ entry: KhatamEntry) {
        self.init(date: entry.entryDate, unitsRead: entry.unitsRead)
    }
}
