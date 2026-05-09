# IhsanLocation

IhsanLocation is the CoreLocation wrapper for Ihsan. App features depend on the `LocationProviding` protocol instead of importing CoreLocation directly, which keeps platform authorization, location lookup, heading updates, significant-change monitoring, reverse geocoding, and test seams in one package.

## Privacy Invariant

Coordinates are transient. `LocatedPlace.coordinates` exists only in memory for prayer-time calculation, qibla bearing, masjid search, and similar immediate work. IhsanLocation never writes coordinates to SwiftData, UserDefaults, files, or any other storage.

Only `cityName` and `countryCode` are safe to persist in app settings. Reverse geocoding is cached in memory only, keyed by rounded coordinates, with roughly 100m precision, a 24-hour TTL, and a 100-entry cap to stay well under CLGeocoder rate limits.

`CoreLocationCoordinator.swift` is the only file in this package that imports CoreLocation. The public API exposes only Foundation types, AsyncStream, and Ihsan domain types.

## Testing With Mocks

Consumers should accept `LocationProviding`:

```swift
struct PrayerLocationConsumer {
    let locationProvider: LocationProviding

    func refresh() async throws -> LocatedPlace {
        try await locationProvider.currentPlace()
    }
}
```

Tests can use an actor or value-backed mock that returns scripted `LocatedPlace`, authorization, significant-location, and heading values. No test needs CoreLocation.

## App Configuration

Add these Info.plist keys to the consuming app target:

- `NSLocationWhenInUseUsageDescription`: `Ihsan uses your location to calculate accurate prayer times. Your coordinates are never stored or shared - only your city name is saved for display.`
- `NSLocationAlwaysAndWhenInUseUsageDescription`: `Ihsan uses your location to automatically update prayer times when you travel. Coordinates are never stored or shared.`

Enable the Location Updates background mode for significant-change monitoring while the app is running.

v1 uses when-in-use authorization. Always authorization for background wake from a terminated state is deferred to v1.1.
