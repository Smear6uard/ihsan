import Foundation
import IhsanCore

/// Aggregation helpers for the gestalt dot pattern.
///
/// The 7D / 30D / 90D modes render every day as its own column — no
/// aggregation needed, the `[DayCompletion]` array already has the right
/// shape. YEAR view chunks the 365-day window into 52 trailing seven-day
/// buckets (today sits in the rightmost bucket) and reduces each bucket
/// to one "typical" `PrayerCompletion` per prayer, computed as the modal
/// status across the seven days.
enum GestaltAggregation {

    /// Year-mode columns. Returns exactly 52 entries ordered oldest-first
    /// (rightmost = current week containing today). Each entry has five
    /// `PrayerCompletion`s in `Prayer.allCases` order — the most common
    /// status the user logged for that prayer across the seven days in
    /// that week.
    static func yearWeekColumns(days: [DayCompletion]) -> [[PrayerCompletion]] {
        // Bucket trailing-7s from the end of the array so today lands in
        // the final bucket. With 365 days we get 52 full sevens plus one
        // leading-day remainder, which we drop — the user's expectation
        // is "52 weeks", not "52.14 chunks".
        let trailingFull = (days.count / 7) * 7
        let trimmed = Array(days.suffix(trailingFull))
        let weeks: [[DayCompletion]] = stride(from: 0, to: trimmed.count, by: 7).map { start in
            Array(trimmed[start..<min(start + 7, trimmed.count)])
        }

        return weeks.map { week in
            Prayer.allCases.map { prayer in
                modeCompletion(for: prayer, in: week)
            }
        }
    }

    /// The modal `PrayerCompletion` for the given prayer across the
    /// provided days. Ties resolve toward the better outcome (jamaʿah →
    /// on-time → qadā → late → missed → unlogged) so an inconsistent
    /// week renders as its best face — honest about variability without
    /// being punitive.
    private static func modeCompletion(
        for prayer: Prayer,
        in days: [DayCompletion]
    ) -> PrayerCompletion {
        // Collect the week's completions for this prayer slot.
        let completions: [PrayerCompletion] = days.compactMap { day in
            day.prayerCompletions.first(where: { $0.prayer == prayer })
        }

        // Count by canonical bucket so jamaʿah is distinct from plain on-time.
        var counts: [GestaltBucket: Int] = [:]
        for completion in completions {
            counts[GestaltBucket(completion), default: 0] += 1
        }

        guard
            let best = counts.max(by: { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value < rhs.value }
                // Tie-break: prefer the better outcome.
                return lhs.key.priority < rhs.key.priority
            })
        else {
            return PrayerCompletion(prayer: prayer, status: nil, withJamaah: false)
        }

        return best.key.completion(for: prayer)
    }

    /// Canonical bucket for a `PrayerCompletion`, used both as a counting
    /// key and as a priority order for tie-breaks.
    private enum GestaltBucket: Hashable {
        case jamaah
        case onTime
        case qada
        case late
        case missed
        case unlogged

        init(_ completion: PrayerCompletion) {
            switch (completion.status, completion.withJamaah) {
            case (.onTime, true): self = .jamaah
            case (.onTime, _):    self = .onTime
            case (.qada, _):      self = .qada
            case (.late, _):      self = .late
            case (.missed, _):    self = .missed
            case (.none, _):      self = .unlogged
            }
        }

        /// Higher priority wins ties.
        var priority: Int {
            switch self {
            case .jamaah:   return 5
            case .onTime:   return 4
            case .qada:     return 3
            case .late:     return 2
            case .missed:   return 1
            case .unlogged: return 0
            }
        }

        func completion(for prayer: Prayer) -> PrayerCompletion {
            switch self {
            case .jamaah:   return PrayerCompletion(prayer: prayer, status: .onTime, withJamaah: true)
            case .onTime:   return PrayerCompletion(prayer: prayer, status: .onTime, withJamaah: false)
            case .qada:     return PrayerCompletion(prayer: prayer, status: .qada,   withJamaah: false)
            case .late:     return PrayerCompletion(prayer: prayer, status: .late,   withJamaah: false)
            case .missed:   return PrayerCompletion(prayer: prayer, status: .missed, withJamaah: false)
            case .unlogged: return PrayerCompletion(prayer: prayer, status: nil,     withJamaah: false)
            }
        }
    }
}
