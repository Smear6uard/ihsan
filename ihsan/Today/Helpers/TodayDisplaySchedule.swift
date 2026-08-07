import Foundation
import IhsanCore
import IhsanPrayerTimes

/// THE one source of the Fajr-to-Fajr cycle every Today surface displays.
///
/// The plate, focused card, log sheet, statuses, and voluntary-night
/// context stay on the cycle whose Fajr opened most recently. Midnight
/// is deliberately absent. The whole plate advances only when the next
/// Fajr opens, so 11:59 PM and 12:01 AM present the same five prayer
/// instances and the same logs.
enum TodayDisplaySchedule {

    /// The UI-facing resolution contains the exact five instances on
    /// the plate, including yesterday's still-open Isha before dawn.
    static func resolve(
        window: PrayerScheduleWindow,
        now: Date
    ) -> PrayerResolution {
        let cycle = window.cycle(at: now)
        let closingFajr = PrayerTime(prayer: .fajr, scheduledTime: cycle.rollsAt)
        return PrayerStateResolver.resolve(
            cycleDay: window.cycleDayTimes(at: now),
            nextFajr: closingFajr,
            now: now
        )
    }

    /// The exact prayer instance in the cycle containing `now`.
    static func prayerTime(
        for prayer: Prayer,
        window: PrayerScheduleWindow,
        now: Date
    ) -> PrayerTime {
        window.cycleDayTimes(at: now).allFardh.first { $0.prayer == prayer }!
    }

    /// The instant every downstream surface formats for `prayer`.
    static func displayTime(
        for prayer: Prayer,
        window: PrayerScheduleWindow,
        now: Date
    ) -> Date {
        prayerTime(for: prayer, window: window, now: now).scheduledTime
    }
}
