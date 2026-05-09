import Foundation
@preconcurrency import CoreLocation
import MapKit
import IhsanPrayerTimes

public final class CoreLocationCoordinator: NSObject, LocationProviding, @unchecked Sendable {
    public static let shared = CoreLocationCoordinator()

    private let manager: CLLocationManager
    private let cache: ReverseGeocodingCache

    private var pendingLocationContinuations: [UUID: CheckedContinuation<CLLocation, Error>] = [:]
    private var pendingAuthContinuations: [CheckedContinuation<LocationAuthorization, Error>] = []

    private var significantChangeContinuations: [UUID: AsyncStream<LocatedPlace>.Continuation] = [:]
    private var headingContinuations: [UUID: AsyncStream<Double>.Continuation] = [:]
    private var authorizationContinuations: [UUID: AsyncStream<LocationAuthorization>.Continuation] = [:]

    private var cachedPlace: LocatedPlace?
    private let lock = NSLock()

    public override init() {
        self.manager = CLLocationManager()
        self.cache = ReverseGeocodingCache()
        super.init()
        self.manager.delegate = self
        self.manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        self.manager.distanceFilter = 100
    }

    public func currentAuthorization() async -> LocationAuthorization {
        Self.translate(manager.authorizationStatus)
    }

    @discardableResult
    public func requestWhenInUseAuthorization() async throws -> LocationAuthorization {
        let current = manager.authorizationStatus
        if current == .restricted {
            throw LocationError.permissionRestricted
        }
        if current != .notDetermined {
            return Self.translate(current)
        }

        return try await withCheckedThrowingContinuation { continuation in
            lock.withLock {
                pendingAuthContinuations.append(continuation)
            }
            manager.requestWhenInUseAuthorization()
        }
    }

    @discardableResult
    public func requestAlwaysAuthorization() async throws -> LocationAuthorization {
        let current = manager.authorizationStatus
        if current == .restricted {
            throw LocationError.permissionRestricted
        }
        if current == .denied {
            return .denied
        }
        if current == .authorizedAlways {
            return .authorizedAlways
        }

        return try await withCheckedThrowingContinuation { continuation in
            lock.withLock {
                pendingAuthContinuations.append(continuation)
            }
            manager.requestAlwaysAuthorization()
        }
    }

    public func authorizationUpdates() -> AsyncStream<LocationAuthorization> {
        AsyncStream { continuation in
            let id = UUID()
            lock.withLock {
                authorizationContinuations[id] = continuation
            }
            continuation.yield(Self.translate(manager.authorizationStatus))
            continuation.onTermination = { [weak self] _ in
                self?.lock.withLock {
                    self?.authorizationContinuations[id] = nil
                }
            }
        }
    }

    public func currentPlace(
        timeout: TimeInterval,
        staleAfter: TimeInterval
    ) async throws -> LocatedPlace {
        if let cached = lock.withLock({ cachedPlace }),
           Date.now.timeIntervalSince(cached.timestamp) < staleAfter {
            return cached
        }

        let auth = await currentAuthorization()
        guard auth.isAuthorized else {
            switch auth {
            case .restricted:
                throw LocationError.permissionRestricted
            case .notDetermined:
                throw LocationError.permissionNotDetermined
            default:
                throw LocationError.permissionDenied
            }
        }

        let location = try await requestLocation(timeout: timeout)
        let place = await makeLocatedPlace(from: location)
        lock.withLock {
            cachedPlace = place
        }
        return place
    }

    public func significantLocationChanges() -> AsyncStream<LocatedPlace> {
        AsyncStream { continuation in
            let id = UUID()
            lock.withLock {
                significantChangeContinuations[id] = continuation
            }
            continuation.onTermination = { [weak self] _ in
                self?.lock.withLock {
                    self?.significantChangeContinuations[id] = nil
                }
            }
        }
    }

    public func startMonitoringSignificantChanges() async throws {
        guard CLLocationManager.significantLocationChangeMonitoringAvailable() else {
            throw LocationError.locationUnavailable
        }

        let auth = await currentAuthorization()
        guard auth.isAuthorized else {
            switch auth {
            case .restricted:
                throw LocationError.permissionRestricted
            case .notDetermined:
                throw LocationError.permissionNotDetermined
            default:
                throw LocationError.permissionDenied
            }
        }

        manager.startMonitoringSignificantLocationChanges()
    }

    public func stopMonitoringSignificantChanges() async {
        manager.stopMonitoringSignificantLocationChanges()
    }

    public func headingUpdates() async throws -> AsyncStream<Double> {
        guard CLLocationManager.headingAvailable() else {
            throw LocationError.headingUnavailable
        }

        return AsyncStream { continuation in
            let id = UUID()
            lock.withLock {
                headingContinuations[id] = continuation
            }
            manager.startUpdatingHeading()
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                self.lock.withLock {
                    self.headingContinuations[id] = nil
                    if self.headingContinuations.isEmpty {
                        self.manager.stopUpdatingHeading()
                    }
                }
            }
        }
    }

    private func requestLocation(timeout: TimeInterval) async throws -> CLLocation {
        let requestID = UUID()
        let timeoutNanoseconds = UInt64(max(timeout, 0) * 1_000_000_000)

        return try await withCheckedThrowingContinuation { continuation in
            lock.withLock {
                pendingLocationContinuations[requestID] = continuation
            }

            Task { [weak self] in
                if timeoutNanoseconds > 0 {
                    try? await Task.sleep(nanoseconds: timeoutNanoseconds)
                }
                guard let self else { return }
                let timedOut: CheckedContinuation<CLLocation, Error>? = self.lock.withLock {
                    self.pendingLocationContinuations.removeValue(forKey: requestID)
                }
                timedOut?.resume(throwing: LocationError.timedOut)
            }

            manager.requestLocation()
        }
    }

    private func makeLocatedPlace(from location: CLLocation) async -> LocatedPlace {
        let coords = Coordinates(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        let metadata = await resolveMetadata(for: location)

        return LocatedPlace(
            coordinates: coords,
            timeZone: metadata.timeZone,
            cityName: metadata.cityName,
            countryCode: metadata.countryCode,
            timestamp: Date.now
        )
    }

    private func resolveMetadata(for location: CLLocation) async -> (
        timeZone: TimeZone,
        cityName: String?,
        countryCode: String?
    ) {
        let key = ReverseGeocodingCache.Key(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        if let cached = cache.value(for: key) {
            let cachedTimeZone = lock.withLock { cachedPlace?.timeZone } ?? .current
            return (cachedTimeZone, cached.city, cached.country)
        }

        do {
            let request = MKReverseGeocodingRequest(location: location)
            guard let first = try await request?.mapItems.first else {
                return (.current, nil, nil)
            }

            let city = first.addressRepresentations?.cityName ?? first.name
            let country = first.addressRepresentations?.region?.identifier
            cache.store((city: city, country: country), for: key)
            return (first.timeZone ?? .current, city, country)
        } catch {
            return (.current, nil, nil)
        }
    }

    private static func translate(_ status: CLAuthorizationStatus) -> LocationAuthorization {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .authorizedWhenInUse:
            return .authorizedWhenInUse
        case .authorizedAlways:
            return .authorizedAlways
        @unknown default:
            return .notDetermined
        }
    }
}

extension CoreLocationCoordinator: CLLocationManagerDelegate {
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = Self.translate(manager.authorizationStatus)

        let pending: [CheckedContinuation<LocationAuthorization, Error>] = lock.withLock {
            let continuations = pendingAuthContinuations
            pendingAuthContinuations.removeAll()
            return continuations
        }
        for continuation in pending {
            if status == .restricted {
                continuation.resume(throwing: LocationError.permissionRestricted)
            } else {
                continuation.resume(returning: status)
            }
        }

        let streams = lock.withLock {
            Array(authorizationContinuations.values)
        }
        for stream in streams {
            stream.yield(status)
        }
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        let pending: [CheckedContinuation<CLLocation, Error>] = lock.withLock {
            let continuations = Array(pendingLocationContinuations.values)
            pendingLocationContinuations.removeAll()
            return continuations
        }
        for continuation in pending {
            continuation.resume(returning: location)
        }

        Task { [weak self] in
            guard let self else { return }
            let place = await self.makeLocatedPlace(from: location)
            self.lock.withLock {
                self.cachedPlace = place
            }
            let streams = self.lock.withLock {
                Array(self.significantChangeContinuations.values)
            }
            for stream in streams {
                stream.yield(place)
            }
        }
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let pending: [CheckedContinuation<CLLocation, Error>] = lock.withLock {
            let continuations = Array(pendingLocationContinuations.values)
            pendingLocationContinuations.removeAll()
            return continuations
        }
        for continuation in pending {
            continuation.resume(throwing: LocationError.locationUnavailable)
        }
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard newHeading.headingAccuracy >= 0 else { return }
        let heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading

        let streams = lock.withLock {
            Array(headingContinuations.values)
        }
        for stream in streams {
            stream.yield(heading)
        }
    }

    public func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        true
    }
}
