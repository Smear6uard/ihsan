import Foundation
import IhsanCore

public protocol PrayerTimesProviding: Sendable {
    /// Computes prayer times for the day containing `date`, in the given timezone.
    func dayTimes(
        for date: Date,
        coordinates: Coordinates,
        timeZone: TimeZone,
        calculationMethod: CalculationMethodChoice,
        madhab: MadhabChoice,
        highLatitudeRule: HighLatitudeRule
    ) throws -> DayPrayerTimes

    /// Returns the next upcoming prayer relative to `referenceDate`.
    /// Correctly rolls over to the following day's Fajr after Isha has passed.
    func nextPrayer(
        from referenceDate: Date,
        coordinates: Coordinates,
        timeZone: TimeZone,
        calculationMethod: CalculationMethodChoice,
        madhab: MadhabChoice,
        highLatitudeRule: HighLatitudeRule
    ) throws -> PrayerTime

    /// Returns the prayer whose time window currently contains `referenceDate`,
    /// or nil if before Fajr for this day.
    func currentPrayer(
        at referenceDate: Date,
        coordinates: Coordinates,
        timeZone: TimeZone,
        calculationMethod: CalculationMethodChoice,
        madhab: MadhabChoice,
        highLatitudeRule: HighLatitudeRule
    ) throws -> PrayerTime?

    /// Computes prayer times across a date range (inclusive).
    /// Used for advance notification scheduling and weekly analytics.
    func dayTimesRange(
        from startDate: Date,
        to endDate: Date,
        coordinates: Coordinates,
        timeZone: TimeZone,
        calculationMethod: CalculationMethodChoice,
        madhab: MadhabChoice,
        highLatitudeRule: HighLatitudeRule
    ) throws -> [DayPrayerTimes]
}
