import Foundation
import SwiftData

/// Walks the CYCLES that have fully ended since setup (bounded by a
/// rolling window) and flows each silent prayer into the makeup ledger —
/// but only when the user chose that at setup. A prayer with any log at
/// all, of any status, never flows: an explicit record is the user's own
/// account of the day. Pause-covered days and repeats are refused by
/// `QadaLedgerWriter`.
///
/// Cycles, not civil days, and the distinction is not academic: a cycle
/// ends at Fajr, so at 1 AM the evening's Isha is still open. Sweeping
/// by civil day would have flowed a prayer whose window had not closed
/// into the ledger as unmade — the app telling someone they had missed
/// a prayer they were about to offer.
@MainActor
public struct QadaMissedFlowSweep {
    /// Cycles are only swept once they have completely ended, so a
    /// quiet morning never turns into entries by afternoon.
    public static let maximumSweepDays = 30

    public init() {}

    @discardableResult
    public func sweep(
        now: Date = .now,
        calendar: Calendar = .current,
        in context: ModelContext
    ) throws -> [QadaEntry] {
        let settings = try UserSettings.fetchOrCreate(in: context)
        guard settings.qadaTrackingEnabled,
              settings.qadaMissedFlowEnabled,
              let setupDate = settings.qadaSetupCompletedAt
        else {
            return []
        }

        let todayStart = PrayerCycleClock.sharedCycleDate(at: now, calendar: calendar)
        let windowFloor = calendar.date(
            byAdding: .day,
            value: -Self.maximumSweepDays,
            to: todayStart
        ) ?? todayStart
        let sweepStart = max(calendar.startOfDay(for: setupDate), windowFloor)

        guard sweepStart < todayStart else {
            return []
        }

        let logs = try context.fetch(FetchDescriptor<PrayerLog>(
            predicate: #Predicate { $0.prayerDate >= sweepStart && $0.prayerDate < todayStart }
        ))
        var loggedKeys = Set<String>()
        for log in logs {
            loggedKeys.insert(Self.key(prayerRaw: log.prayerRaw, day: log.prayerDate, calendar: calendar))
        }

        let writer = QadaLedgerWriter()
        var created: [QadaEntry] = []
        var day = sweepStart
        while day < todayStart {
            for prayer in Prayer.allCases {
                let key = Self.key(prayerRaw: prayer.rawValue, day: day, calendar: calendar)
                guard !loggedKeys.contains(key) else {
                    continue
                }
                if let entry = try writer.recordMissedFlow(prayer: prayer, date: day, in: context) {
                    created.append(entry)
                }
            }
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? todayStart
        }

        return created
    }

    private static func key(prayerRaw: String, day: Date, calendar: Calendar) -> String {
        let start = calendar.startOfDay(for: day)
        return "\(prayerRaw)-\(start.timeIntervalSinceReferenceDate)"
    }
}
