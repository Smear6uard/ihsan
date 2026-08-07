import Foundation
import IhsanCore
import IhsanPrayerTimes

/// The focused card's state machine, as pure functions of the moment.
///
/// The card renders exactly what this model resolves — the tests pin
/// the two Part-A guarantees (a countdown never rests at 0:00:00; at
/// a window boundary the state transitions atomically) and the copy
/// rule (the app describes the window, never the user's act).
enum FocusedCardModel {

    enum Phase: Equatable {
        /// Before the window opens: the prayer's time is the primary
        /// numeral, the countdown is an inscription.
        case upcoming(opensAt: Date)
        /// Inside the window: name is primary, the window is described
        /// quietly ("NOW · UNTIL 6:15 AM"), no giant numerals.
        case active(until: Date)
        /// The window has passed with no log.
        case windowClosed(at: Date?)
        /// A log exists.
        case logged
    }

    /// Whether the phase admits logging controls. Before a window
    /// opens there is nothing to commit — the card shows its upcoming
    /// state and offers no buttons, no sheet.
    static func allowsLogging(_ phase: Phase) -> Bool {
        if case .upcoming = phase { return false }
        return true
    }

    /// The tasbih handoff belongs only to an in-window prayer that was
    /// just recorded as completed. Historical, missed, and makeup logs
    /// never surface a misleading post-prayer action.
    static func offersPostPrayerTasbih(
        windowState: PrayerWindowState,
        status: PrayerStatus?,
        isAvailable: Bool
    ) -> Bool {
        guard isAvailable, windowState.isCurrent else { return false }
        return status == .onTime || status == .late
    }

    static func resolve(
        windowState: PrayerWindowState,
        isLogged: Bool
    ) -> Phase {
        if isLogged { return .logged }
        // No boundary arithmetic lives here. The UI consumes the exact
        // state produced by `PrayerStateResolver`, so a card cannot
        // disagree with the header, plate, sheet, or widgets.
        switch windowState {
        case .upcoming(let opensAt):
            return .upcoming(opensAt: opensAt)
        case .current(_, let endsAt):
            return .active(until: endsAt)
        case .closed(_, let endedAt):
            return .windowClosed(at: endedAt)
        }
    }

    // MARK: - Copy
    //
    // Copy rule: describe the window, not the user. "NOW" and "IN ITS
    // WINDOW" state facts about time; "PRAYING NOW" would claim
    // knowledge the app doesn't have.

    static func inscription(
        for phase: Phase,
        status: PrayerStatus?,
        loggedAt: Date?,
        isJamaah: Bool,
        windowEndTime: Date?,
        scheduledTime: Date,
        now: Date,
        timeZone: TimeZone,
        windowEndDescriptor: String? = nil
    ) -> String {
        switch phase {
        case .active(let until):
            if let windowEndDescriptor {
                return "Now · until \(windowEndDescriptor) \(PlateTimeFormat.time(until, in: timeZone))"
            }
            return "Now · until \(PlateTimeFormat.time(until, in: timeZone))"
        case .upcoming:
            return "Opens in · \(countdown(until: scheduledTime, now: now))"
        case .windowClosed(let end):
            if let end {
                return "Window closed \(PlateTimeFormat.time(end, in: timeZone))"
            }
            return "Window closed"
        case .logged:
            return loggedInscription(
                status: status,
                loggedAt: loggedAt,
                isJamaah: isJamaah,
                windowEndTime: windowEndTime,
                scheduledTime: scheduledTime,
                timeZone: timeZone
            )
        }
    }

    private static func loggedInscription(
        status: PrayerStatus?,
        loggedAt: Date?,
        isJamaah: Bool,
        windowEndTime: Date?,
        scheduledTime: Date,
        timeZone: TimeZone
    ) -> String {
        guard let status else { return "" }
        let jamaahPrefix = isJamaah ? "\(IhsanVocabulary.jamaahTitle) · " : ""
        let loggedClause = loggedAt.map { " · \(PlateTimeFormat.time($0, in: timeZone))" } ?? ""
        switch status {
        case .onTime:
            return "\(jamaahPrefix)On time\(loggedClause)"
        case .late:
            return "\(jamaahPrefix)Late\(loggedClause)"
        case .qada:
            let day = loggedAt.map { " \(PlateTimeFormat.dayMonth($0, in: timeZone))" } ?? ""
            return "Qadā · logged\(day)"
        case .missed:
            return "Window closed \(PlateTimeFormat.time(windowEndTime ?? scheduledTime, in: timeZone))"
        }
    }

    // MARK: - Countdown

    /// H:MM:SS remaining until `target`, rounded UP — so the display
    /// reads 0:00:01 in the final partial second and the phase itself
    /// has already turned by the time zero would appear. 0:00:00 is
    /// unrepresentable as a resting state.
    static func countdown(until target: Date, now: Date) -> String {
        let total = max(1, Int(target.timeIntervalSince(now).rounded(.up)))
        return String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }

    /// VoiceOver phrasing of the same remaining span.
    static func spokenCountdown(until target: Date, now: Date) -> String {
        let total = max(1, Int(target.timeIntervalSince(now).rounded(.up)))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        var parts: [String] = []
        if h > 0 { parts.append("\(h) hour\(h == 1 ? "" : "s")") }
        if m > 0 { parts.append("\(m) minute\(m == 1 ? "" : "s")") }
        if h == 0 { parts.append("\(s) second\(s == 1 ? "" : "s")") }
        return parts.joined(separator: ", ")
    }
}
