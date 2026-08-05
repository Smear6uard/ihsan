import Foundation
import IhsanCore

public extension WidgetSnapshot {
    /// The resolver's immutable input for the day bracket containing
    /// `instant` — today's table up to tomorrow's Fajr, tomorrow's
    /// from there to its own terminal Fajr. Nil exactly when the
    /// snapshot is stale for that instant, which callers render as
    /// the "Open Ihsan" state; nothing here ever substitutes an
    /// approximate table.
    ///
    /// Both days rebuild the exact absolute instants the host app
    /// calculated, so `PrayerStateResolver.resolve` returns the same
    /// answer in a widget that it returns on the Today screen — the
    /// one-truth guarantee this family is built on.
    func resolverSchedule(containing instant: Date) -> PrayerStateSchedule? {
        guard let table = dayTable(containing: instant) else { return nil }
        let precedingIsha: Date
        let terminalFajr: Date
        if table == today {
            precedingIsha = yesterdayIsha
            terminalFajr = tomorrow.fajr
        } else {
            precedingIsha = today.isha
            terminalFajr = dayAfterTomorrowFajr
        }
        return PrayerStateSchedule(
            yesterdayIsha: PrayerTime(prayer: .isha, scheduledTime: precedingIsha),
            fajr: PrayerTime(prayer: .fajr, scheduledTime: table.fajr),
            sunrise: table.sunrise,
            dhuhr: PrayerTime(prayer: .dhuhr, scheduledTime: table.dhuhr),
            asr: PrayerTime(prayer: .asr, scheduledTime: table.asr),
            maghrib: PrayerTime(prayer: .maghrib, scheduledTime: table.maghrib),
            isha: PrayerTime(prayer: .isha, scheduledTime: table.isha),
            tomorrowFajr: PrayerTime(prayer: .fajr, scheduledTime: terminalFajr),
            timeZoneIdentifier: timeZoneIdentifier
        )
    }
}

public extension WidgetSnapshot.DayTable {
    /// A day table lifted straight from a calculated day — the only
    /// constructor the publisher uses, so a snapshot can never carry
    /// times that differ from a `DayPrayerTimes` the app displayed.
    init(_ day: DayPrayerTimes, civilDayStart: Date) {
        self.init(
            civilDayStart: civilDayStart,
            fajr: day.fajr.scheduledTime,
            sunrise: day.sunrise,
            dhuhr: day.dhuhr.scheduledTime,
            asr: day.asr.scheduledTime,
            maghrib: day.maghrib.scheduledTime,
            isha: day.isha.scheduledTime
        )
    }
}

public extension WidgetSnapshot.NightTable {
    /// Lifted straight from the app's `NightIntervals` — the widget
    /// never divides a night span itself.
    init(_ night: NightIntervals) {
        self.init(
            start: night.start,
            end: night.end,
            nisfAlLayl: night.nisfAlLayl,
            lastThirdStart: night.lastThirdStart
        )
    }
}
