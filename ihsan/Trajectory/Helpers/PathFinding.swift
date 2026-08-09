import Foundation
import IhsanCore
import IhsanFiqhConfig

/// The one thing in this period worth doing something about.
///
/// The Path already *shows* the pattern (the gestalt grid) and *counts*
/// it (the quiet summary row). Restating either in a sentence adds
/// nothing, which is what the readout used to do. This picks the single
/// sharpest reading the ledger supports, says it plainly with the
/// numbers that make it true, and offers one action that changes
/// something.
///
/// Everything here is arithmetic over the user's own logs. The cited
/// context that accompanies a finding is authored copy keyed by
/// `kind` (`TrajectoryFindingFraming`) — no religious language is
/// generated here or by the on-device model.
struct PathFinding: Equatable, Sendable {
    let kind: PathFindingKind
    /// The blunt line. Names the prayer and the counts behind it.
    let headline: String
    /// The single offered action, and the words on its button. Absent
    /// only when the ledger genuinely calls for nothing.
    let action: PathFindingAction?
    let actionTitle: String?
}

/// What the card's button does. One of these mutates a setting in
/// place rather than navigating — the useful answer to "Fajr keeps
/// slipping" is a reminder that now exists, not a trip to a settings
/// screen.
///
/// `PrayerNotificationConfig.leadTimeSeconds` is deliberately not
/// touched. It is a modelled field with no control anywhere in the app,
/// so setting it from here would leave behind state the user can
/// neither see nor undo. The app has exactly one visible lever on a
/// prayer's reminder, and this uses that one.
enum PathFindingAction: Equatable, Sendable {
    /// Open the retroactive log sheet on this exact empty slot.
    case logSlot(day: Date, prayer: Prayer)
    /// Open the qadāʾ ledger.
    case openMakeupLedger
    /// Turn this prayer's reminder on.
    case enableReminder(Prayer)
    /// Open the nearby-masjid search.
    case findCongregation
}

/// One prayer's notification state, flattened so the finding engine
/// stays a pure function over values. `isEnabled` folds in the global
/// switch, because a per-prayer reminder under a global off is not a
/// reminder the user receives.
struct PathReminderSetting: Equatable, Sendable {
    let prayer: Prayer
    let isEnabled: Bool
}

extension PathFinding {

    /// Below this many elapsed days the ledger cannot distinguish a
    /// habit from a bad week, so no prayer gets named as weak.
    static let minimumDaysForPrayerDiagnosis = 4

    /// A reading is only as good as its coverage. Past this share of
    /// empty slots, the empty slots *are* the finding.
    static let coverageFloor = 0.5

    static func make(
        days: [DayCompletion],
        aggregate: TrajectoryAggregate,
        logs: [PrayerLog],
        reminders: [PathReminderSetting],
        now: Date,
        calendar: Calendar = .current
    ) -> PathFinding {
        // Today is excluded outright. Its later prayers are not due
        // yet, and counting a not-yet-due slot as a gap would make the
        // card wrong every morning. Paused days never enter any count.
        let today = calendar.startOfDay(for: now)
        let elapsed = days.filter { !$0.isPaused && $0.date < today }
        let elapsedSlots = elapsed.count * 5
        let stats = PrayerStats.build(from: elapsed)

        if let finding = unrecordedFinding(elapsed: elapsed, elapsedSlots: elapsedSlots, calendar: calendar) {
            return finding
        }
        if let finding = makeupFinding(days: days, logs: logs, calendar: calendar) {
            return finding
        }
        if let finding = weakPrayerFinding(stats: stats, dayCount: elapsed.count, reminders: reminders) {
            return finding
        }
        if let finding = delayFinding(stats: stats, dayCount: elapsed.count, reminders: reminders) {
            return finding
        }
        if let finding = congregationFinding(aggregate: aggregate) {
            return finding
        }
        return steadyFinding(stats: stats, dayCount: elapsed.count, aggregate: aggregate)
    }

    // MARK: - The readings, in the order they matter

    /// Gaps outrank everything. A ledger that is mostly empty cannot
    /// support a claim about which prayer is weak, and pretending
    /// otherwise would be the confident kind of wrong.
    private static func unrecordedFinding(
        elapsed: [DayCompletion],
        elapsedSlots: Int,
        calendar: Calendar
    ) -> PathFinding? {
        guard elapsedSlots >= 5 else { return nil }
        let unrecorded = elapsed.reduce(0) { total, day in
            total + day.prayerCompletions.filter { $0.status == nil }.count
        }
        guard Double(unrecorded) > Double(elapsedSlots) * coverageFloor else { return nil }

        let recorded = elapsedSlots - unrecorded
        let headline = "\(unrecorded) of the last \(elapsedSlots) slots hold no record at all. "
            + "The pattern above is drawn from the \(recorded) that do."

        // The most recent gap, not the oldest: a person can still
        // remember yesterday afternoon.
        guard let gap = mostRecentGap(in: elapsed) else {
            return PathFinding(
                kind: .unrecordedSlots,
                headline: headline,
                action: nil,
                actionTitle: nil
            )
        }

        return PathFinding(
            kind: .unrecordedSlots,
            headline: headline,
            action: .logSlot(day: gap.day, prayer: gap.prayer),
            actionTitle: "Record \(gap.prayer.displayNameEnglish) · \(weekday(gap.day, calendar: calendar))"
        )
    }

    /// A missed prayer that no one has made up yet.
    ///
    /// This has to read the raw logs, not the day grid. Marking a
    /// prayer as qadāʾ writes a SECOND, linked log and deliberately
    /// leaves the original as missed, so the grid shows missed either
    /// way. The only honest test of "still owed" is whether any qadāʾ
    /// log points back at it — and that make-up may well have been
    /// performed after the period ended, so the whole log set is
    /// searched, not the window.
    ///
    /// Unlike the gap reading, this one does include today. A slot the
    /// user has explicitly marked missed is owed the moment they mark
    /// it; there is nothing not-yet-due about it.
    private static func makeupFinding(
        days: [DayCompletion],
        logs: [PrayerLog],
        calendar: Calendar
    ) -> PathFinding? {
        // Derived from the extremes rather than the array's ends: the
        // aggregator hands these over oldest-first today, and a window
        // that silently inverts if that ever changes would make this
        // reading disappear instead of fail.
        guard let first = days.map(\.date).min(),
              let last = days.map(\.date).max(),
              let end = calendar.date(byAdding: .day, value: 1, to: last)
        else { return nil }

        let pausedDays = Set(days.filter(\.isPaused).map(\.date))
        let repaired = Set(logs.compactMap(\.qadaForPrayerLogID))
        let outstanding = logs.filter { log in
            log.status == .missed
                && log.prayerDate >= first
                && log.prayerDate < end
                && !pausedDays.contains(calendar.startOfDay(for: log.prayerDate))
                && !repaired.contains(log.id)
        }

        guard !outstanding.isEmpty else { return nil }

        let isOne = outstanding.count == 1
        let headline = "\(outstanding.count) \(isOne ? "prayer is" : "prayers are") "
            + "recorded missed in this period with no make-up logged against "
            + "\(isOne ? "it" : "them") yet."

        return PathFinding(
            kind: .outstandingMakeups,
            headline: headline,
            action: .openMakeupLedger,
            actionTitle: "Open the make-up ledger"
        )
    }

    /// One prayer is not being prayed while the rest are.
    ///
    /// Measured on whether the prayer HAPPENED — on time or delayed,
    /// both count as present — never on whether it was punctual. A
    /// prayer taken at the end of its window every single day is not
    /// weak, it is late, and that is the next reading down with its own
    /// grounding. Ranking it here would hand someone a warning about
    /// missing ʿAṣr when they have not missed one.
    private static func weakPrayerFinding(
        stats: [PrayerStats],
        dayCount: Int,
        reminders: [PathReminderSetting]
    ) -> PathFinding? {
        guard dayCount >= minimumDaysForPrayerDiagnosis,
              let worst = stats.min(by: PrayerStats.byPresence),
              let best = stats.max(by: PrayerStats.byPresence),
              worst.prayer != best.prayer,
              worst.presentRate(over: dayCount) <= 0.5,
              best.presentRate(over: dayCount) - worst.presentRate(over: dayCount) >= 0.25
        else { return nil }

        let kind: PathFindingKind = switch worst.prayer {
        case .fajr, .isha: .weakFajrOrIsha
        case .asr: .weakAsr
        case .dhuhr, .maghrib: .weakOtherPrayer
        }

        let headline = "\(worst.prayer.displayNameEnglish) is the weak point: "
            + "prayed on \(worst.present) of \(dayCount) days, "
            + "against \(best.present) for \(best.prayer.displayNameEnglish)."
        let remedy = remedy(for: worst.prayer, reminders: reminders)

        return PathFinding(
            kind: kind,
            headline: headline,
            action: remedy.action,
            actionTitle: remedy.title
        )
    }

    /// A prayer that is being prayed, habitually, at the end of its
    /// window.
    private static func delayFinding(
        stats: [PrayerStats],
        dayCount: Int,
        reminders: [PathReminderSetting]
    ) -> PathFinding? {
        guard dayCount >= minimumDaysForPrayerDiagnosis,
              let worst = stats.max(by: PrayerStats.byLateCount),
              worst.late >= 3,
              worst.late > worst.onTime
        else { return nil }

        let kind: PathFindingKind = worst.prayer == .asr ? .delayedAsr : .delayedOtherPrayer
        let headline = "\(worst.prayer.displayNameEnglish) is recorded delayed on "
            + "\(worst.late) of \(dayCount) days — inside its window, at the end of it."
        let remedy = remedy(for: worst.prayer, reminders: reminders)

        return PathFinding(
            kind: kind,
            headline: headline,
            action: remedy.action,
            actionTitle: remedy.title
        )
    }

    /// A record that holds, entirely alone.
    private static func congregationFinding(aggregate: TrajectoryAggregate) -> PathFinding? {
        guard aggregate.jamaahCount == 0, aggregate.totalLogged >= 10 else { return nil }

        return PathFinding(
            kind: .noJamaah,
            headline: "\(aggregate.totalLogged) prayers recorded in this period, "
                + "none of them with a congregation.",
            action: .findCongregation,
            actionTitle: "Find a masjid"
        )
    }

    /// Nothing is slipping. The card still names the thinnest point,
    /// because "all good" is the one reading nobody can act on.
    private static func steadyFinding(
        stats: [PrayerStats],
        dayCount: Int,
        aggregate: TrajectoryAggregate
    ) -> PathFinding {
        let headline: String
        if dayCount > 0, let worst = stats.min(by: PrayerStats.byOnTimeRate) {
            headline = "Nothing in this period is slipping. The thinnest point is "
                + "\(worst.prayer.displayNameEnglish), on time on \(worst.onTime) of \(dayCount) days."
        } else {
            headline = "Not enough elapsed days in this period to read a pattern yet."
        }

        // Offering a masjid search to somebody already praying half
        // their prayers in congregation is noise, so that record gets
        // no button at all.
        let jamaahRate = aggregate.totalLogged > 0
            ? Double(aggregate.jamaahCount) / Double(aggregate.totalLogged)
            : 0
        guard jamaahRate < 0.5 else {
            return PathFinding(kind: .steady, headline: headline, action: nil, actionTitle: nil)
        }

        return PathFinding(
            kind: .steady,
            headline: headline,
            action: .findCongregation,
            actionTitle: "Find a masjid"
        )
    }

    // MARK: - Remedies

    /// The remedy ladder, which has exactly two rungs because the app
    /// has exactly two things to offer. If the prayer is not even being
    /// announced, announce it. If it already is, the phone has done
    /// what a phone can do, and the remaining answer is other people.
    private static func remedy(
        for prayer: Prayer,
        reminders: [PathReminderSetting]
    ) -> (action: PathFindingAction, title: String) {
        // A prayer missing from the settings blob is treated as having
        // no reminder, which is what the user experiences.
        guard let setting = reminders.first(where: { $0.prayer == prayer }), setting.isEnabled else {
            return (
                .enableReminder(prayer),
                "Turn on the \(prayer.displayNameEnglish) reminder"
            )
        }
        return (.findCongregation, "Find a masjid")
    }

    // MARK: - Slot arithmetic

    private static func mostRecentGap(
        in elapsed: [DayCompletion]
    ) -> (day: Date, prayer: Prayer)? {
        for day in elapsed.sorted(by: { $0.date > $1.date }) {
            // Prayer order within the day, so the offered slot is the
            // first one that went unrecorded rather than whichever
            // happened to be stored first.
            let gap = Prayer.allCases.first { prayer in
                day.prayerCompletions.contains { $0.prayer == prayer && $0.status == nil }
            }
            if let gap { return (day.date, gap) }
        }
        return nil
    }

    private static func weekday(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = .current
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter.string(from: date)
    }
}

/// One prayer's elapsed-day counts. Built once and shared by the
/// readings so they cannot disagree about the same period.
struct PrayerStats: Equatable, Sendable {
    let prayer: Prayer
    let onTime: Int
    let late: Int
    let missed: Int

    /// Prayed at all, punctual or not.
    var present: Int { onTime + late }

    func onTimeRate(over dayCount: Int) -> Double {
        guard dayCount > 0 else { return 0 }
        return Double(onTime) / Double(dayCount)
    }

    func presentRate(over dayCount: Int) -> Double {
        guard dayCount > 0 else { return 0 }
        return Double(present) / Double(dayCount)
    }

    static func build(from days: [DayCompletion]) -> [PrayerStats] {
        Prayer.allCases.map { prayer in
            var onTime = 0
            var late = 0
            var missed = 0
            for day in days {
                switch day.prayerCompletions.first(where: { $0.prayer == prayer })?.status {
                case .onTime: onTime += 1
                case .late: late += 1
                case .missed: missed += 1
                case .qada, .none: break
                }
            }
            return PrayerStats(prayer: prayer, onTime: onTime, late: late, missed: missed)
        }
    }

    /// Ties break on the day's own order — Fajr before Isha — so the
    /// card names the same prayer on every recomputation instead of
    /// flickering between two equally weak ones.
    ///
    /// Prayer index is unique, so both comparators are strict total
    /// orders and their min/max answers are single elements — no
    /// first-vs-last-of-equals subtlety applies. The tie direction is
    /// chosen per call site instead. This one is read by `min` to find
    /// the weakest prayer, so an ascending tie hands back the earlier
    /// of two equally weak ones.
    static func byOnTimeRate(_ lhs: PrayerStats, _ rhs: PrayerStats) -> Bool {
        if lhs.onTime != rhs.onTime { return lhs.onTime < rhs.onTime }
        return order(lhs.prayer) < order(rhs.prayer)
    }

    /// Read by `min` for the weakest prayer and by `max` for the one it
    /// is measured against. The ascending tie hands `min` the earlier
    /// of two equally absent prayers, which is the one the card names;
    /// `max` only ever supplies a comparison figure, so which of two
    /// equally strong prayers it picks does not matter beyond being
    /// stable.
    static func byPresence(_ lhs: PrayerStats, _ rhs: PrayerStats) -> Bool {
        if lhs.present != rhs.present { return lhs.present < rhs.present }
        return order(lhs.prayer) < order(rhs.prayer)
    }

    /// Read by `max` to find the most-delayed prayer, so this tie runs
    /// the other way: the earlier prayer sorts highest and wins.
    static func byLateCount(_ lhs: PrayerStats, _ rhs: PrayerStats) -> Bool {
        if lhs.late != rhs.late { return lhs.late < rhs.late }
        return order(lhs.prayer) > order(rhs.prayer)
    }

    private static func order(_ prayer: Prayer) -> Int {
        Prayer.allCases.firstIndex(of: prayer) ?? 0
    }
}
