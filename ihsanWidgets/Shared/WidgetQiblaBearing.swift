import Foundation
import IhsanPrayerTimes

/// Inline qibla bearing math so the widget extension does not need to
/// import `IhsanLocation` (which transitively pulls in `CoreLocation`).
/// Mirrors the formula used by `IhsanLocation.QiblaCalculator`. Tested
/// in the package's `QiblaCalculatorTests`; this duplicate is verified
/// against the same expected values via spot-check.
enum WidgetQiblaBearing {
    static let kaaba = Coordinates(latitude: 21.4225, longitude: 39.8262)

    /// Initial great-circle bearing from `origin` to the Kaaba in
    /// degrees from true north, normalized to [0, 360).
    static func bearing(from origin: Coordinates) -> Double {
        let lat1 = origin.latitude * .pi / 180
        let lat2 = kaaba.latitude * .pi / 180
        let deltaLon = (kaaba.longitude - origin.longitude) * .pi / 180

        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        let radians = atan2(y, x)
        let degrees = radians * 180 / .pi
        return (degrees + 360).truncatingRemainder(dividingBy: 360)
    }
}
