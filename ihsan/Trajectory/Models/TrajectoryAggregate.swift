import Foundation
import IhsanCore

/// Period-level summary derived from a `[DayCompletion]`. Feeds the quiet
/// inscription row beneath the gestalt grid. Carries no view dependencies
/// so it stays trivially testable.
struct TrajectoryAggregate: Equatable, Sendable {
    /// Days inside the period that are NOT paused.
    let totalActiveDays: Int

    let pausedDays: Int
    let travelingDays: Int

    /// Count of fardh prayers with any status (onTime + late + missed) across
    /// all active days. Qada is tracked separately.
    let totalLogged: Int

    /// Theoretical maximum: `totalActiveDays * 5`.
    let totalPossible: Int

    let onTimeCount: Int
    let lateCount: Int
    let missedCount: Int
    let qadaCount: Int

    /// Number of prayers within the period that were logged with
    /// `withJamaah = true`. Surfaces in the quiet summary row as the
    /// "JAMAʿAH · N" count.
    let jamaahCount: Int

    let perPrayer: [PrayerAggregate]

    struct PrayerAggregate: Equatable, Sendable {
        let prayer: Prayer
        let onTimeCount: Int
        let lateCount: Int
        let missedCount: Int
        let qadaCount: Int
        let totalActiveDays: Int
        /// One value per day in chronological order. `nil` for paused days
        /// (renders as a dash); otherwise the per-prayer fraction in 0...1.
        let dailyFractions: [Double?]
    }
}
