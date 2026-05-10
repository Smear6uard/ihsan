import Foundation
import IhsanCore

/// Small-caps inscription text that renders beneath each prayer name on
/// the Today screen's prayer list. The inscription is the row's complete
/// state description: scheduled time when there's nothing to log,
/// "PRAYING NOW · WINDOW ENDS …" when the user is inside the active
/// prayer's window, "ON TIME · 12:38 PM" / "JAMA·AH · 5:14 AM" /
/// "LATE · 25 MIN AFTER" / "QADĀ · LOGGED 9 MAY" / "MISSED · WINDOW
/// CLOSED 4:18 PM" once logged or past the window.
///
/// The strings come straight from the manuscript-redirect mockups —
/// the small-caps formatting is applied at the call site via the
/// `IhsanFont.inscription` style and a `.tracking()` modifier.
enum PrayerRowInscription {
    /// Build the inscription for one row.
    ///
    /// - Parameters:
    ///   - prayer: Which fardh the row represents. Currently unused
    ///     in the inscription itself but threaded through so future
    ///     copy can differ per prayer (e.g. a special "PRE-FAJR" hint).
    ///   - scheduledTime: The prayer's start.
    ///   - windowEndTime: The end of the prayer's window — sunrise
    ///     for Fajr, the next prayer's start for Dhuhr–Maghrib, or
    ///     `nil` for Isha (window extends past midnight).
    ///   - log: The persisted log entry for this prayer today, if any.
    ///   - isActive: `true` when the row represents the prayer
    ///     currently in its window.
    ///   - now: Override for "current moment" — tests pass a fixed
    ///     date; runtime callers leave the default.
    static func text(
        for prayer: Prayer,
        scheduledTime: Date,
        windowEndTime: Date?,
        log: PrayerLog?,
        isActive: Bool,
        now: Date = .now
    ) -> String {
        _ = prayer

        // Logged states take precedence — even for the currently
        // active prayer, once the user has tapped a status the row
        // should reflect their answer rather than fall back to
        // "PRAYING NOW".
        if let log, let status = log.status {
            return loggedInscription(
                status: status,
                withJamaah: log.withJamaah,
                lateBySeconds: log.lateBySeconds,
                scheduledTime: scheduledTime,
                windowEndTime: windowEndTime,
                loggedAt: log.loggedAt
            )
        }

        // Active prayer in window, not yet logged — invite the user
        // to log by surfacing how long the window is open for.
        if isActive {
            if let end = windowEndTime {
                return "PRAYING NOW · WINDOW ENDS \(timeText(end))"
            }
            return "PRAYING NOW"
        }

        // No log, no active flag, but the window has closed — auto-
        // display as missed so the row doesn't read as "still upcoming"
        // for a prayer the user can no longer log on time.
        if let end = windowEndTime, now > end {
            return "MISSED · WINDOW CLOSED \(timeText(end))"
        }

        // Nothing logged, window still ahead — just the scheduled time.
        return timeText(scheduledTime)
    }

    // MARK: - Helpers

    private static func loggedInscription(
        status: PrayerStatus,
        withJamaah: Bool,
        lateBySeconds: Int?,
        scheduledTime: Date,
        windowEndTime: Date?,
        loggedAt: Date
    ) -> String {
        switch status {
        case .onTime:
            if withJamaah {
                return "JAMA·AH · \(timeText(scheduledTime))"
            }
            return "ON TIME · \(timeText(scheduledTime))"
        case .late:
            let minutes = max(1, (lateBySeconds ?? 0) / 60)
            return "LATE · \(minutes) MIN AFTER"
        case .missed:
            if let end = windowEndTime {
                return "MISSED · WINDOW CLOSED \(timeText(end))"
            }
            return "MISSED"
        case .qada:
            return "QADĀ · LOGGED \(dayMonthText(loggedAt))"
        }
    }

    private static func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date).uppercased()
    }

    private static func dayMonthText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date).uppercased()
    }
}
