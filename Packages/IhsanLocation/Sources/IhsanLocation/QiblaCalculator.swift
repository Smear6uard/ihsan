import Foundation
import IhsanPrayerTimes

public enum QiblaCalculator {
    /// Coordinates of the Kaaba in Makkah.
    public static let kaabaCoordinates = Coordinates(
        latitude: 21.4225,
        longitude: 39.8262
    )

    /// Returns the great-circle initial bearing from `origin` to the
    /// Kaaba, in degrees from true north (0-360).
    ///
    /// Uses the standard spherical-earth bearing formula. For Qibla
    /// purposes, the spherical approximation is more than sufficient.
    public static func bearingToKaaba(from origin: Coordinates) -> Double {
        bearing(from: origin, to: kaabaCoordinates)
    }

    /// Generic great-circle initial bearing from one coordinate to another.
    public static func bearing(from origin: Coordinates, to destination: Coordinates) -> Double {
        let lat1 = origin.latitude * .pi / 180
        let lat2 = destination.latitude * .pi / 180
        let deltaLon = (destination.longitude - origin.longitude) * .pi / 180

        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        let radians = atan2(y, x)
        let degrees = radians * 180 / .pi
        return (degrees + 360).truncatingRemainder(dividingBy: 360)
    }

    /// Distance in kilometers from `origin` to the Kaaba (great-circle).
    public static func distanceToKaaba(from origin: Coordinates) -> Double {
        distance(from: origin, to: kaabaCoordinates)
    }

    /// Generic great-circle distance in kilometers.
    public static func distance(from a: Coordinates, to b: Coordinates) -> Double {
        let earthRadiusKm = 6371.0
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let deltaLat = (b.latitude - a.latitude) * .pi / 180
        let deltaLon = (b.longitude - a.longitude) * .pi / 180

        let h = sin(deltaLat / 2) * sin(deltaLat / 2)
            + cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2)
        let c = 2 * atan2(sqrt(h), sqrt(1 - h))
        return earthRadiusKm * c
    }
}

public extension Coordinates {
    /// The great-circle bearing from this location to the Kaaba,
    /// in degrees from true north.
    var qiblaBearing: Double {
        QiblaCalculator.bearingToKaaba(from: self)
    }

    /// The great-circle distance from this location to the Kaaba,
    /// in kilometers.
    var distanceToKaaba: Double {
        QiblaCalculator.distanceToKaaba(from: self)
    }
}
