import Foundation
import IhsanCore

/// Shared prayer-window copy for the focused card and Live Activity.
/// Temporal consumers hand this type resolver boundaries; it only
/// formats those exact instants in the schedule's timezone.
public enum PrayerWindowText {
    public static func windowEndDescriptor(for prayer: Prayer) -> String? {
        prayer == .fajr ? "sunrise" : nil
    }

    public static func activeLine(
        until windowEnd: Date,
        timeZone: TimeZone,
        windowEndDescriptor: String? = nil
    ) -> String {
        let boundary = time(windowEnd, in: timeZone)
        if let windowEndDescriptor {
            return "Now · until \(windowEndDescriptor) \(boundary)"
        }
        return "Now · until \(boundary)"
    }

    public static func time(_ date: Date, in timeZone: TimeZone) -> String {
        var style = Date.FormatStyle(date: .omitted, time: .shortened)
        style.timeZone = timeZone
        return date.formatted(style)
    }
}
