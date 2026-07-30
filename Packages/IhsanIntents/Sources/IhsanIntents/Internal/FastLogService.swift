import Foundation
import IhsanCore
import SwiftData

/// The single mutation funnel for fasting records. Every surface —
/// the Ramadan offer, the significant-day line's intention tap, the
/// fasting inscription, Shortcuts — writes through here, so one row
/// per civil day holds everywhere (`FastLog.dedupKey`).
struct FastLogService {

    /// Same clock discipline as `PrayerLogService`: every stamp
    /// derives from the process's one clock, never the wall clock.
    let clock: NowProvider

    init(clock: NowProvider = .active) {
        self.clock = clock
    }

    /// Records the day's fast, factually and idempotently:
    ///
    /// - no row → a new record with the given kind and state;
    /// - an `intended` row asked to become `kept` → the intention was
    ///   fulfilled; the row updates in place;
    /// - a row in the same state → the tap removes it (undo).
    ///
    /// A `kept` row never downgrades to `intended` — a second tap in
    /// the intention register simply leaves the kept fact alone.
    /// There is no negative transition anywhere: an intention that
    /// passes unkept is left to expire untouched.
    @MainActor
    @discardableResult
    func recordFast(
        kind: FastKind,
        state: FastState,
        fastDate: Date,
        sourceSurface: SourceSurface = .app,
        in context: ModelContext
    ) throws -> FastLog? {
        let dedupKey = FastLog.makeDedupKey(fastDate: fastDate)
        let descriptor = FetchDescriptor<FastLog>(
            predicate: #Predicate { $0.dedupKey == dedupKey }
        )

        if let existing = try context.fetch(descriptor).first {
            switch (existing.state, state) {
            case (.intended, .kept):
                existing.kindRaw = kind.rawValue
                existing.stateRaw = FastState.kept.rawValue
                existing.modifiedAt = clock.now()
                try context.save()
                return existing
            case (.kept, .intended):
                return existing
            default:
                context.delete(existing)
                try context.save()
                return nil
            }
        }

        let log = FastLog(
            kind: kind,
            state: state,
            fastDate: fastDate,
            loggedAt: clock.now(),
            sourceSurface: sourceSurface
        )
        context.insert(log)
        try context.save()
        return log
    }
}
