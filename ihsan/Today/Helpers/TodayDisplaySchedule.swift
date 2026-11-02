import Foundation
import IhsanCore
import IhsanPrayerTimes

/// THE one source of the prayer instances every Today surface displays.
///
/// The plate, focused card, statuses, and voluntary-night context stay
/// on the cycle whose Fajr opened most recently — the record. Midnight
/// is deliberately absent: 11:59 PM and 12:01 AM present the same five
/// prayer instances and the same logs.
///
/// One instance looks ahead. From the moment the cycle's Isha opens,
/// "Fajr" on every surface means the Fajr that closes the cycle — the
/// one the header's NEXT already names — and the sunrise beside it is
/// that Fajr's sunrise. Before this rule was restored the plate printed
/// the morning's Fajr all night: a minute off the header most nights,
/// an hour off on the night daylight saving ends.
enum TodayDisplaySchedule {

    /// The UI-facing resolution contains the exact five instances on
    /// the plate, including yesterday's still-open Isha before dawn,
    /// and the closing Fajr as the upcoming terminal instance.
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

    /// The exact prayer instance the surfaces show for `prayer` at
    /// `now`. The cycle's own, except Fajr after Isha has opened.
    static func prayerTime(
        for prayer: Prayer,
        window: PrayerScheduleWindow,
        now: Date
    ) -> PrayerTime {
        window.displayedPrayerTime(of: prayer, at: now)
    }

    /// The instant every downstream surface formats for `prayer`.
    static func displayTime(
        for prayer: Prayer,
        window: PrayerScheduleWindow,
        now: Date
    ) -> Date {
        prayerTime(for: prayer, window: window, now: now).scheduledTime
    }

    /// Whether the instance shown for `prayer` is the dawn ahead rather
    /// than the cycle's own. A shown instance that looks ahead carries
    /// no log: the morning's record stays the morning's, and nothing
    /// may be committed against a window that has not opened.
    static func looksAhead(
        _ prayer: Prayer,
        window: PrayerScheduleWindow,
        now: Date
    ) -> Bool {
        prayer == .fajr && window.namesClosingFajr(at: now)
    }

    /// The sunrise printed beside the displayed Fajr.
    static func sunrise(window: PrayerScheduleWindow, now: Date) -> Date {
        window.displayedSunrise(at: now)
    }

    /// Whether the screen's record queries, keyed when the view was
    /// built at `dayAnchor`, name a different cycle from the one `now`
    /// is in. A window built before dawn stays valid through the whole
    /// next day — it is never exhausted at Fajr — so without this the
    /// queries kept the night before's cycle all day.
    static func needsReanchor(
        window: PrayerScheduleWindow,
        dayAnchor: Date,
        now: Date
    ) -> Bool {
        window.cycle(at: now).date != window.cycle(at: dayAnchor).date
    }
}
