import Adhan
import Foundation
import IhsanCore

public struct AdhanPrayerTimesProvider: PrayerTimesProviding {
    public init() {}

    public func dayTimes(
        for date: Date,
        coordinates: Coordinates,
        timeZone: TimeZone,
        calculationMethod: CalculationMethodChoice,
        madhab: MadhabChoice,
        highLatitudeRule: IhsanCore.HighLatitudeRule
    ) throws -> DayPrayerTimes {
        try validate(coordinates: coordinates)
        try validate(timeZone: timeZone)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        guard let startOfDay = calendar.dateInterval(of: .day, for: date)?.start else {
            throw PrayerTimesError.invalidDate("Could not determine start of day in \(timeZone.identifier).")
        }

        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        guard dateComponents.year != nil, dateComponents.month != nil, dateComponents.day != nil else {
            throw PrayerTimesError.invalidDate("Date must resolve to Gregorian year, month, and day components.")
        }

        var parameters = try calculationMethod.toAdhanCalculationParameters()
        parameters.madhab = madhab.toAdhanMadhab()
        parameters.highLatitudeRule = highLatitudeRule.toAdhanHighLatitudeRule()

        let adhanCoordinates = Adhan.Coordinates(
            latitude: coordinates.latitude,
            longitude: coordinates.longitude
        )

        guard let prayerTimes = Adhan.PrayerTimes(
            coordinates: adhanCoordinates,
            date: dateComponents,
            calculationParameters: parameters
        ) else {
            throw PrayerTimesError.calculationFailed(
                underlying: "Adhan-Swift could not compute prayer times for \(coordinates.latitude), \(coordinates.longitude) on \(startOfDay)."
            )
        }

        guard let sunnahTimes = Adhan.SunnahTimes(from: prayerTimes) else {
            throw PrayerTimesError.calculationFailed(
                underlying: "Adhan-Swift could not compute sunnah times for \(coordinates.latitude), \(coordinates.longitude) on \(startOfDay)."
            )
        }

        return DayPrayerTimes(
            date: startOfDay,
            timeZoneIdentifier: timeZone.identifier,
            coordinates: coordinates,
            calculationMethod: calculationMethod,
            madhab: madhab,
            highLatitudeRule: highLatitudeRule,
            fajr: PrayerTime(prayer: .fajr, scheduledTime: prayerTimes.fajr),
            dhuhr: PrayerTime(prayer: .dhuhr, scheduledTime: prayerTimes.dhuhr),
            asr: PrayerTime(prayer: .asr, scheduledTime: prayerTimes.asr),
            maghrib: PrayerTime(prayer: .maghrib, scheduledTime: prayerTimes.maghrib),
            isha: PrayerTime(prayer: .isha, scheduledTime: prayerTimes.isha),
            sunrise: prayerTimes.sunrise,
            middleOfTheNight: sunnahTimes.middleOfTheNight,
            lastThirdOfTheNight: sunnahTimes.lastThirdOfTheNight
        )
    }

    public func nextPrayer(
        from referenceDate: Date,
        coordinates: Coordinates,
        timeZone: TimeZone,
        calculationMethod: CalculationMethodChoice,
        madhab: MadhabChoice,
        highLatitudeRule: IhsanCore.HighLatitudeRule
    ) throws -> PrayerTime {
        let window = try scheduleWindow(
            for: referenceDate,
            coordinates: coordinates,
            timeZone: timeZone,
            calculationMethod: calculationMethod,
            madhab: madhab,
            highLatitudeRule: highLatitudeRule
        )
        return PrayerStateResolver.resolve(
            prayerTimes: window.resolverSchedule,
            now: referenceDate
        ).nextPrayer
    }

    public func currentPrayer(
        at referenceDate: Date,
        coordinates: Coordinates,
        timeZone: TimeZone,
        calculationMethod: CalculationMethodChoice,
        madhab: MadhabChoice,
        highLatitudeRule: IhsanCore.HighLatitudeRule
    ) throws -> PrayerTime? {
        // Window-aware: pre-dawn hours belong to yesterday's Isha, the
        // forenoon gap [sunrise, dhuhr) belongs to no one, and every
        // window is half-open so boundaries transition atomically.
        let window = try scheduleWindow(
            for: referenceDate,
            coordinates: coordinates,
            timeZone: timeZone,
            calculationMethod: calculationMethod,
            madhab: madhab,
            highLatitudeRule: highLatitudeRule
        )
        return PrayerStateResolver.resolve(
            prayerTimes: window.resolverSchedule,
            now: referenceDate
        ).currentPrayer
    }

    public func dayTimesRange(
        from startDate: Date,
        to endDate: Date,
        coordinates: Coordinates,
        timeZone: TimeZone,
        calculationMethod: CalculationMethodChoice,
        madhab: MadhabChoice,
        highLatitudeRule: IhsanCore.HighLatitudeRule
    ) throws -> [DayPrayerTimes] {
        guard startDate <= endDate else {
            throw PrayerTimesError.invalidDate("startDate must be before or equal to endDate.")
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        guard
            let startDay = calendar.dateInterval(of: .day, for: startDate)?.start,
            let endDay = calendar.dateInterval(of: .day, for: endDate)?.start
        else {
            throw PrayerTimesError.invalidDate("Could not resolve date range in \(timeZone.identifier).")
        }

        let dayCount = calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0
        guard dayCount <= 365 else {
            throw PrayerTimesError.invalidDate("Date range cannot exceed 366 inclusive days.")
        }

        var result: [DayPrayerTimes] = []
        result.reserveCapacity(dayCount + 1)

        var currentDay = startDay
        while currentDay <= endDay {
            result.append(
                try dayTimes(
                    for: currentDay,
                    coordinates: coordinates,
                    timeZone: timeZone,
                    calculationMethod: calculationMethod,
                    madhab: madhab,
                    highLatitudeRule: highLatitudeRule
                )
            )

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDay) else {
                throw PrayerTimesError.invalidDate("Could not advance date range cursor in \(timeZone.identifier).")
            }
            currentDay = nextDay
        }

        return result
    }
}

private func validate(coordinates: Coordinates) throws {
    guard coordinates.latitude.isFinite, coordinates.longitude.isFinite else {
        throw PrayerTimesError.invalidCoordinates("Latitude and longitude must be finite numbers.")
    }
    guard (-90...90).contains(coordinates.latitude) else {
        throw PrayerTimesError.invalidCoordinates("Latitude must be between -90 and 90 degrees.")
    }
    guard (-180...180).contains(coordinates.longitude) else {
        throw PrayerTimesError.invalidCoordinates("Longitude must be between -180 and 180 degrees.")
    }
}

private func validate(timeZone: TimeZone) throws {
    guard !timeZone.identifier.isEmpty else {
        throw PrayerTimesError.invalidTimeZone("Time zone identifier cannot be empty.")
    }
}
