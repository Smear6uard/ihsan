import Foundation
import IhsanLocation
import IhsanPrayerTimes

/// Drives every visual state of the Qibla screen. The dial, info panel, and
/// calibration hint are derived from this enum plus the live heading on the
/// view model.
enum QiblaState: Equatable {
    case loading
    case needsLocationPermission
    case ready(Snapshot)
    /// Hardware lacks a magnetometer (iPad without compass, Mac, or
    /// some simulator configurations). Bearing + distance are still
    /// known from the device's location; only the live heading dial
    /// is suppressed.
    case compassUnavailable(Snapshot)
    case error(String)

    struct Snapshot: Equatable {
        let cityName: String?
        let coordinates: Coordinates
        /// Bearing from the user's location to the Kaaba, in degrees from
        /// true north. Fixed for a given location — never changes with
        /// device heading.
        let qiblaBearing: Double
        /// Great-circle distance to the Kaaba in kilometers.
        let distanceToMakkahKm: Double
    }
}
