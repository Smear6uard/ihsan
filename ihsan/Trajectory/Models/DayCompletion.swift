import Foundation
import IhsanCore

/// A single day's prayer record, derived from `PrayerLog`s, `PauseInterval`s,
/// and `TravelInterval`s. Drives both the hero heatmap dot and the day
/// popover.
struct DayCompletion: Identifiable, Hashable, Sendable {
    /// Start-of-day in the user's current calendar. Doubles as the identity.
    let id: Date
    let date: Date
    /// Always exactly five entries, ordered fajr → isha.
    let prayerCompletions: [PrayerCompletion]
    let isPaused: Bool
    let isTraveling: Bool
    /// This cycle holds an entry the app declined to resolve on the
    /// user's behalf — a second record of one prayer, surfaced by the
    /// cycle reattribution rather than deleted.
    var needsReview: Bool = false

    /// Number of fardh prayers logged with status `.onTime`.
    var onTimeCount: Int {
        prayerCompletions.filter { $0.status == .onTime }.count
    }

    /// Total fardh prayers with any status logged. Excludes qada — qada
    /// belongs on a separate "made up" axis, not in the daily denominator.
    var loggedCount: Int {
        prayerCompletions.filter { $0.status != nil }.count
    }

    /// Completion fraction in `0...1`, used for heatmap dot opacity.
    /// `nil` for paused days — they should render as a dash, not a dot.
    var completionFraction: Double? {
        if isPaused { return nil }
        return Double(onTimeCount) / 5.0
    }
}
