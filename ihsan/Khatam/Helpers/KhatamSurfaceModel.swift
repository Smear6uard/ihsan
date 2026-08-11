import Foundation
import IhsanCore

nonisolated struct KhatamPrayerOffer: Equatable, Sendable {
    let count: Int
    let unit: KhatamUnit

    var inscription: String {
        KhatamSurfaceModel.unitLine(count, unit: unit).uppercased()
    }
}

enum KhatamSurfaceModel {
    static func activePlan(in plans: [KhatamPlan]) -> KhatamPlan? {
        plans.first(where: \.isActive)
    }

    static func entries(for plan: KhatamPlan, from entries: [KhatamEntry]) -> [KhatamEntry] {
        entries.filter { $0.planID == plan.id }
    }

    static func pace(
        for plan: KhatamPlan,
        entries: [KhatamEntry],
        pauses: [PauseInterval],
        today: Date,
        calendar: Calendar = .current
    ) -> KhatamPace {
        KhatamPacing.resolve(
            plan: KhatamPacingPlan(
                plan: plan,
                pauses: pauses,
                through: today,
                calendar: calendar
            ),
            entries: self.entries(for: plan, from: entries).map(KhatamPacingEntry.init),
            today: today,
            calendar: calendar
        )
    }

    static func totalRead(for plan: KhatamPlan, entries: [KhatamEntry]) -> Int {
        self.entries(for: plan, from: entries).reduce(0) { $0 + $1.unitsRead }
    }

    static func readToday(
        for plan: KhatamPlan,
        entries: [KhatamEntry],
        today: Date,
        calendar: Calendar = .current
    ) -> Int {
        let day = calendar.startOfDay(for: today)
        return self.entries(for: plan, from: entries)
            .filter { calendar.isDate($0.entryDate, inSameDayAs: day) }
            .reduce(0) { $0 + $1.unitsRead }
    }

    static func isPaused(
        on date: Date,
        pauses: [PauseInterval],
        calendar: Calendar = .current
    ) -> Bool {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return pauses.contains {
            $0.startDate < end && ($0.endDate ?? .distantFuture) > start
        }
    }

    static func forecastInscription(
        _ date: Date,
        offsetDays: Int,
        timeZone: TimeZone = .current
    ) -> String {
        let hijri = HijriConverter.components(
            for: date,
            offsetDays: offsetDays,
            timeZone: timeZone
        )
        if hijri.month == RamadanContext.ramadanMonth {
            return "AT YOUR PACE · BY RAMADAN \(hijri.day)"
        }
        return "AT YOUR PACE · BY \(date.formatted(.dateTime.month(.abbreviated).day()).uppercased())"
    }

    nonisolated static func unitLine(_ count: Int, unit: KhatamUnit) -> String {
        let label = count == 1 ? unit.singularLabel : unit.pluralLabel
        return "\(count.formatted()) \(label)"
    }

    /// The focused-card offer is presence-following-purpose: one quiet
    /// amount while today's intention is still open, and nothing once it
    /// has been met. A pause suppresses the offer only; the detail screen's
    /// logging door remains available.
    static func prayerOffer(
        for plan: KhatamPlan,
        entries: [KhatamEntry],
        pauses: [PauseInterval],
        today: Date,
        calendar: Calendar = .current
    ) -> KhatamPrayerOffer? {
        guard plan.isActive, !isPaused(on: today, pauses: pauses, calendar: calendar) else {
            return nil
        }
        let pace = pace(
            for: plan,
            entries: entries,
            pauses: pauses,
            today: today,
            calendar: calendar
        )
        let read = readToday(
            for: plan,
            entries: entries,
            today: today,
            calendar: calendar
        )
        guard pace.perPrayerSuggestion > 0, read < pace.suggestedToday else {
            return nil
        }
        return KhatamPrayerOffer(count: pace.perPrayerSuggestion, unit: plan.unit)
    }
}
