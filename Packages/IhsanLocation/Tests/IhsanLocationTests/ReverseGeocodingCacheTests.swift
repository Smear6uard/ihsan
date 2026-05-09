import Foundation
import Testing
@testable import IhsanLocation

@Test
func storingAndRetrievingSameLocationReturnsCachedValue() {
    let cache = ReverseGeocodingCache()
    let key = ReverseGeocodingCache.Key(latitude: 41.8781, longitude: -87.6298)

    cache.store((city: "Chicago", country: "US"), for: key)

    let result = cache.value(for: key)
    #expect(result?.city == "Chicago")
    #expect(result?.country == "US")
}

@Test
func nearbyLocationsCollapseToSameCacheKey() {
    let first = ReverseGeocodingCache.Key(latitude: 41.878100, longitude: -87.629800)
    let second = ReverseGeocodingCache.Key(latitude: 41.878149, longitude: -87.629849)

    #expect(first == second)
}

@Test
func distantLocationsUseDifferentCacheKeys() {
    let first = ReverseGeocodingCache.Key(latitude: 41.8781, longitude: -87.6298)
    let second = ReverseGeocodingCache.Key(latitude: 41.8810, longitude: -87.6298)

    #expect(first != second)
}

@Test
func entriesOlderThanMaxAgeAreEvictedOnLookup() {
    let now = Date(timeIntervalSinceReferenceDate: 800_000)
    let cache = ReverseGeocodingCache(now: { now })
    let key = ReverseGeocodingCache.Key(latitude: 41.8781, longitude: -87.6298)

    cache.store(
        (city: "Chicago", country: "US"),
        for: key,
        timestamp: now.addingTimeInterval(-86_401)
    )

    #expect(cache.value(for: key) == nil)
}

@Test
func cacheEvictsOldestEntryWhenCapacityExceeded() {
    let now = Date(timeIntervalSinceReferenceDate: 900_000)
    let cache = ReverseGeocodingCache(maxEntries: 2, now: { now })
    let oldest = ReverseGeocodingCache.Key(latitude: 41.8781, longitude: -87.6298)
    let middle = ReverseGeocodingCache.Key(latitude: 51.5074, longitude: -0.1278)
    let newest = ReverseGeocodingCache.Key(latitude: 40.7128, longitude: -74.0060)

    cache.store((city: "Chicago", country: "US"), for: oldest, timestamp: now.addingTimeInterval(-30))
    cache.store((city: "London", country: "GB"), for: middle, timestamp: now.addingTimeInterval(-20))
    cache.store((city: "New York", country: "US"), for: newest, timestamp: now.addingTimeInterval(-10))

    #expect(cache.value(for: oldest) == nil)
    #expect(cache.value(for: middle)?.city == "London")
    #expect(cache.value(for: newest)?.city == "New York")
}
