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
        let dayTimes: DayPrayerTimes
        let nextPrayerTime: PrayerTime
        let isWithinFajrToSunriseWindow: Bool
        let activePrayer: Prayer?
        let ramadanContext: RamadanContext

        var isCurrentlyRamadan: Bool {
            ramadanContext.isCurrentlyRamadan
        }

        var isWithinSuhoorWindow: Bool {
            isCurrentlyRamadan
                && nextPrayerTime.prayer == .fajr
                && !isWithinFajrToSunriseWindow
        }

        var isCountingDownToIftar: Bool {
            isCurrentlyRamadan
                && nextPrayerTime.prayer == .maghrib
                && !isWithinFajrToSunriseWindow
        }
    }
}
