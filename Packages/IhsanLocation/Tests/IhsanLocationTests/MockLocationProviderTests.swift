import Foundation
import Testing
import IhsanPrayerTimes
@testable import IhsanLocation

actor MockLocationProvider: LocationProviding {
    nonisolated let scriptedPlace: LocatedPlace
    nonisolated let scriptedAuth: LocationAuthorization

    init(
        place: LocatedPlace,
        authorization: LocationAuthorization = .authorizedWhenInUse
    ) {
        self.scriptedPlace = place
        self.scriptedAuth = authorization
    }

    nonisolated func currentAuthorization() async -> LocationAuthorization {
        scriptedAuth
    }

    nonisolated func requestWhenInUseAuthorization() async throws -> LocationAuthorization {
        scriptedAuth
    }

    nonisolated func requestAlwaysAuthorization() async throws -> LocationAuthorization {
        scriptedAuth
    }

    nonisolated func authorizationUpdates() -> AsyncStream<LocationAuthorization> {
        AsyncStream { continuation in
            continuation.yield(scriptedAuth)
            continuation.finish()
        }
    }

    nonisolated func currentPlace(timeout: TimeInterval, staleAfter: TimeInterval) async throws -> LocatedPlace {
        scriptedPlace
    }

    nonisolated func significantLocationChanges() -> AsyncStream<LocatedPlace> {
        AsyncStream { continuation in
            continuation.yield(scriptedPlace)
            continuation.finish()
        }
    }

    nonisolated func startMonitoringSignificantChanges() async throws {}

    nonisolated func stopMonitoringSignificantChanges() async {}

    nonisolated func isHeadingAvailable() -> Bool { true }

    nonisolated func headingUpdates() async throws -> AsyncStream<HeadingSample> {
        AsyncStream { continuation in
            continuation.yield(HeadingSample(
                trueHeading: 0,
                magneticHeading: 0,
                accuracy: 5,
                timestamp: .now
            ))
            continuation.finish()
        }
    }
}

@Test
func mockProviderReturnsScriptedPlace() async throws {
    let mockPlace = LocatedPlace(
        coordinates: .init(latitude: 41.8781, longitude: -87.6298),
        timeZone: TimeZone(identifier: "America/Chicago")!,
        cityName: "Chicago",
        countryCode: "US",
        timestamp: .now
    )
    let mock = MockLocationProvider(place: mockPlace)

    let result = try await mock.currentPlace()

    #expect(result.cityName == "Chicago")
    #expect(result.coordinates.latitude == 41.8781)
}
