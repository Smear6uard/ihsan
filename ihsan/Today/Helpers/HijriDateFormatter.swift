import Foundation
import IhsanCore

/// Renders a Gregorian date in the Hijri calendar (e.g. "Safar 14,
/// 1448 AH") through THE one converter, with the user's published
/// moonsighting adjustment applied — every surface that names a
/// Hijri date reads the same mapping.
enum HijriDateFormatter {
    static func string(from date: Date) -> String {
        HijriConverter.string(
            for: date, offsetDays: HijriDisplay.offsetDays
        )
    }
}
