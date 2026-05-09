import Testing
import IhsanPrayerTimes
@testable import IhsanLocation

@Test
func bearingFromMakkahToItself() {
    let bearing = QiblaCalculator.bearingToKaaba(from: QiblaCalculator.kaabaCoordinates)
    #expect(bearing >= 0 && bearing < 360)
}

@Test
func bearingFromChicagoIsNortheast() {
    let chicago = Coordinates(latitude: 41.8781, longitude: -87.6298)
    let bearing = chicago.qiblaBearing
    #expect(bearing >= 45 && bearing <= 60, "Chicago qibla should point northeast, got \(bearing) degrees")
}

@Test
func bearingFromLondonIsSouthEast() {
    let london = Coordinates(latitude: 51.5074, longitude: -0.1278)
    let bearing = london.qiblaBearing
    #expect(bearing >= 115 && bearing <= 122, "London qibla should point southeast, got \(bearing) degrees")
}

@Test
func bearingFromJakartaIsWest() {
    let jakarta = Coordinates(latitude: -6.2088, longitude: 106.8456)
    let bearing = jakarta.qiblaBearing
    #expect(bearing >= 290 && bearing <= 300, "Jakarta qibla should point west-northwest, got \(bearing) degrees")
}

@Test
func bearingFromNewYorkIsNortheast() {
    let ny = Coordinates(latitude: 40.7128, longitude: -74.0060)
    let bearing = ny.qiblaBearing
    #expect(bearing >= 53 && bearing <= 63, "NYC qibla should point northeast, got \(bearing) degrees")
}

@Test
func bearingFromSydneyIsWestNorthwest() {
    let sydney = Coordinates(latitude: -33.8688, longitude: 151.2093)
    let bearing = sydney.qiblaBearing
    #expect(bearing >= 273 && bearing <= 282, "Sydney qibla should point WNW, got \(bearing) degrees")
}

@Test
func distanceFromChicagoToMakkahReasonable() {
    let chicago = Coordinates(latitude: 41.8781, longitude: -87.6298)
    let distance = chicago.distanceToKaaba
    #expect(distance > 11_000 && distance < 11_700, "Distance \(distance) km is outside expected range")
}
