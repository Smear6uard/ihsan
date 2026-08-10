import Foundation
import Observation
import IhsanCore
import IhsanPrayerTimes

/// Holds the last sky reading and decides when to ask for a new one.
///
/// Weather is an overlay privilege, never a dependency: every path out
/// of this model is allowed to produce nothing, and nothing here throws,
/// logs, or blocks the schedule work it rides beside. No reading —
/// offline, provider failure, no interested consumer — simply means the
/// idealized sky.
@MainActor
@Observable
final class SkyWeatherModel {
    private(set) var conditions: SkyConditions?

    private let provider: any SkyWeatherProviding
    private let locate: @Sendable () async throws -> Coordinates
    private var inFlight = false

    init(
        provider: any SkyWeatherProviding = WeatherKitSkyProvider(),
        locate: @escaping @Sendable () async throws -> Coordinates
    ) {
        self.provider = provider
        self.locate = locate
    }

    /// The reading if it is still fit to serve, else nil.
    func current(at now: Date) -> SkyConditions? {
        conditions?.usable(at: now)
    }

    /// Serves the cache, then refetches if the policy says to.
    ///
    /// `interested` is decided by the caller each time — fetching only
    /// happens while some consumer (the living sky, the weather duas)
    /// is actually switched on.
    func refresh(interested: Bool, now: Date, force: Bool = false) async {
        guard interested else { return }

        let cached = (conditions ?? SkyConditionsCacheStore.read())?.usable(at: now)
        conditions = cached

        guard SkyWeatherRefreshPolicy.shouldFetch(cached: cached, now: now, force: force),
              !inFlight
        else { return }
        inFlight = true
        defer { inFlight = false }

        guard let coordinates = try? await locate() else { return }
        do {
            let fresh = try await provider.currentConditions(at: coordinates, asOf: now)
            conditions = fresh
            SkyConditionsCacheStore.write(fresh)
        } catch {
            // Silent by contract. The cached reading, if any, keeps
            // serving until it expires; past that the plate paints its
            // idealized sky as if weather had never existed.
        }
    }
}
