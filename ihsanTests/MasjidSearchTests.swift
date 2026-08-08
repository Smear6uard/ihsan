import CoreLocation
import MapKit
import Testing
@testable import ihsan

@Suite("Nearby masjid search policy")
struct MasjidSearchTests {
    private let origin = CLLocation(latitude: 41.8781, longitude: -87.6298)

    @Test("same normalized name and coordinate is one result")
    func deduplicatesNameAndCoordinate() throws {
        let first = try result(name: "Masjid Al-Noor", latitudeOffset: 0.001)
        let duplicate = try result(name: "MASJID AL-NOOR", latitudeOffset: 0.001)

        let finalized = MasjidSearchService.finalized([first, duplicate])

        #expect(finalized.count == 1)
    }

    @Test("results are nearest first and capped")
    func sortsAndCapsResults() throws {
        let candidates = try (1...20).reversed().map { index in
            try result(
                name: "Masjid \(index)",
                latitudeOffset: Double(index) * 0.001
            )
        }

        let finalized = MasjidSearchService.finalized(candidates)

        #expect(finalized.count == MasjidSearchService.resultLimit)
        #expect(finalized.map(\.distanceMeters) == finalized.map(\.distanceMeters).sorted())
    }

    private func result(
        name: String,
        latitudeOffset: Double
    ) throws -> MasjidResult {
        let location = CLLocation(
            latitude: origin.coordinate.latitude + latitudeOffset,
            longitude: origin.coordinate.longitude
        )
        let address = try #require(
            MKAddress(fullAddress: "100 Crescent Street, Chicago, IL", shortAddress: "100 Crescent Street")
        )
        let item = MKMapItem(location: location, address: address)
        item.name = name
        return try #require(MasjidResult(from: item, userLocation: origin))
    }
}
