import Foundation

/// Pure spherical math for the qibla instrument. No CoreLocation, no UI —
/// plain degrees in, plain degrees out, so every consumer (iOS view model,
/// watch, tests) shares one set of formulas.
public enum QiblaMath {
    /// Coordinates of the Kaaba in Makkah.
    public static let kaabaLatitude = 21.4225
    public static let kaabaLongitude = 39.8262

    /// Mean Earth radius in kilometers, for the haversine distance.
    private static let earthRadiusKm = 6371.0

    /// Great-circle initial bearing from the given point to the Kaaba,
    /// in degrees from true north, [0, 360).
    public static func qiblaBearing(latitude: Double, longitude: Double) -> Double {
        let lat1 = latitude * .pi / 180
        let lat2 = kaabaLatitude * .pi / 180
        let deltaLon = (kaabaLongitude - longitude) * .pi / 180

        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        return normalized(atan2(y, x) * 180 / .pi)
    }

    /// Great-circle (haversine) distance from the given point to the
    /// Kaaba, in kilometers.
    public static func kaabaDistanceKm(latitude: Double, longitude: Double) -> Double {
        let lat1 = latitude * .pi / 180
        let lat2 = kaabaLatitude * .pi / 180
        let deltaLat = (kaabaLatitude - latitude) * .pi / 180
        let deltaLon = (kaabaLongitude - longitude) * .pi / 180

        let h = sin(deltaLat / 2) * sin(deltaLat / 2)
            + cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2)
        return 2 * earthRadiusKm * atan2(sqrt(h), sqrt(1 - h))
    }

    /// Shortest signed rotation from one bearing to another, in degrees,
    /// in (-180, 180]. Positive means the target lies clockwise (to the
    /// user's right); the 360/0 seam is crossed the short way.
    public static func signedDelta(from: Double, to: Double) -> Double {
        var delta = (to - from).truncatingRemainder(dividingBy: 360)
        if delta > 180 { delta -= 360 }
        if delta <= -180 { delta += 360 }
        return delta
    }

    /// Normalizes any angle in degrees into [0, 360).
    public static func normalized(_ degrees: Double) -> Double {
        let wrapped = degrees.truncatingRemainder(dividingBy: 360)
        return wrapped < 0 ? wrapped + 360 : wrapped
    }
}
