import Foundation

/// Renders a Gregorian date in the Umm al-Qura Hijri calendar (e.g.
/// "21 Dhu al-Qa'dah 1447 AH"). The formatter is constructed per-call so it's
/// safe to use across actors without external synchronization.
enum HijriDateFormatter {
    static func string(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .islamicUmmAlQura)
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
