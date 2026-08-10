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
    /// Episode identity for the weather dua lines — when the current
    /// rain/wind/thunder began. Persisted so a relaunch mid-rain does
    /// not greet the same rain as new.
    private(set) var episodes: WeatherEpisodeLedger

    private let provider: any SkyWeatherProviding
    private let locate: @Sendable () async throws -> Coordinates
    private var inFlight = false

    init(
        provider: any SkyWeatherProviding = WeatherKitSkyProvider(),
        locate: @escaping @Sendable () async throws -> Coordinates
    ) {
        self.provider = provider
        self.locate = locate
        self.episodes = WeatherEpisodeLedgerStore.read() ?? WeatherEpisodeLedger()
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
        #if DEBUG
        if let forced = Self.debugForcedSky(now: now) {
            conditions = forced.conditions
            episodes = forced.episodes
            return
        }
        #endif

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
            episodes = episodes.advanced(with: fresh, now: now)
            SkyConditionsCacheStore.write(fresh)
            WeatherEpisodeLedgerStore.write(episodes)
        } catch {
            // Silent by contract. The cached reading, if any, keeps
            // serving until it expires; past that the plate paints its
            // idealized sky as if weather had never existed.
        }
    }

    #if DEBUG
    /// `-IhsanDebugSkyConditions <kind>` — the screenshot harness's way
    /// of standing under any sky. `<kind>` is a `SkyConditions.Kind`
    /// raw value, with two refinements: append `.strong` for a strong
    /// wind band, or pass `afterRain` for the just-stopped state.
    private static func debugForcedSky(
        now: Date
    ) -> (conditions: SkyConditions, episodes: WeatherEpisodeLedger)? {
        guard let raw = DebugLaunch.value(after: "-IhsanDebugSkyConditions") else {
            return nil
        }

        let began = now.addingTimeInterval(-30 * 60)
        if raw == "afterRain" {
            let dry = SkyConditions(
                kind: .mostlyCloudy,
                isPrecipitating: false,
                windBand: .calm,
                cloudBand: .broken,
                fetchedAt: now
            )
            var ledger = WeatherEpisodeLedger()
            ledger.rainEndedAt = now.addingTimeInterval(-10 * 60)
            return (dry, ledger)
        }

        let parts = raw.split(separator: ".")
        guard let kind = SkyConditions.Kind(rawValue: String(parts[0])) else { return nil }
        let wind: SkyConditions.WindBand = parts.count > 1 && parts[1] == "strong"
            ? .strong
            : .calm
        let forced = SkyConditions(
            kind: kind,
            isPrecipitating: kind.impliesPrecipitation,
            windBand: wind,
            cloudBand: kind == .clear ? .clear : .broken,
            fetchedAt: now
        )
        let ledger = WeatherEpisodeLedger().advanced(with: forced, now: began)
        return (forced, ledger)
    }
    #endif
}
