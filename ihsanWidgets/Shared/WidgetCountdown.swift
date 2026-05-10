import Foundation
import SwiftUI

/// Hand-formatted countdown strings for places where SwiftUI's auto-
/// updating `Text(_:style: .timer)` is too verbose (e.g. lock screen
/// circular widgets, snapshot/placeholder rendering).
///
/// For surfaces that should tick visibly (the small/medium/large home
/// widgets and the rectangular lock screen widget) prefer `Text(_:style:
/// .timer)` so the system updates the display without rebuilding the
/// timeline entry.
enum WidgetCountdown {
    /// "1h 23m" / "23m" / "in 30s". Compact form suited to small surfaces.
    static func compact(secondsUntil: TimeInterval) -> String {
        let total = max(0, Int(secondsUntil))
        if total == 0 {
            return "now"
        }
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "<1m"
        }
    }

    /// "in 1h 23m" — same as compact, prefixed.
    static func phrasedIn(secondsUntil: TimeInterval) -> String {
        let total = max(0, Int(secondsUntil))
        if total == 0 {
            return "now"
        }
        return "in \(compact(secondsUntil: secondsUntil))"
    }

    /// Wall-clock "4:32 PM" formatter. Caller passes the prayer time;
    /// we format in the device's current locale and time zone.
    static func clockTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}
