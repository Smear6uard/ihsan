import Foundation
import IhsanCore

/// The canonical gallery day — the same Chicago mid-July day every
/// other gallery frame in this repo uses — anchored to the viewer's
/// current day so countdowns in the widget gallery read believably.
///
/// This is a `WidgetSnapshot` like any other and flows through the
/// same composer and the same resolver as live data: the gallery
/// preview exercises the real machinery, only the table is stylized.
enum GalleryDay {
    static func snapshot(anchoredTo now: Date = .now) -> WidgetSnapshot {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        let dayStart = calendar.startOfDay(for: now)

        func at(_ day: Int, _ hour: Int, _ minute: Int) -> Date {
            calendar.date(
                byAdding: DateComponents(day: day, hour: hour, minute: minute),
                to: dayStart
            ) ?? dayStart
        }

        let today = WidgetSnapshot.DayTable(
            civilDayStart: dayStart,
            fajr: at(0, 4, 10),
            sunrise: at(0, 5, 42),
            dhuhr: at(0, 12, 58),
            asr: at(0, 16, 53),
            maghrib: at(0, 20, 11),
            isha: at(0, 21, 43)
        )
        let tomorrow = WidgetSnapshot.DayTable(
            civilDayStart: at(1, 0, 0),
            fajr: at(1, 4, 11),
            sunrise: at(1, 5, 43),
            dhuhr: at(1, 12, 58),
            asr: at(1, 16, 52),
            maghrib: at(1, 20, 10),
            isha: at(1, 21, 41)
        )
        let dayAfterFajr = at(2, 4, 12)

        func night(from maghrib: Date, to fajr: Date) -> WidgetSnapshot.NightTable {
            let span = fajr.timeIntervalSince(maghrib)
            return WidgetSnapshot.NightTable(
                start: maghrib,
                end: fajr,
                nisfAlLayl: maghrib.addingTimeInterval(span / 2),
                lastThirdStart: maghrib.addingTimeInterval(span * 2 / 3)
            )
        }

        return WidgetSnapshot(
            writtenAt: now,
            timeZoneIdentifier: TimeZone.current.identifier,
            cityName: "Madinah",
            qiblaBearingDegrees: 176,
            yesterdayIsha: at(-1, 21, 44),
            cycleDayStart: today.civilDayStart,
            cycleRollsAt: tomorrow.fajr,
            today: today,
            tomorrow: tomorrow,
            dayAfterTomorrowFajr: dayAfterFajr,
            tonight: night(from: today.maghrib, to: tomorrow.fajr),
            tomorrowNight: night(from: tomorrow.maghrib, to: dayAfterFajr),
            hijri: [
                WidgetSnapshot.HijriStamp(
                    civilDayStart: today.civilDayStart,
                    eveningTurn: today.maghrib,
                    day: 13,
                    monthName: "Safar",
                    year: 1448,
                    significantLine: "White day · Safar 13",
                    isRamadan: false
                ),
                WidgetSnapshot.HijriStamp(
                    civilDayStart: tomorrow.civilDayStart,
                    eveningTurn: tomorrow.maghrib,
                    day: 14,
                    monthName: "Safar",
                    year: 1448,
                    significantLine: "White day · Safar 14",
                    isRamadan: false
                ),
            ],
            fasting: [
                WidgetSnapshot.FastingStamp(
                    civilDayStart: today.civilDayStart, eveningTurn: today.maghrib,
                    isFasting: false, isRamadan: false
                ),
                WidgetSnapshot.FastingStamp(
                    civilDayStart: tomorrow.civilDayStart, eveningTurn: tomorrow.maghrib,
                    isFasting: false, isRamadan: false
                ),
            ],
            loggedStatusByPrayerRaw: [
                Prayer.fajr.rawValue: PrayerStatus.onTime.rawValue,
                Prayer.dhuhr.rawValue: PrayerStatus.onTime.rawValue,
            ],
            jamaahByPrayerRaw: [Prayer.dhuhr.rawValue: true],
            isPaused: false,
            pauseExpectedEnd: nil,
            qadaRemaining: nil
        )
    }
}
