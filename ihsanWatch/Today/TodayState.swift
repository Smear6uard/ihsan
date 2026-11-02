import Foundation
import IhsanCore
import IhsanLocation
import IhsanPrayerTimes

enum TodayState {
    case loading
    case needsLocationPermission
    case ready(Snapshot)
    case error(String)

    struct Snapshot {
        let place: LocatedPlace
        let scheduleWindow: PrayerScheduleWindow
        /// Map from prayer to logged status, if a log exists for today.
        /// `nil` value means the prayer has not yet been logged.
        let statuses: [Prayer: PrayerStatus?]
        /// Map from prayer to whether it was logged with jama'ah.
        let jamaah: [Prayer: Bool]
    }
}

extension TodayState.Snapshot {
    func status(for prayer: Prayer) -> PrayerStatus? {
        statuses[prayer] ?? nil
    }

    func isJamaah(for prayer: Prayer) -> Bool {
        jamaah[prayer] ?? false
    }

    /// Whether the watch is showing the dawn ahead for `prayer` — Fajr,
    /// from the cycle's Isha onward. The same rule the phone's plate
    /// and the widgets read, so all three name one Fajr.
    func looksAhead(_ prayer: Prayer, at instant: Date) -> Bool {
        prayer == .fajr && scheduleWindow.namesClosingFajr(at: instant)
    }

    /// The instance the watch prints for `prayer`.
    func displayedPrayerTime(for prayer: Prayer, at instant: Date) -> PrayerTime {
        scheduleWindow.displayedPrayerTime(of: prayer, at: instant)
    }

    /// The record for the instance on screen. The morning's Fajr log is
    /// not the log of the Fajr ahead.
    func status(for prayer: Prayer, at instant: Date) -> PrayerStatus? {
        looksAhead(prayer, at: instant) ? nil : status(for: prayer)
    }

    func isJamaah(for prayer: Prayer, at instant: Date) -> Bool {
        looksAhead(prayer, at: instant) ? false : isJamaah(for: prayer)
    }
}
