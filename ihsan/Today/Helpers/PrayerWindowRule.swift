import IhsanCore

/// Copy-only metadata for named boundaries. Temporal boundaries come
/// exclusively from `PrayerStateResolver`; this helper never resolves
/// or compares time.
enum PrayerWindowRule {
    /// The named event a prayer's window ends at, when that event is
    /// not simply the next prayer's adhan. Fajr ends at SUNRISE — the
    /// card's active inscription names it ("Now · until sunrise 5:47
    /// AM") so the boundary reads as the solar fact it is.
    static func windowEndDescriptor(for prayer: Prayer) -> String? {
        prayer == .fajr ? "sunrise" : nil
    }
}
