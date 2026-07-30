import Foundation
import IhsanCore
import IhsanPrayerTimes

/// THE one source of the instant every Today surface displays for a
/// prayer — plate marker labels, the header's "NEXT:", the focused
/// card, and the log sheet all read this, and
/// `TodayMomentDerivationTests` pins it to agree with the one
/// `PrayerResolution` at every minute of the day.
///
/// The rule: each prayer displays today's instance, except Fajr rolls
/// to tomorrow's the moment Isha's window opens — from then on
/// "Fajr" everywhere on the surface means the Fajr the night is
/// heading toward, which is the instant `PrayerStateResolver`
/// returns as `nextPrayer`. Fajr's times drift by about a minute per day,
/// so two surfaces disagreeing about *which* Fajr produces the
/// 4:20/4:21 split this rule exists to prevent.
enum TodayDisplaySchedule {

    /// Whether this prayer's displayed instance has rolled into
    /// tomorrow. A rolled prayer is upcoming by definition: today's
    /// log no longer attaches to it, and no logging is offered on it
    /// until its window opens.
    static func isRolledToTomorrow(
        _ prayer: Prayer,
        window: PrayerScheduleWindow,
        resolution: PrayerResolution
    ) -> Bool {
        prayer == .fajr && resolution.nextPrayer == window.tomorrowFajr
    }

    /// The exact instance every downstream surface must use to ask
    /// the resolver for state. Keeping the `PrayerTime` (not just its
    /// date) prevents today's and tomorrow's Fajr from being conflated.
    static func prayerTime(
        for prayer: Prayer,
        window: PrayerScheduleWindow,
        resolution: PrayerResolution
    ) -> PrayerTime {
        isRolledToTomorrow(prayer, window: window, resolution: resolution)
            ? window.tomorrowFajr
            : window.day.allFardh.first { $0.prayer == prayer }!
    }

    /// The instant surfaces display for `prayer` at `now` — same
    /// source, same rounding (Adhan's whole-minute instants), and
    /// every caller formats it through `PlateTimeFormat`.
    static func displayTime(
        for prayer: Prayer,
        window: PrayerScheduleWindow,
        resolution: PrayerResolution
    ) -> Date {
        prayerTime(for: prayer, window: window, resolution: resolution).scheduledTime
    }
}
