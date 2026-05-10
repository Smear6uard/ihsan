import IhsanCore

/// Canonical ordering used by every Today/complication surface.
/// Defined once so screens can index it via Digital Crown rotation
/// without re-deriving the order in each call site.
enum PrayerListOrder {
    static let all: [Prayer] = [.fajr, .dhuhr, .asr, .maghrib, .isha]
}
