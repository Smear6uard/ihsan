import Foundation
import IhsanCore

// Additive night conveniences on top of the existing day computation.
// The five-prayer paths are untouched: these compose dayTimes outputs only.
public extension PrayerTimesProviding {
    /// The night beginning at Maghrib of the day containing `date`, ending at
    /// the following day's true Fajr, computed with the same method, madhab,
    /// and high-latitude rule as the fard times.
    func nightIntervals(
        for date: Date,
        coordinates: Coordinates,
        timeZone: TimeZone,
        calculationMethod: CalculationMethodChoice,
        madhab: MadhabChoice,
        highLatitudeRule: HighLatitudeRule
    ) throws -> NightIntervals {
        let today = try dayTimes(
            for: date,
            coordinates: coordinates,
            timeZone: timeZone,
            calculationMethod: calculationMethod,
            madhab: madhab,
            highLatitudeRule: highLatitudeRule
        )

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: today.date) else {
            throw PrayerTimesError.invalidDate("Could not advance to the next day in \(timeZone.identifier).")
        }

        let tomorrow = try dayTimes(
            for: nextDay,
            coordinates: coordinates,
            timeZone: timeZone,
            calculationMethod: calculationMethod,
            madhab: madhab,
            highLatitudeRule: highLatitudeRule
        )

        return try NightIntervals(
            maghrib: today.maghrib.scheduledTime,
            nextFajr: tomorrow.fajr.scheduledTime
        )
    }

    /// The duha window for the day containing `date`, or nil when the offsets
    /// leave no room between sunrise and Dhuhr.
    func duhaWindow(
        for date: Date,
        coordinates: Coordinates,
        timeZone: TimeZone,
        calculationMethod: CalculationMethodChoice,
        madhab: MadhabChoice,
        highLatitudeRule: HighLatitudeRule,
        sunriseOffset: TimeInterval = 20 * 60,
        dhuhrMargin: TimeInterval = 15 * 60
    ) throws -> DuhaWindow? {
        let today = try dayTimes(
            for: date,
            coordinates: coordinates,
            timeZone: timeZone,
            calculationMethod: calculationMethod,
            madhab: madhab,
            highLatitudeRule: highLatitudeRule
        )

        return DuhaWindow(
            sunrise: today.sunrise,
            dhuhr: today.dhuhr.scheduledTime,
            sunriseOffset: sunriseOffset,
            dhuhrMargin: dhuhrMargin
        )
    }
}
