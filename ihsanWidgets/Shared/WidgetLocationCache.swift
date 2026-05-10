import Foundation
import IhsanCore
import IhsanPrayerTimes

/// Read-only window into the most recent location resolved by the main app.
///
/// The widget extension cannot import `CoreLocation` (it has no
/// authorization to query location), so the main app is responsible for
/// writing the most recent coordinates to the shared App Group
/// `UserDefaults` whenever it resolves a location. The widget reads them
/// here.
///
/// When no location has been written yet — first install before the app
/// has launched, or location permission was denied — `current` returns
/// `nil` and the widget falls back to a "Open Ihsan to set location"
/// placeholder state. We deliberately do NOT fall back to Mecca or
/// arbitrary defaults: showing wrong prayer times would be worse than
/// showing none.
enum WidgetLocationCache {
    /// App Group `UserDefaults` keys. The main app writes; the widget reads.
    /// Documented here so any future writer can find the contract.
    enum Key {
        static let latitude = "ihsan.widget.location.latitude"
        static let longitude = "ihsan.widget.location.longitude"
        static let cityName = "ihsan.widget.location.cityName"
        static let resolvedAt = "ihsan.widget.location.resolvedAt"
    }

    /// Reads the cached snapshot. Returns `nil` if no coordinates have
    /// been written by the main app yet.
    static func current() -> Snapshot? {
        guard let defaults = UserDefaults(
            suiteName: IhsanModelContainerFactory.appGroupIdentifier
        ) else {
            return nil
        }
        guard
            let lat = defaults.object(forKey: Key.latitude) as? Double,
            let lon = defaults.object(forKey: Key.longitude) as? Double,
            lat.isFinite,
            lon.isFinite,
            (-90.0...90.0).contains(lat),
            (-180.0...180.0).contains(lon)
        else {
            return nil
        }
        let city = defaults.string(forKey: Key.cityName)
        let resolvedAt = (defaults.object(forKey: Key.resolvedAt) as? Double)
            .map(Date.init(timeIntervalSince1970:))
        return Snapshot(
            coordinates: Coordinates(latitude: lat, longitude: lon),
            cityName: city,
            resolvedAt: resolvedAt
        )
    }

    struct Snapshot: Sendable, Equatable {
        let coordinates: Coordinates
        let cityName: String?
        let resolvedAt: Date?

        var displayCity: String {
            cityName ?? "Current Location"
        }
    }
}
