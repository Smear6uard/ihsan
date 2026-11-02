import Foundation
import IhsanCore

/// The only data allowed to cross into the share renderer.
///
/// Pause metadata does not merely receive a different visual treatment:
/// it is removed here, before SwiftUI sees the export. A pause-covered
/// day becomes the same blank value as an ordinary day with no records,
/// and presence/travel facts on that day are withheld with it.
struct PatternExportContent: Sendable {
    let days: [DayCompletion]
    let naflDays: Set<Date>?
    let dhikrDays: Set<Date>?
    let recordBegan: Date?
    let tally: PathTally
}

enum PatternExportPrivacy {
    static func prepare(
        days: [DayCompletion],
        naflDays: Set<Date>?,
        dhikrDays: Set<Date>?,
        recordBegan: Date? = nil,
        calendar: Calendar = .current
    ) -> PatternExportContent {
        let pausedDates = Set(
            days.filter(\.isPaused).map { calendar.startOfDay(for: $0.date) }
        )

        let flattenedDays = days.map { day in
            guard day.isPaused else { return day }
            return DayCompletion(
                id: day.id,
                date: day.date,
                prayerCompletions: Prayer.allCases.map {
                    PrayerCompletion(prayer: $0, status: nil, withJamaah: false)
                },
                isPaused: false,
                isTraveling: false,
                needsReview: false
            )
        }

        return PatternExportContent(
            days: flattenedDays,
            naflDays: removing(pausedDates, from: naflDays, calendar: calendar),
            dhikrDays: removing(pausedDates, from: dhikrDays, calendar: calendar),
            recordBegan: recordBegan,
            // Counted from the flattened days, not the aggregate: a
            // paused day is a blank here, in the count as in the marks,
            // and nothing in the image can tell the two apart.
            tally: PathTally(days: flattenedDays, recordBegan: recordBegan)
        )
    }

    private static func removing(
        _ privateDates: Set<Date>,
        from dates: Set<Date>?,
        calendar: Calendar
    ) -> Set<Date>? {
        dates.map { source in
            Set(source.filter { !privateDates.contains(calendar.startOfDay(for: $0)) })
        }
    }
}
