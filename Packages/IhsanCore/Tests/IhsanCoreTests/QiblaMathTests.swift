import Foundation
import Testing
@testable import IhsanCore

@Suite("QiblaMath")
struct QiblaMathTests {

    // MARK: - Great-circle bearing to the Kaaba

    /// Published qibla bearings (degrees from true north) for six cities,
    /// from the Adhan library's own test suite — an independent,
    /// widely-deployed reference. Tolerance per the acceptance bar: ±0.5°.
    @Test(
        "qibla bearing matches published values for known cities",
        arguments: [
            ("Washington DC", 38.9072, -77.0369, 56.560),
            ("New York", 40.7128, -74.0059, 58.481),
            ("London", 51.5074, -0.1278, 118.987),
            ("Sydney", -33.8688, 151.2093, 277.499),
            ("Tokyo", 35.6895, 139.6917, 293.021),
            ("Anchorage", 61.2181, -149.9003, 350.883),
        ]
    )
    func bearingMatchesPublished(
        city: String, latitude: Double, longitude: Double, published: Double
    ) {
        let bearing = QiblaMath.qiblaBearing(latitude: latitude, longitude: longitude)
        #expect(
            abs(bearing - published) < 0.5,
            "\(city): computed \(bearing)°, published \(published)°"
        )
    }

    // MARK: - Great-circle distance to the Kaaba

    /// Haversine distances (R = 6371 km) computed independently.
    /// NYC→Makkah cross-checks against the commonly published ~10,306 km.
    @Test(
        "distance to the Kaaba matches independent haversine computation",
        arguments: [
            ("New York", 40.7128, -74.0059, 10306.3),
            ("London", 51.5074, -0.1278, 4793.8),
            ("Sydney", -33.8688, 151.2093, 13236.3),
        ]
    )
    func distanceMatchesReference(
        city: String, latitude: Double, longitude: Double, expectedKm: Double
    ) {
        let km = QiblaMath.kaabaDistanceKm(latitude: latitude, longitude: longitude)
        #expect(abs(km - expectedKm) < 5, "\(city): computed \(km) km, expected \(expectedKm) km")
    }

    @Test("distance from the Kaaba itself is zero")
    func distanceAtKaabaIsZero() {
        let km = QiblaMath.kaabaDistanceKm(
            latitude: QiblaMath.kaabaLatitude,
            longitude: QiblaMath.kaabaLongitude
        )
        #expect(km < 0.001)
    }

    // MARK: - Signed shortest delta

    @Test("signed delta turns clockwise for a target to the right")
    func signedDeltaClockwise() {
        #expect(QiblaMath.signedDelta(from: 0, to: 48) == 48)
        #expect(QiblaMath.signedDelta(from: 30, to: 90) == 60)
    }

    @Test("signed delta turns counterclockwise for a target to the left")
    func signedDeltaCounterclockwise() {
        #expect(QiblaMath.signedDelta(from: 90, to: 30) == -60)
    }

    @Test("signed delta crosses the 360/0 seam the short way")
    func signedDeltaWraparound() {
        #expect(QiblaMath.signedDelta(from: 350, to: 10) == 20)
        #expect(QiblaMath.signedDelta(from: 10, to: 350) == -20)
        #expect(QiblaMath.signedDelta(from: 359, to: 1) == 2)
        #expect(QiblaMath.signedDelta(from: 1, to: 359) == -2)
    }

    @Test("signed delta of the exact opposite direction is +180")
    func signedDeltaAntipode() {
        #expect(QiblaMath.signedDelta(from: 0, to: 180) == 180)
        #expect(QiblaMath.signedDelta(from: 0, to: 181) == -179)
    }

    @Test("signed delta of identical bearings is zero")
    func signedDeltaZero() {
        #expect(QiblaMath.signedDelta(from: 123.4, to: 123.4) == 0)
    }

    // MARK: - Normalization

    @Test("bearings normalize into [0, 360)")
    func normalization() {
        #expect(QiblaMath.normalized(361) == 1)
        #expect(QiblaMath.normalized(-1) == 359)
        #expect(QiblaMath.normalized(720) == 0)
        #expect(QiblaMath.normalized(360) == 0)
        #expect(QiblaMath.normalized(45.5) == 45.5)
    }
}
