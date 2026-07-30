import Foundation
import IhsanCore

/// Yesterday, and whether the app should mention it.
///
/// The most common real thing that happens is not a missed prayer — it
/// is a prayed prayer that never got logged, usually the whole of
/// yesterday. The retroactive path through Path's grid handles it, but
/// only for someone who already knows the path exists.
///
/// So the app offers. Once, quietly, about one day. Every rule below
/// exists to keep that offer from becoming a demand:
///
///   * **Yesterday only.** Never the day before, never a backlog.
///     Deeper history stays Path's job, where a person goes looking
///     rather than being met.
///   * **Silent.** It never fires a notification. It is a line on a
///     screen someone already opened.
///   * **Dismissible, and then gone.** Dismissed for the day; gone for
///     good once yesterday is fully accounted for.
///   * **Never during an excused pause.** A pause means the days did
///     not count. Asking about them afterwards would take that back.
enum YesterdayAccount {

    /// What the header should say, if anything.
    struct Offer: Equatable {
        /// The civil day being offered — always yesterday.
        let day: Date
        /// How many of the five have no log at all.
        let unloggedCount: Int

        /// "YESTERDAY · 3 UNLOGGED". Singular when it is one, because
        /// "1 UNLOGGED" reads like a machine.
        var inscription: String {
            unloggedCount == 1
                ? "YESTERDAY · 1 UNLOGGED"
                : "YESTERDAY · \(unloggedCount) UNLOGGED"
        }

        var spokenLabel: String {
            unloggedCount == 1
                ? "Yesterday, one prayer not logged"
                : "Yesterday, \(unloggedCount) prayers not logged"
        }
    }

    /// The offer for this moment, or `nil` when the app should say
    /// nothing.
    ///
    /// - Parameters:
    ///   - now: the screen's clock, so a debug override moves this too.
    ///   - logs: every prayer log available; only yesterday's matter.
    ///   - pauses: excused pauses, active or ended.
    ///   - dismissedDayKey: the civil day the person last dismissed the
    ///     line on, as `civilDayKey` renders it. Empty means never.
    static func offer(
        now: Date,
        logs: [PrayerLog],
        pauses: [PauseInterval],
        dismissedDayKey: String,
        calendar: Calendar = .current
    ) -> Offer? {
        let today = calendar.startOfDay(for: now)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
            return nil
        }

        // Dismissed today: the person has already been asked once.
        guard dismissedDayKey != civilDayKey(today, calendar: calendar) else { return nil }

        // An excused pause covering any part of yesterday silences this
        // entirely. A pause is the app agreeing not to keep count, and
        // an offer to fill in the gap would be keeping count.
        if pauses.contains(where: { $0.overlaps(day: yesterday, calendar: calendar) }) {
            return nil
        }

        let loggedYesterday = Set(
            logs
                .filter { calendar.isDate($0.prayerDate, inSameDayAs: yesterday) }
                .compactMap(\.prayer)
        )
        let unlogged = Prayer.allCases.filter { !loggedYesterday.contains($0) }
        guard !unlogged.isEmpty else { return nil }

        return Offer(day: yesterday, unloggedCount: unlogged.count)
    }

    /// Yesterday's five, in order, each with the log it already has.
    static func rows(
        for day: Date,
        logs: [PrayerLog],
        calendar: Calendar = .current
    ) -> [(prayer: Prayer, log: PrayerLog?)] {
        let dayLogs = logs.filter { calendar.isDate($0.prayerDate, inSameDayAs: day) }
        return Prayer.allCases.map { prayer in
            (prayer, dayLogs.first { $0.prayer == prayer })
        }
    }

    /// The dismissal key for a civil day. Presentation state, not
    /// worship data — it lives in `@AppStorage`, never in the store.
    static func civilDayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0, components.month ?? 0, components.day ?? 0
        )
    }
}

extension PauseInterval {
    /// Whether this pause covers any part of the given civil day.
    func overlaps(day: Date, calendar: Calendar = .current) -> Bool {
        let dayStart = calendar.startOfDay(for: day)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return false
        }
        let pauseEnd = endDate ?? .distantFuture
        return startDate < dayEnd && pauseEnd >= dayStart
    }
}
