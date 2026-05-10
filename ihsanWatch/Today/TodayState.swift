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
        let nextPrayer: PrayerTime
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
}
