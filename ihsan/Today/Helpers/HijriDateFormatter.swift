import Foundation
import IhsanCore

/// Renders a Gregorian date in the Hijri calendar (e.g. "Safar 14,
/// 1448 AH") through THE one converter, with the user's published
/// moonsighting adjustment applied — every surface that names a
/// Hijri date reads the same mapping.
enum HijriDateFormatter {
    /// Resolved in the PLACE's timezone, published beside the evening
    /// boundaries. The Hijri day turns where the sun set, and a device
    /// carried across a timezone must not turn it somewhere else.
    static func string(from date: Date) -> String {
        HijriConverter.string(
            for: date,
            offsetDays: HijriDisplay.offsetDays,
            timeZone: HijriDisplay.timeZone ?? .current
        )
    }
}
