import Foundation
import IhsanCore
import IhsanPrayerTimes

/// The sheet's temporal truth rule: which timing choices can be TRUE
/// at `now` for the prayer and civil day being logged.
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
        now: Date,
        dayBeingLogged: Date,
        windowState: PrayerWindowState?,
        currentStatus: PrayerStatus?,
        calendar: Calendar = .current
    ) -> Set<PrayerStatus> {
        var allowed = baseStatuses(
            now: now,
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
        now: Date,
        dayBeingLogged: Date,
        windowState: PrayerWindowState?,
        calendar: Calendar
    ) -> Set<PrayerStatus> {
        let today = calendar.startOfDay(for: now)
        let day = calendar.startOfDay(for: dayBeingLogged)

        if day < today {
            return [.onTime, .late, .qada, .missed]
        }
        if day > today {
            return []
        }

        // Today. With the schedule known, the window decides; the
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
