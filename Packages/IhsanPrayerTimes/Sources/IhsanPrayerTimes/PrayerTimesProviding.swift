import Foundation
import IhsanCore

public protocol PrayerTimesProviding: Sendable {
    /// Computes prayer times for the day containing `date`, in the given timezone.
    ///
    /// `tuning` carries the calculation depth — custom twilight angles,
    /// a fixed Isha interval, and per-prayer manual offsets. It defaults
    /// to `.standard`, which is the identity: the named method exactly
    /// as its authority publishes it.
    func dayTimes(
        for date: Date,
        coordinates: Coordinates,
        timeZone: TimeZone,
        calculationMethod: CalculationMethodChoice,
        madhab: MadhabChoice,
        highLatitudeRule: HighLatitudeRule,
        tuning: CalculationTuning
    ) throws -> DayPrayerTimes

    /// Returns the next upcoming prayer relative to `referenceDate`.
    /// Correctly rolls over to the following day's Fajr after Isha has passed.
    func nextPrayer(
        from referenceDate: Date,
        coordinates: Coordinates,
        timeZone: TimeZone,
        calculationMethod: CalculationMethodChoice,
        madhab: MadhabChoice,
        highLatitudeRule: HighLatitudeRule,
        tuning: CalculationTuning
    ) throws -> PrayerTime

    /// Returns the prayer whose time window currently contains `referenceDate`,
    /// or nil if before Fajr for this day.
    func currentPrayer(
        at referenceDate: Date,
        coordinates: Coordinates,
        timeZone: TimeZone,
        calculationMethod: CalculationMethodChoice,
        madhab: MadhabChoice,
        highLatitudeRule: HighLatitudeRule,
        tuning: CalculationTuning
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
        highLatitudeRule: HighLatitudeRule,
        tuning: CalculationTuning
    ) throws -> [DayPrayerTimes]
}

// MARK: - Untuned convenience
//
// The overloads below keep `.standard` a one-word default at every call
// site without putting default arguments in the protocol requirements
// (which would silently let a conformer forget the parameter).

public extension PrayerTimesProviding {
    func dayTimes(
        for date: Date,
        coordinates: Coordinates,
        timeZone: TimeZone,
        calculationMethod: CalculationMethodChoice,
        madhab: MadhabChoice,
        highLatitudeRule: HighLatitudeRule
    ) throws -> DayPrayerTimes {
        try dayTimes(
            for: date,
            coordinates: coordinates,
            timeZone: timeZone,
            calculationMethod: calculationMethod,
            madhab: madhab,
            highLatitudeRule: highLatitudeRule,
            tuning: .standard
        )
    }

    func nextPrayer(
        from referenceDate: Date,
        coordinates: Coordinates,
        timeZone: TimeZone,
        calculationMethod: CalculationMethodChoice,
        madhab: MadhabChoice,
        highLatitudeRule: HighLatitudeRule
    ) throws -> PrayerTime {
        try nextPrayer(
            from: referenceDate,
            coordinates: coordinates,
            timeZone: timeZone,
            calculationMethod: calculationMethod,
            madhab: madhab,
            highLatitudeRule: highLatitudeRule,
            tuning: .standard
        )
    }

    func currentPrayer(
        at referenceDate: Date,
        coordinates: Coordinates,
        timeZone: TimeZone,
        calculationMethod: CalculationMethodChoice,
        madhab: MadhabChoice,
        highLatitudeRule: HighLatitudeRule
    ) throws -> PrayerTime? {
        try currentPrayer(
            at: referenceDate,
            coordinates: coordinates,
            timeZone: timeZone,
            calculationMethod: calculationMethod,
            madhab: madhab,
            highLatitudeRule: highLatitudeRule,
            tuning: .standard
        )
    }

    func dayTimesRange(
        from startDate: Date,
        to endDate: Date,
        coordinates: Coordinates,
        timeZone: TimeZone,
        calculationMethod: CalculationMethodChoice,
        madhab: MadhabChoice,
        highLatitudeRule: HighLatitudeRule
    ) throws -> [DayPrayerTimes] {
        try dayTimesRange(
            from: startDate,
            to: endDate,
            coordinates: coordinates,
            timeZone: timeZone,
            calculationMethod: calculationMethod,
            madhab: madhab,
            highLatitudeRule: highLatitudeRule,
            tuning: .standard
        )
    }
}
