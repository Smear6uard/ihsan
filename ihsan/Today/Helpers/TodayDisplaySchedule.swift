import Foundation
import IhsanCore
import IhsanPrayerTimes

/// THE one source of the instant every Today surface displays for a
/// prayer — plate marker labels, the header's "NEXT:", the focused
/// card, and the log sheet all read this, and
/// `TodayMomentDerivationTests` pins it to agree with
/// `PrayerMoment.next` at every minute of the day.
///
/// The rule: each prayer displays today's instance, except Fajr rolls
/// to tomorrow's the moment Isha's window opens — from then on
/// "Fajr" everywhere on the surface means the Fajr the night is
/// heading toward, which is the instant `moment(at:)` already
/// returns as `next`. Fajr's times drift by about a minute per day,
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
        now: Date
    ) -> Bool {
        prayer == .fajr && now >= window.day.isha.scheduledTime
    }

    /// The instant surfaces display for `prayer` at `now` — same
    /// source, same rounding (Adhan's whole-minute instants), and
    /// every caller formats it through `PlateTimeFormat`.
    static func displayTime(
        for prayer: Prayer,
        window: PrayerScheduleWindow,
        now: Date
    ) -> Date {
        isRolledToTomorrow(prayer, window: window, now: now)
            ? window.tomorrowFajr.scheduledTime
            : window.day.time(for: prayer)
    }
}
