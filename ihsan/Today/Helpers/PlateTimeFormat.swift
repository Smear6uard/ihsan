import Foundation

/// The one clock-time formatter for the Today surface.
///
/// The header's "NEXT:" inscription, the plate's marker labels, and
/// the focused card all format prayer instants through this — same
/// style, same timezone — so no two surfaces can ever disagree about
/// a time to the minute. Prayer times are absolute instants; the
/// place's timezone, not the device's, is the display frame.
enum PlateTimeFormat {
    static func time(_ date: Date, in timeZone: TimeZone) -> String {
        var style = Date.FormatStyle(date: .omitted, time: .shortened)
        style.timeZone = timeZone
        return date.formatted(style)
    }

    /// Day-month inscription for qadā log lines ("29 JUL").
    static func dayMonth(_ date: Date, in timeZone: TimeZone) -> String {
        var style = Date.FormatStyle(date: .abbreviated, time: .omitted)
        style.timeZone = timeZone
        return date.formatted(
            style.day(.defaultDigits).month(.abbreviated).year(.omitted)
        ).uppercased()
    }
}
