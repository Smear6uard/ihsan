import Foundation
import MapKit

/// Value type wrapping the relevant fields of an `MKMapItem`.
///
/// MapKit details are encapsulated here; the surface used by the
/// view model and components leaks no MapKit types. Only the four facts
/// the row needs plus its destination coordinate survive the search;
/// the full `MKMapItem` and its unused business metadata do not cross
/// the actor boundary.
///
/// Marked `nonisolated` so the search actor can construct and return
/// values without crossing the project's default MainActor isolation.
nonisolated struct MasjidResult: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let street: String?
    let distanceMeters: CLLocationDistance
    private let latitude: Double
    private let longitude: Double

    init?(from mapItem: MKMapItem, userLocation: CLLocation) {
        let location = mapItem.location
        let coord = location.coordinate
        guard let mapName = mapItem.name?.trimmingCharacters(in: .whitespacesAndNewlines),
              !mapName.isEmpty else { return nil }
        self.name = mapName
        self.street = mapItem.address?.shortAddress
        self.distanceMeters = userLocation.distance(from: location)
        self.latitude = coord.latitude
        self.longitude = coord.longitude

        // Composite id for dedup: name + rounded coordinates.
        // 4 decimals ≈ 11m precision — collapses near-duplicates that
        // separate queries return at slightly different coordinates,
        // while keeping genuinely distinct masjids separate.
        let lat = (coord.latitude * 10_000).rounded() / 10_000
        let lon = (coord.longitude * 10_000).rounded() / 10_000
        let normalizedName = mapName.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        ).lowercased()
        self.id = "\(normalizedName)-\(lat)-\(lon)"
    }

    /// The venue's coordinate, for the one place it is ever written down:
    /// the deliberate act of setting this masjid as the user's own. Nothing
    /// on the search path itself persists it.
    var coordinate: (latitude: Double, longitude: Double) {
        (latitude, longitude)
    }

    /// Open Apple Maps with this masjid as the destination, the user's
    /// current location as origin. Maps honors the person's preferred
    /// route mode rather than this app choosing one for them.
    @MainActor
    func openInMaps() {
        let destination = MKMapItem(
            location: CLLocation(latitude: latitude, longitude: longitude),
            address: nil
        )
        destination.name = name
        destination.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDefault
        ])
    }

    static func == (lhs: MasjidResult, rhs: MasjidResult) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
