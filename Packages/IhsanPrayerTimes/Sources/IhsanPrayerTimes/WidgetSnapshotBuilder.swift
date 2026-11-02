import Foundation
import IhsanCore

/// Builds the two-day widget snapshot from the same provider, the same
/// settings, and the same bracketing rule the app itself resolves
/// with. The host app supplies the SwiftData-derived facts (logs,
/// Hijri and fasting stamps, the pause); everything temporal is
/// computed here so no second arithmetic path exists between what the
/// Today screen shows and what a widget renders.
///
/// Coordinates arrive in memory and leave nothing behind — the
/// snapshot persists only the resolved city name, timezone, and qibla
/// bearing, per the privacy contract on `LocatedPlace`.
public enum WidgetSnapshotBuilder {

    public struct Facts: Sendable {
        public let hijri: [WidgetSnapshot.HijriStamp]
        public let fasting: [WidgetSnapshot.FastingStamp]
        public let loggedStatusByPrayerRaw: [String: String]
        public let jamaahByPrayerRaw: [String: Bool]
        public let isPaused: Bool
        public let pauseExpectedEnd: Date?
        public let qadaRemaining: Int?

        public init(
            hijri: [WidgetSnapshot.HijriStamp],
            fasting: [WidgetSnapshot.FastingStamp],
            loggedStatusByPrayerRaw: [String: String],
            jamaahByPrayerRaw: [String: Bool],
            isPaused: Bool,
            pauseExpectedEnd: Date?,
            qadaRemaining: Int? = nil
        ) {
            self.hijri = hijri
            self.fasting = fasting
            self.loggedStatusByPrayerRaw = loggedStatusByPrayerRaw
            self.jamaahByPrayerRaw = jamaahByPrayerRaw
            self.isPaused = isPaused
            self.pauseExpectedEnd = pauseExpectedEnd
            self.qadaRemaining = qadaRemaining
        }

        public static let empty = Facts(
            hijri: [],
            fasting: [],
            loggedStatusByPrayerRaw: [:],
            jamaahByPrayerRaw: [:],
            isPaused: false,
            pauseExpectedEnd: nil
        )
    }

    /// The civil days a snapshot built at `now` will carry, so the
    /// caller can assemble Hijri/fasting facts for exactly those days.
    /// "Today" is the day of the prayer cycle containing `now` — before
    /// dawn, yesterday's, whose Isha is still open.
    ///
    /// Three days, not two: the Hijri date and the fasting fact both
    /// turn at Maghrib, so an evening late in the snapshot's run needs
    /// the day after tomorrow to have something to turn INTO.
    public static func coveredDays(
        at now: Date,
        provider: any PrayerTimesProviding,
        coordinates: Coordinates,
        timeZone: TimeZone,
        calculationMethod: CalculationMethodChoice,
        madhab: MadhabChoice,
        highLatitudeRule: HighLatitudeRule,
        tuning: CalculationTuning = .standard
    ) throws -> (today: Date, tomorrow: Date, dayAfterTomorrow: Date) {
        let window = try provider.scheduleWindow(
            for: now,
            coordinates: coordinates,
            timeZone: timeZone,
            calculationMethod: calculationMethod,
            madhab: madhab,
            highLatitudeRule: highLatitudeRule,
            tuning: tuning
        )
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let today = calendar.startOfDay(for: window.cycleDayTimes(at: now).date)
        guard
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: today),
            let dayAfterTomorrow = calendar.date(byAdding: .day, value: 2, to: today)
        else {
            throw PrayerTimesError.invalidDate(
                "Could not advance \(today) in \(timeZone.identifier)."
            )
        }
        return (today, tomorrow, dayAfterTomorrow)
    }

    public static func build(
        at now: Date,
        writtenAt: Date? = nil,
        cityName: String?,
        qiblaBearingDegrees: Double?,
        provider: any PrayerTimesProviding,
        coordinates: Coordinates,
        timeZone: TimeZone,
        calculationMethod: CalculationMethodChoice,
        madhab: MadhabChoice,
        highLatitudeRule: HighLatitudeRule,
        tuning: CalculationTuning = .standard,
        facts: Facts
    ) throws -> WidgetSnapshot {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        // One bracketed window anchors everything, and the snapshot
        // leads with the CYCLE's day, as the Today screen does: before
        // dawn that is yesterday's table. A pre-dawn publish used to
        // lead with the civil day, which hung the previous cycle's logs
        // on the coming day's slots — all of that day, until the app
        // next opened — and handed the night face the coming night
        // instead of the one in progress.
        //
        // The price: a pre-dawn publish now covers to the second Fajr,
        // about 28 hours, where the civil lead reached the 36-hour age
        // limit. Any foreground publishes again.
        let window = try provider.scheduleWindow(
            for: now,
            coordinates: coordinates,
            timeZone: timeZone,
            calculationMethod: calculationMethod,
            madhab: madhab,
            highLatitudeRule: highLatitudeRule,
            tuning: tuning
        )

        func dayTimes(offset: Int) throws -> DayPrayerTimes {
            guard let day = calendar.date(byAdding: .day, value: offset, to: window.day.date) else {
                throw PrayerTimesError.invalidDate(
                    "Could not offset \(window.day.date) by \(offset) day(s) in \(timeZone.identifier)."
                )
            }
            return try provider.dayTimes(
                for: day,
                coordinates: coordinates,
                timeZone: timeZone,
                calculationMethod: calculationMethod,
                madhab: madhab,
                highLatitudeRule: highLatitudeRule,
                tuning: tuning
            )
        }

        let cycle = window.cycle(at: now)
        let isBeforeDawn = now < window.day.fajr.scheduledTime
        let cycleDay = isBeforeDawn ? window.yesterday : window.day
        let nextDay = isBeforeDawn ? window.day : window.tomorrow
        let precedingIsha = try isBeforeDawn
            ? dayTimes(offset: -2).isha.scheduledTime
            : window.yesterdayIsha.scheduledTime
        let dayAfter = try dayTimes(offset: isBeforeDawn ? 1 : 2)

        let today = WidgetSnapshot.DayTable(
            cycleDay,
            civilDayStart: calendar.startOfDay(for: cycleDay.date)
        )
        let tomorrow = WidgetSnapshot.DayTable(
            nextDay,
            civilDayStart: calendar.startOfDay(for: nextDay.date)
        )

        // Consistency guard: the cycle rolls at the second table's Fajr
        // and the third table follows it. If they ever diverge the
        // snapshot must not ship half of each.
        guard
            cycle.rollsAt == tomorrow.fajr,
            calendar.startOfDay(for: dayAfter.date)
                == calendar.date(byAdding: .day, value: 1, to: tomorrow.civilDayStart)
        else {
            throw PrayerTimesError.invalidDate(
                "Cycle boundaries and recomputed days disagree at \(now)."
            )
        }
        let dayAfterFajr = dayAfter.fajr.scheduledTime

        return WidgetSnapshot(
            writtenAt: writtenAt ?? now,
            timeZoneIdentifier: timeZone.identifier,
            cityName: cityName,
            qiblaBearingDegrees: qiblaBearingDegrees,
            yesterdayIsha: precedingIsha,
            cycleDayStart: cycle.date,
            cycleRollsAt: cycle.rollsAt,
            today: today,
            tomorrow: tomorrow,
            dayAfterTomorrowFajr: dayAfterFajr,
            dayAfterTomorrow: WidgetSnapshot.DayTable(
                dayAfter,
                civilDayStart: calendar.startOfDay(for: dayAfter.date)
            ),
            tonight: WidgetSnapshot.NightTable(
                try NightIntervals(maghrib: today.maghrib, nextFajr: tomorrow.fajr)
            ),
            tomorrowNight: WidgetSnapshot.NightTable(
                try NightIntervals(maghrib: tomorrow.maghrib, nextFajr: dayAfterFajr)
            ),
            hijri: facts.hijri,
            fasting: facts.fasting,
            loggedStatusByPrayerRaw: facts.loggedStatusByPrayerRaw,
            jamaahByPrayerRaw: facts.jamaahByPrayerRaw,
            isPaused: facts.isPaused,
            pauseExpectedEnd: facts.pauseExpectedEnd,
            qadaRemaining: facts.qadaRemaining
        )
    }
}
