import Foundation
import IhsanPrayerTimes

public struct LocatedPlace: Sendable, Hashable {
    /// Coordinates. Used for prayer time calculation and qibla bearing.
    /// MUST NOT be persisted to SwiftData, UserDefaults, or any storage.
    public let coordinates: Coordinates

    /// IANA time zone identifier resolved at this location.
    /// Used for prayer time calculation. Not persisted.
    public let timeZone: TimeZone

    /// City or locality name for display. Safe to persist.
    /// May be nil if reverse geocoding is unavailable.
    public let cityName: String?

    /// ISO 3166-1 alpha-2 country code. Safe to persist.
    /// Used for calculation method auto-detection (US/Canada -> ISNA, etc.).
    public let countryCode: String?

    /// When this location was resolved. Used to detect staleness.
    public let timestamp: Date

    public init(
        coordinates: Coordinates,
        timeZone: TimeZone,
        cityName: String?,
        countryCode: String?,
        timestamp: Date
    ) {
        self.coordinates = coordinates
        self.timeZone = timeZone
        self.cityName = cityName
        self.countryCode = countryCode
        self.timestamp = timestamp
    }
}
