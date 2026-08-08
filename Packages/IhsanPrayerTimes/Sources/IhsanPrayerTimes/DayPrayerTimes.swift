import Foundation
import IhsanCore

public struct DayPrayerTimes: Sendable, Equatable {
    /// Civil date this set of times belongs to, represented as start of day in `timeZoneIdentifier`.
    public let date: Date
    public let timeZoneIdentifier: String
    public let coordinates: Coordinates
    public let calculationMethod: CalculationMethodChoice
    public let madhab: MadhabChoice
    public let highLatitudeRule: HighLatitudeRule

    public let fajr: PrayerTime
    public let dhuhr: PrayerTime
    public let asr: PrayerTime
    public let maghrib: PrayerTime
    public let isha: PrayerTime

    public let sunrise: Date
    public let middleOfTheNight: Date
    public let lastThirdOfTheNight: Date

    public init(
        date: Date,
        timeZoneIdentifier: String,
        coordinates: Coordinates,
        calculationMethod: CalculationMethodChoice,
        madhab: MadhabChoice,
        highLatitudeRule: HighLatitudeRule,
        fajr: PrayerTime,
        dhuhr: PrayerTime,
        asr: PrayerTime,
        maghrib: PrayerTime,
        isha: PrayerTime,
        sunrise: Date,
        middleOfTheNight: Date,
        lastThirdOfTheNight: Date
    ) {
        self.date = date
        self.timeZoneIdentifier = timeZoneIdentifier
        self.coordinates = coordinates
        self.calculationMethod = calculationMethod
        self.madhab = madhab
        self.highLatitudeRule = highLatitudeRule
        self.fajr = fajr
        self.dhuhr = dhuhr
        self.asr = asr
        self.maghrib = maghrib
        self.isha = isha
        self.sunrise = sunrise
        self.middleOfTheNight = middleOfTheNight
        self.lastThirdOfTheNight = lastThirdOfTheNight
    }

    /// Returns all five fardh prayer times in chronological order.
    public var allFardh: [PrayerTime] {
        [fajr, dhuhr, asr, maghrib, isha]
    }

    /// Returns the scheduled time for a specific prayer.
    public func time(for prayer: Prayer) -> Date {
        switch prayer {
        case .fajr:
            fajr.scheduledTime
        case .dhuhr:
            dhuhr.scheduledTime
        case .asr:
            asr.scheduledTime
        case .maghrib:
            maghrib.scheduledTime
        case .isha:
            isha.scheduledTime
        }
    }

    /// The exact boundary that closes one prayer's window in this
    /// Fajr-to-Fajr schedule snapshot. Callers supply the next Fajr
    /// because it belongs to the adjacent day table; no consumer is
    /// allowed to invent an Isha lifetime of its own.
    public func windowEnd(for prayer: Prayer, nextFajr: Date) -> Date {
        switch prayer {
        case .fajr:
            sunrise
        case .dhuhr:
            asr.scheduledTime
        case .asr:
            maghrib.scheduledTime
        case .maghrib:
            isha.scheduledTime
        case .isha:
            nextFajr
        }
    }
}
