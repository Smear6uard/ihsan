import Foundation
import IhsanCore
import SwiftData

/// The single mutation funnel for voluntary-worship records. Every surface —
/// the focused card's chips, the duha card, the night set, Shortcuts —
/// writes through here, so one row per kind per day holds everywhere
/// (`NaflLog.dedupKey`).
struct NaflLogService {

    /// Same clock discipline as `PrayerLogService`: every stamp
    /// derives from the process's one clock, never the wall clock.
    let clock: NowProvider

    init(clock: NowProvider = .active) {
        self.clock = clock
    }

    /// Toggles the day's record for a kind: absent → recorded,
    /// present → removed. Returns the new log, or nil when the tap
    /// removed one. A rak'ah count is stored only when the caller passes
    /// one — the layer never asks.
    @MainActor
    @discardableResult
    func toggleNafl(
        kind: NaflKind,
        naflDate: Date,
        rakahCount: Int? = nil,
        sourceSurface: SourceSurface = .app,
        in context: ModelContext
    ) throws -> NaflLog? {
        let dedupKey = NaflLog.makeDedupKey(kind: kind, naflDate: naflDate)
        let descriptor = FetchDescriptor<NaflLog>(
            predicate: #Predicate { $0.dedupKey == dedupKey }
        )

        if let existing = try context.fetch(descriptor).first {
            context.delete(existing)
            try context.save()
            return nil
        }

        let log = NaflLog(
            kind: kind,
            naflDate: naflDate,
            rakahCount: rakahCount,
            loggedAt: clock.now(),
            sourceSurface: sourceSurface
        )
        context.insert(log)
        try context.save()
        return log
    }
}
