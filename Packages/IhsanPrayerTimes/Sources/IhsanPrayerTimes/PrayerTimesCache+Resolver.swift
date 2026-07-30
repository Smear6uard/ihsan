import Foundation
import IhsanCore

public extension PrayerTimesCache {
    /// Rebuild the resolver's immutable input from the exact table
    /// calculated by the host app. No coordinates or calculation
    /// parameters are persisted or recomputed in an extension.
    var resolverSchedule: PrayerStateSchedule? {
        guard
            let previousDayIsha,
            let sunrise,
            let nextDayFajr
        else { return nil }

        let parsed: [Prayer: Date] = entries.reduce(into: [:]) { result, entry in
            guard let prayer = Prayer(rawValue: entry.prayerRaw) else { return }
            result[prayer] = entry.scheduledTime
        }
        guard
            let fajr = parsed[.fajr],
            let dhuhr = parsed[.dhuhr],
            let asr = parsed[.asr],
            let maghrib = parsed[.maghrib],
            let isha = parsed[.isha]
        else { return nil }

        return PrayerStateSchedule(
            yesterdayIsha: PrayerTime(prayer: .isha, scheduledTime: previousDayIsha),
            fajr: PrayerTime(prayer: .fajr, scheduledTime: fajr),
            sunrise: sunrise,
            dhuhr: PrayerTime(prayer: .dhuhr, scheduledTime: dhuhr),
            asr: PrayerTime(prayer: .asr, scheduledTime: asr),
            maghrib: PrayerTime(prayer: .maghrib, scheduledTime: maghrib),
            isha: PrayerTime(prayer: .isha, scheduledTime: isha),
            tomorrowFajr: PrayerTime(prayer: .fajr, scheduledTime: nextDayFajr),
            timeZoneIdentifier: timeZoneIdentifier
        )
    }
}
