import Foundation
import MapKit
import IhsanPrayerTimes

/// Value type wrapping the relevant fields of an `MKMapItem`.
///
/// MapKit details are encapsulated here; the public surface used by the
/// view model and components leaks no MapKit types. The retained
/// `mapItem` reference is what carries Apple's enriched data through to
/// Apple Maps when the user taps a row — we never reconstruct one
/// ourselves, so we don't lose the metadata Apple's index already
/// resolved (operating hours, exact placement, business identity).
///
/// The struct stores a class reference but is treated as immutable from
/// construction onward, hence `@unchecked Sendable`. `MKMapItem` itself
/// is not Sendable in the iOS 26 SDK, but no consumer in this codebase
/// mutates it.
///
/// Marked `nonisolated` so the search actor can construct and return
/// values without crossing the project's default MainActor isolation.
nonisolated struct MasjidResult: Identifiable, Hashable, @unchecked Sendable {
    let id: String
    let name: String
    let address: String?
    let phoneNumber: String?
    let coordinate: Coordinates
    let distanceKm: Double

    private let mapItem: MKMapItem

    init(from mapItem: MKMapItem, userLocation: CLLocation) {
        self.mapItem = mapItem
        let location = mapItem.location
        let coord = location.coordinate
        self.name = mapItem.name ?? "Unknown"
        // `addressRepresentations.fullAddress` is the iOS 26 replacement
        // for the deprecated `MKPlacemark` formatting. Single-line with
        // region keeps the row compact and readable across locales.
        self.address = mapItem.addressRepresentations?.fullAddress(
            includingRegion: true,
            singleLine: true
        )
        self.phoneNumber = mapItem.phoneNumber
        self.coordinate = Coordinates(
            latitude: coord.latitude,
            longitude: coord.longitude
        )
        self.distanceKm = userLocation.distance(from: location) / 1_000.0

        // Composite id for dedup: name + rounded coordinates.
        // 4 decimals ≈ 11m precision — collapses near-duplicates that
        // separate queries return at slightly different coordinates,
        // while keeping genuinely distinct masjids separate.
        let lat = (coord.latitude * 10_000).rounded() / 10_000
        let lon = (coord.longitude * 10_000).rounded() / 10_000
        self.id = "\(self.name)-\(lat)-\(lon)"
    }

    /// Open Apple Maps with this masjid as the destination, the user's
    /// current location as origin, driving directions by default.
    func openInMaps() {
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    /// Universal-link URL pointing at this masjid's coordinates on Apple
    /// Maps. Used for the Share Location flow — produces a URL that
    /// recipients can open directly in Maps.
    var shareURL: URL? {
        let nameQuery = name.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed
        ) ?? ""
        let lat = coordinate.latitude
        let lon = coordinate.longitude
        return URL(string: "https://maps.apple.com/?ll=\(lat),\(lon)&q=\(nameQuery)")
    }

    static func == (lhs: MasjidResult, rhs: MasjidResult) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
