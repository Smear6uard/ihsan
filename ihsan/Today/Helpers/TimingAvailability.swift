import Foundation
import IhsanCore

/// The sheet's temporal truth rule: which timing choices can be TRUE
/// at `now` for the prayer and civil day being logged.
///
/// - Live window open → only **On Time** (Late / Qadā / Missed are
///   rendered quiet and disabled — visible for learnability, not
///   selectable).
/// - Window ended today → **Late / Qadā / Missed** (the window is
///   gone; "on time" can no longer become true).
/// - A past civil day → all four (memory, not the clock, is the
///   authority for a day that has closed).
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
        scheduledTime: Date?,
        windowEndTime: Date?,
        currentStatus: PrayerStatus?,
        calendar: Calendar = .current
    ) -> Set<PrayerStatus> {
        var allowed = baseStatuses(
            now: now,
            dayBeingLogged: dayBeingLogged,
            scheduledTime: scheduledTime,
            windowEndTime: windowEndTime,
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
        scheduledTime: Date?,
        windowEndTime: Date?,
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
        guard let scheduledTime, let windowEndTime else {
            return [.onTime, .late, .qada, .missed]
        }
        if now < scheduledTime {
            return []
        }
        if now < windowEndTime {
            return [.onTime]
        }
        return [.late, .qada, .missed]
    }
}
