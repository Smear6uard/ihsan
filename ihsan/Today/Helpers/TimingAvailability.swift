import Foundation
import IhsanCore
import IhsanPrayerTimes

/// The sheet's temporal truth rule: which timing choices can be TRUE
/// for the prayer and cycle being logged.
///
/// "Today" here is the prayer CYCLE in progress, not the civil day: at
/// 1 AM the cycle is still last evening's, so that evening's Isha is
/// judged by its live window rather than filed away as a past day.
///
/// The timing axis describes when the prayer was PERFORMED, not when
/// the log entry is created. Praying within the window and logging
/// afterward is the most common usage pattern and must never be
/// blocked.
///
/// - Live window open → **On Time and Delayed**. Both describe a
///   prayer offered *inside* its window, and both can be true right
///   now — someone praying Isha at 3 a.m. is delayed, not qāḍī. Qadā
///   and Missed describe a window that has passed, which cannot yet be
///   true; they render quiet and disabled, visible for learnability.
/// - Window ended, today or any past day → **all four**. "On time"
///   remains true of a prayer performed inside the window and logged
///   after it; memory, not the clock, is the authority once the
///   window has closed.
/// - A future day, or today before the window opens → nothing (the
///   UI never offers the sheet there; the empty set is the honest
///   defensive answer).
///
/// An existing entry's status is always selectable on top of the
/// rule — editing must be able to re-affirm what is already
/// recorded, and "Save Changes" with an unchanged selection can
/// never be blocked by the clock.
enum TimingAvailability {

    static func allowedStatuses(
        cycleDate: Date,
        dayBeingLogged: Date,
        windowState: PrayerWindowState?,
        currentStatus: PrayerStatus?,
        calendar: Calendar = .current
    ) -> Set<PrayerStatus> {
        var allowed = baseStatuses(
            cycleDate: cycleDate,
            dayBeingLogged: dayBeingLogged,
            windowState: windowState,
            calendar: calendar
        )
        if let currentStatus {
            allowed.insert(currentStatus)
        }
        return allowed
    }

    private static func baseStatuses(
        cycleDate: Date,
        dayBeingLogged: Date,
        windowState: PrayerWindowState?,
        calendar: Calendar
    ) -> Set<PrayerStatus> {
        let today = calendar.startOfDay(for: cycleDate)
        let day = calendar.startOfDay(for: dayBeingLogged)

        if day < today {
            return [.onTime, .late, .qada, .missed]
        }
        if day > today {
            return []
        }

        // The cycle in progress. With the schedule known, the window decides; the
        // ledger surfaces (Path cells) open without a schedule and
        // fall through to the full set — repair is deliberate there,
        // and the Today surfaces remain the schedule's authority.
        guard let windowState else {
            return [.onTime, .late, .qada, .missed]
        }
        switch windowState {
        case .upcoming:
            return []
        case .current:
            // Delayed is an in-window state, so it is live the moment
            // the window is. This is also what makes the focused card
            // and this sheet agree: the card has always offered a
            // Delayed commit while the window is open.
            return [.onTime, .late]
        case .closed:
            return [.onTime, .late, .qada, .missed]
        }
    }
}
