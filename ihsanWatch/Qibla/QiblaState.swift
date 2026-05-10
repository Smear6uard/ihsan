import Foundation
import IhsanLocation
import IhsanPrayerTimes

/// Drives every visual state of the Qibla screen. Mirrors iOS but
/// with one extra terminal state — `compassUnavailable` — covering
/// the watch hardware models (Series 3/4, original SE) that ship
/// without a magnetometer.
enum QiblaState: Equatable {
    case loading
    case needsLocationPermission
    case compassUnavailable(Snapshot)
    case ready(Snapshot)
    case error(String)

    struct Snapshot: Equatable {
        let cityName: String?
        let coordinates: Coordinates
        let qiblaBearing: Double
        let distanceToMakkahKm: Double
    }
}
