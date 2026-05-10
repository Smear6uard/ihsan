import Foundation

public protocol LocationProviding: Sendable {
    /// Current authorization status. Updates may be observed via
    /// `authorizationUpdates()`.
    func currentAuthorization() async -> LocationAuthorization

    /// Request when-in-use authorization. Returns the resulting status.
    /// Throws `LocationError.permissionRestricted` if restricted.
    @discardableResult
    func requestWhenInUseAuthorization() async throws -> LocationAuthorization

    /// Request always authorization. Only use this after the user
    /// explicitly enables auto-location updates in Settings.
    /// Throws `LocationError.permissionRestricted` if restricted.
    @discardableResult
    func requestAlwaysAuthorization() async throws -> LocationAuthorization

    /// Stream of authorization status changes.
    func authorizationUpdates() -> AsyncStream<LocationAuthorization>

    /// One-shot current location lookup. Used for prayer time
    /// calculation, qibla compass, masjid search.
    ///
    /// - Returns a `LocatedPlace` with coordinates, time zone, and
    ///   reverse-geocoded city name + country code.
    /// - Caches the most recent result for `staleAfter` seconds; if a
    ///   fresh result is unavailable within `timeout` seconds, throws
    ///   `LocationError.timedOut`.
    /// - Throws `LocationError.permissionDenied` if not authorized.
    func currentPlace(
        timeout: TimeInterval,
        staleAfter: TimeInterval
    ) async throws -> LocatedPlace

    /// Stream of significant location changes (movement of ~500m+).
    /// Useful for auto-location updates when the user travels.
    /// Each emitted `LocatedPlace` is a fully-resolved location
    /// (coordinates + reverse-geocoded city name).
    ///
    /// The stream remains active for the lifetime of the app process
    /// (or until `stopMonitoringSignificantChanges()` is called).
    func significantLocationChanges() -> AsyncStream<LocatedPlace>

    /// Begin monitoring significant location changes. Required before
    /// `significantLocationChanges()` will emit values.
    func startMonitoringSignificantChanges() async throws

    /// Stop monitoring significant location changes.
    func stopMonitoringSignificantChanges() async

    /// Stream of compass heading samples. Each sample carries true heading,
    /// magnetic heading, accuracy, and timestamp.
    ///
    /// - Throws `LocationError.headingUnavailable` if the device has no
    ///   compass (iPad, simulator).
    /// - The stream pauses automatically when the consumer cancels iteration.
    /// - For direction-critical features, check `sample.isAccuracyAcceptable`
    ///   before trusting the value.
    func headingUpdates() async throws -> AsyncStream<HeadingSample>
}

public extension LocationProviding {
    /// 10s timeout, 5min stale window.
    func currentPlace() async throws -> LocatedPlace {
        try await currentPlace(timeout: 10, staleAfter: 300)
    }
}
