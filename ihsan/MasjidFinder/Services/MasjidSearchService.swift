import Foundation
import MapKit
import IhsanPrayerTimes

protocol MasjidSearching: Sendable {
    func search(near coordinates: Coordinates) async throws -> [MasjidResult]
}

/// Wraps `MKLocalSearch` to find masjids near a coordinate.
///
/// Runs three parallel queries ("mosque", "masjid", "islamic center"),
/// merges and deduplicates the results by normalized name + coordinate,
/// sorts by distance, and caps the sheet at fifteen useful choices.
///
/// Privacy: the user's coordinates are passed in, used to scope the
/// MapKit queries, and discarded with this actor's stack. Nothing is
/// retained, persisted, or logged.
actor MasjidSearchService: MasjidSearching {
    nonisolated static let radiusMeters: CLLocationDistance = 25_000
    nonisolated static let resultLimit = 15

    func search(near coordinates: Coordinates) async throws -> [MasjidResult] {
        let queries = ["mosque", "masjid", "islamic center"]

        let allResults: [[MasjidResult]] = try await withThrowingTaskGroup(
            of: [MasjidResult].self,
            returning: [[MasjidResult]].self
        ) { group in
            for query in queries {
                group.addTask {
                    try await Self.runSearch(query: query, near: coordinates)
                }
            }
            var results: [[MasjidResult]] = []
            for try await batch in group {
                results.append(batch)
            }
            return results
        }

        return Self.finalized(allResults.flatMap { $0 })
    }

    /// Pure finalization kept separate from MapKit I/O so the privacy-
    /// preserving search contract (dedupe, order, cap) is pinned by tests.
    nonisolated static func finalized(_ results: [MasjidResult]) -> [MasjidResult] {
        var seen = Set<String>()
        let unique = results.filter { seen.insert($0.id).inserted }
        return Array(
            unique.sorted { $0.distanceMeters < $1.distanceMeters }
                .prefix(resultLimit)
        )
    }

    private static func runSearch(
        query: String,
        near coordinates: Coordinates
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
            latitudinalMeters: Self.radiusMeters * 2,
            longitudinalMeters: Self.radiusMeters * 2
        )
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = region
        request.resultTypes = .pointOfInterest
        let search = MKLocalSearch(request: request)
        let response = try await search.start()
        return response.mapItems.compactMap { item in
            guard let result = MasjidResult(from: item, userLocation: userLocation),
                  result.distanceMeters <= Self.radiusMeters
            else { return nil }
            return result
        }
    }
}
