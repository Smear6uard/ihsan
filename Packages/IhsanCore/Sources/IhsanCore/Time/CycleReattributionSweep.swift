import Foundation
import SwiftData

/// One cycle's boundaries, as the caller can supply them for a past
/// civil date. Fajr opens the cycle; Isha is the window that used to
/// spill across midnight and get filed on the wrong day.
public struct CycleDayBoundaries: Sendable, Equatable {
    public let fajr: Date
    public let isha: Date
    /// The Fajr that closes this cycle — the end of Isha's window.
    public let nextFajr: Date

    public init(fajr: Date, isha: Date, nextFajr: Date) {
        self.fajr = fajr
        self.isha = isha
        self.nextFajr = nextFajr
    }
}

/// What the reattribution did, in full. Printed by the seeded-store
/// test and logged once by the app, because a repair that moves
/// worship records without saying so is not a repair anyone should
/// trust.
public struct CycleReattributionReport: Sendable, Equatable {
    /// Entries examined — every log whose stored date could have been
    /// wrong under the midnight rule.
    public var examined: Int = 0
    /// Prayer logs moved to the previous cycle.
    public var prayerLogsMoved: Int = 0
    /// Of those, how many had a timing status recomputed, and to what.
    public var statusesRecomputed: [String] = []
    /// Voluntary records moved by the same rule.
    public var naflLogsMoved: Int = 0
    public var dhikrSessionsMoved: Int = 0
    /// Entries whose rightful cycle was already occupied. Both rows
    /// were kept; these are the ones flagged for the user.
    public var collisionsFlagged: Int = 0
    /// Days the caller could supply no schedule for. Nothing in them
    /// was touched.
    public var daysWithoutSchedule: Int = 0

    public init() {}

    /// The line the test prints and the app logs.
    public var summary: String {
        """
        Cycle reattribution — examined \(examined), \
        prayers moved \(prayerLogsMoved), \
        statuses recomputed \(statusesRecomputed.count)\
        \(statusesRecomputed.isEmpty ? "" : " [\(statusesRecomputed.joined(separator: ", "))]"), \
        nafl moved \(naflLogsMoved), \
        dhikr moved \(dhikrSessionsMoved), \
        collisions flagged \(collisionsFlagged), \
        days without a schedule \(daysWithoutSchedule)
        """
    }
}

/// The one-shot repair of records attributed under the midnight rule.
///
/// An Isha entry stored on a date but LOGGED between that date's
/// midnight and its Fajr was offered in the previous evening's cycle —
/// the window that was still open. It moves back one day, and its
/// timing status is recomputed against the window it really belonged
/// to: an in-window Isha wrongly stored as qadā or missed becomes on
/// time. Post-midnight qiyam, witr, and dhikr follow the same rule.
///
/// Nothing is deleted. Where the rightful cycle already holds an entry
/// for that prayer, the earlier PERFORMED one keeps the slot, the
/// other is flagged `.cycleDuplicate`, and Path shows both for the
/// person to settle. The app does not get to decide which of someone's
/// two records of a prayer is the real one.
///
/// The caller supplies the schedule. This type never learns what a
/// coordinate is — a day it cannot be told about is a day it leaves
/// alone, and says so in the report.
///
/// Unisolated on purpose: it is a synchronous pass over a context the
/// caller already owns, and the seeded-store test drives it from a
/// child process where no main actor is running.
public struct CycleReattributionSweep {

    /// Bump when the rule changes and every store must be re-swept.
    public static let currentVersion = 1

    /// How far back the sweep reaches. A year of history is more than
    /// this app has ever had, and the bound keeps a first launch from
    /// walking an unbounded store.
    public static let maximumLookbackDays = 400

    private let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// Run the repair if this store has not had it.
    ///
    /// - Parameter boundaries: the cycle boundaries for a civil day,
    ///   or `nil` where the caller cannot compute them.
    @discardableResult
    public func runIfNeeded(
        now: Date,
        boundaries: (Date) -> CycleDayBoundaries?,
        in context: ModelContext
    ) throws -> CycleReattributionReport? {
        let settings = try UserSettings.fetchOrCreate(in: context)
        guard settings.cycleReattributionVersion < Self.currentVersion else { return nil }

        let report = try run(now: now, boundaries: boundaries, in: context)

        settings.cycleReattributionVersion = Self.currentVersion
        settings.modifiedAt = now
        try context.save()
        return report
    }

    /// The repair itself, without the marker — the seam the tests
    /// drive.
    @discardableResult
    public func run(
        now: Date,
        boundaries: (Date) -> CycleDayBoundaries?,
        in context: ModelContext
    ) throws -> CycleReattributionReport {
        var report = CycleReattributionReport()
        let floor = calendar.date(
            byAdding: .day, value: -Self.maximumLookbackDays, to: calendar.startOfDay(for: now)
        ) ?? .distantPast

        // A day whose schedule the caller cannot supply is counted
        // once and skipped; without a Fajr there is no way to tell a
        // post-midnight entry from an evening one.
        var scheduleCache: [Date: CycleDayBoundaries?] = [:]
        func schedule(for day: Date) -> CycleDayBoundaries? {
            if let cached = scheduleCache[day] { return cached }
            let resolved = boundaries(day)
            scheduleCache[day] = resolved
            if resolved == nil { report.daysWithoutSchedule += 1 }
            return resolved
        }

        try reattributePrayerLogs(
            floor: floor, schedule: schedule, report: &report, in: context
        )
        try reattributeNaflLogs(
            floor: floor, schedule: schedule, report: &report, in: context
        )
        try reattributeDhikrSessions(
            floor: floor, schedule: schedule, report: &report, in: context
        )

        try context.save()
        return report
    }

    // MARK: - Prayer logs

    private func reattributePrayerLogs(
        floor: Date,
        schedule: (Date) -> CycleDayBoundaries?,
        report: inout CycleReattributionReport,
        in context: ModelContext
    ) throws {
        let logs = try context.fetch(FetchDescriptor<PrayerLog>(
            predicate: #Predicate { $0.prayerDate >= floor }
        ))
        // Every (prayer, cycle) already spoken for, so a move can see
        // the collision before it makes one.
        var occupied: [String: PrayerLog] = [:]
        for log in logs {
            occupied[log.dedupKey] = log
        }

        for log in logs {
            guard log.prayer == .isha else { continue }
            let storedDay = calendar.startOfDay(for: log.prayerDate)
            guard let boundaries = schedule(storedDay) else { continue }
            // Logged after the stored day began but before its Fajr:
            // the act happened in the window still open from the
            // evening before.
            guard log.loggedAt >= storedDay, log.loggedAt < boundaries.fajr else { continue }
            report.examined += 1

            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: storedDay),
                  let previous = schedule(previousDay)
            else { continue }
            // And it really was inside the previous cycle's Isha.
            guard log.loggedAt >= previous.isha, log.loggedAt < previous.nextFajr else { continue }

            let newKey = Self.dedupKey(prayerRaw: log.prayerRaw, prayerDate: previousDay)
            if let sitting = occupied[newKey], sitting !== log {
                // Two records of one prayer. Keep the earlier
                // performed one where it is, flag the mover, delete
                // nothing.
                log.reviewFlagRaw = PrayerLogReviewFlag.cycleDuplicate.rawValue
                report.collisionsFlagged += 1
                continue
            }

            occupied[log.dedupKey] = nil
            log.prayerDate = previousDay
            log.dedupKey = newKey
            log.scheduledTime = previous.isha
            occupied[newKey] = log
            report.prayerLogsMoved += 1

            // The status was judged against a window this prayer was
            // never in. Judge it again against the one it was.
            let recomputed = Self.status(
                of: log, inWindowFrom: previous.isha, to: previous.nextFajr
            )
            if recomputed != log.status {
                report.statusesRecomputed.append(
                    "\(log.statusRaw)→\(recomputed.rawValue)"
                )
                log.statusRaw = recomputed.rawValue
                if recomputed == .late {
                    log.lateBySeconds = max(
                        0, Int((log.prayedAt ?? log.loggedAt).timeIntervalSince(previous.isha))
                    )
                } else {
                    log.lateBySeconds = nil
                }
            }
        }
    }

    /// The timing an entry deserves against its real window.
    ///
    /// Only the two in-window verdicts are ever awarded here. A record
    /// the person themselves marked missed or made up stays as they
    /// left it unless the act demonstrably happened inside the window
    /// — the sweep corrects the app's arithmetic, never someone's own
    /// account of their day.
    private static func status(
        of log: PrayerLog, inWindowFrom start: Date, to end: Date
    ) -> PrayerStatus {
        let performed = log.prayedAt ?? log.loggedAt
        guard performed >= start, performed < end else { return log.status ?? .missed }
        switch log.status {
        case .onTime, .late:
            return log.status ?? .onTime
        case .qada, .missed, .none:
            // It was offered inside its window. Whatever the midnight
            // rule made of that, it was not qadā.
            return .onTime
        }
    }

    // MARK: - Voluntary records

    private func reattributeNaflLogs(
        floor: Date,
        schedule: (Date) -> CycleDayBoundaries?,
        report: inout CycleReattributionReport,
        in context: ModelContext
    ) throws {
        let logs = try context.fetch(FetchDescriptor<NaflLog>(
            predicate: #Predicate { $0.naflDate >= floor }
        ))
        var occupied = Set(logs.map(\.dedupKey))

        for log in logs {
            guard let kind = log.kind, Self.isNightKind(kind) else { continue }
            let storedDay = calendar.startOfDay(for: log.naflDate)
            guard let boundaries = schedule(storedDay) else { continue }
            guard log.loggedAt >= storedDay, log.loggedAt < boundaries.fajr else { continue }
            report.examined += 1

            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: storedDay)
            else { continue }
            let newKey = NaflLog.makeDedupKey(kind: kind, naflDate: previousDay)
            // A night act already recorded for the night it belongs to
            // needs no second row; the misfiled one is the duplicate,
            // and it stays where a person can see it.
            guard !occupied.contains(newKey) else { continue }

            occupied.remove(log.dedupKey)
            log.naflDate = previousDay
            log.dedupKey = newKey
            occupied.insert(newKey)
            report.naflLogsMoved += 1
        }
    }

    /// The kinds that belong to the night, and so can be offered after
    /// midnight. Duha and the rawatib cannot: their windows close long
    /// before it.
    private static func isNightKind(_ kind: NaflKind) -> Bool {
        switch kind {
        case .qiyam, .witr, .tarawih: return true
        case .duha, .rawatibBefore, .rawatibAfter: return false
        }
    }

    private func reattributeDhikrSessions(
        floor: Date,
        schedule: (Date) -> CycleDayBoundaries?,
        report: inout CycleReattributionReport,
        in context: ModelContext
    ) throws {
        let sessions = try context.fetch(FetchDescriptor<DhikrSession>(
            predicate: #Predicate { $0.sessionDate >= floor }
        ))

        for session in sessions {
            let storedDay = calendar.startOfDay(for: session.sessionDate)
            guard let boundaries = schedule(storedDay) else { continue }
            guard session.startedAt >= storedDay, session.startedAt < boundaries.fajr else {
                continue
            }
            report.examined += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: storedDay)
            else { continue }
            // Sittings do not dedup by day — a night can hold several,
            // and moving one never collides with another.
            session.sessionDate = previousDay
            report.dhikrSessionsMoved += 1
        }
    }

    // MARK: - Keys

    /// `PrayerLog`'s own key rule, reproduced because the model keeps
    /// its maker private and a reattribution must write exactly what a
    /// fresh log would.
    static func dedupKey(prayerRaw: String, prayerDate: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return "\(prayerRaw)-\(formatter.string(from: prayerDate))"
    }
}
