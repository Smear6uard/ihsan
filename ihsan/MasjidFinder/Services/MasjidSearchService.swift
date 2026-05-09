import Foundation
import MapKit
import IhsanPrayerTimes

/// Wraps `MKLocalSearch` to find masjids near a coordinate.
///
/// Runs three parallel queries ("mosque", "masjid", "islamic center"),
/// merges and deduplicates the results by composite id, applies the
/// circular radius filter (MKLocalSearch's region is a bounding box,
/// not a circle), and sorts by distance.
///
/// Privacy: the user's coordinates are passed in, used to scope the
/// MapKit queries, and discarded with this actor's stack. Nothing is
/// retained, persisted, or logged.
actor MasjidSearchService {
    func search(
        near coordinates: Coordinates,
        radiusKm: Double
    ) async throws -> [MasjidResult] {
        let userLocation = CLLocation(
            latitude: coordinates.latitude,
            longitude: coordinates.longitude
        )
        // Region is a bounding box. Doubling the radius gives MapKit
        // enough headroom that masjids at the radius edge aren't
        // clipped before our circular filter runs.
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: coordinates.latitude,
                longitude: coordinates.longitude
            ),
            latitudinalMeters: radiusKm * 1_000 * 2,
            longitudinalMeters: radiusKm * 1_000 * 2
        )

        let queries = ["mosque", "masjid", "islamic center"]

        let allResults: [[MKMapItem]] = try await withThrowingTaskGroup(
            of: [MKMapItem].self,
            returning: [[MKMapItem]].self
        ) { group in
            for query in queries {
                group.addTask {
                    try await Self.runSearch(query: query, region: region)
                }
            }
            var results: [[MKMapItem]] = []
            for try await batch in group {
                results.append(batch)
            }
            return results
        }

        var seen = Set<String>()
        var unique: [MasjidResult] = []
        for item in allResults.flatMap({ $0 }) {
            let result = MasjidResult(from: item, userLocation: userLocation)
            guard result.distanceKm <= radiusKm else { continue }
            guard !seen.contains(result.id) else { continue }
            seen.insert(result.id)
            unique.append(result)
        }

        return unique.sorted { $0.distanceKm < $1.distanceKm }
    }

    private static func runSearch(
        query: String,
        region: MKCoordinateRegion
    ) async throws -> [MKMapItem] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = region
        request.resultTypes = .pointOfInterest
        let search = MKLocalSearch(request: request)
        let response = try await search.start()
        return response.mapItems
    }
}
