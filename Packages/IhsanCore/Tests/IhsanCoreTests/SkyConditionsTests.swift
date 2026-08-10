import Foundation
import Testing
@testable import IhsanCore

@Suite("Sky conditions model")
struct SkyConditionsTests {
    private func conditions(
        kind: SkyConditions.Kind = .clear,
        fetchedAt: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> SkyConditions {
        SkyConditions(
            kind: kind,
            isPrecipitating: false,
            windBand: .calm,
            cloudBand: .clear,
            fetchedAt: fetchedAt
        )
    }

    // MARK: - Wind bands

    @Test("Wind below the breeze threshold is calm")
    func windCalm() {
        #expect(SkyConditions.WindBand(kilometersPerHour: 0) == .calm)
        #expect(SkyConditions.WindBand(kilometersPerHour: 19.9) == .calm)
    }

    @Test("Wind at the breeze threshold is breezy up to the strong threshold")
    func windBreezy() {
        #expect(SkyConditions.WindBand(kilometersPerHour: 20.0) == .breezy)
        #expect(SkyConditions.WindBand(kilometersPerHour: 37.9) == .breezy)
    }

    @Test("Wind at the strong threshold and above is strong")
    func windStrong() {
        #expect(SkyConditions.WindBand(kilometersPerHour: 38.0) == .strong)
        #expect(SkyConditions.WindBand(kilometersPerHour: 90.0) == .strong)
    }

    // MARK: - Cloud bands

    @Test("Cloud cover maps onto the four bands at fixed boundaries")
    func cloudBands() {
        #expect(SkyConditions.CloudBand(cloudCover: 0.0) == .clear)
        #expect(SkyConditions.CloudBand(cloudCover: 0.19) == .clear)
        #expect(SkyConditions.CloudBand(cloudCover: 0.2) == .scattered)
        #expect(SkyConditions.CloudBand(cloudCover: 0.49) == .scattered)
        #expect(SkyConditions.CloudBand(cloudCover: 0.5) == .broken)
        #expect(SkyConditions.CloudBand(cloudCover: 0.84) == .broken)
        #expect(SkyConditions.CloudBand(cloudCover: 0.85) == .overcast)
        #expect(SkyConditions.CloudBand(cloudCover: 1.0) == .overcast)
    }

    // MARK: - Staleness and expiry

    @Test("Conditions are fresh until the refresh interval elapses")
    func freshness() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let sample = conditions(fetchedAt: base)
        #expect(!sample.isStale(at: base.addingTimeInterval(SkyConditions.refreshInterval - 1)))
        #expect(sample.isStale(at: base.addingTimeInterval(SkyConditions.refreshInterval)))
    }

    @Test("Conditions expire after the expiry interval and stop being usable")
    func expiry() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let sample = conditions(fetchedAt: base)
        #expect(!sample.isExpired(at: base.addingTimeInterval(SkyConditions.expiryInterval - 1)))
        #expect(sample.isExpired(at: base.addingTimeInterval(SkyConditions.expiryInterval)))
        #expect(sample.usable(at: base.addingTimeInterval(SkyConditions.expiryInterval - 1)) != nil)
        #expect(sample.usable(at: base.addingTimeInterval(SkyConditions.expiryInterval)) == nil)
    }

    @Test("A stale-but-unexpired reading is still usable while a refresh runs")
    func staleButUsable() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let sample = conditions(fetchedAt: base)
        let probe = base.addingTimeInterval(SkyConditions.refreshInterval + 60)
        #expect(sample.isStale(at: probe))
        #expect(sample.usable(at: probe) != nil)
    }

    // MARK: - Refresh policy

    @Test("No cached reading always fetches")
    func policyNoCache() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        #expect(SkyWeatherRefreshPolicy.shouldFetch(cached: nil, now: now))
    }

    @Test("A fresh reading is not refetched")
    func policyFresh() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let sample = conditions(fetchedAt: now.addingTimeInterval(-60))
        #expect(!SkyWeatherRefreshPolicy.shouldFetch(cached: sample, now: now))
    }

    @Test("A stale reading is refetched")
    func policyStale() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let sample = conditions(fetchedAt: now.addingTimeInterval(-SkyConditions.refreshInterval))
        #expect(SkyWeatherRefreshPolicy.shouldFetch(cached: sample, now: now))
    }

    @Test("Force overrides freshness")
    func policyForce() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let sample = conditions(fetchedAt: now.addingTimeInterval(-60))
        #expect(SkyWeatherRefreshPolicy.shouldFetch(cached: sample, now: now, force: true))
    }

    // MARK: - Cache store

    @Test("The cache store round-trips and clears")
    func cacheRoundTrip() {
        SkyConditionsCacheStore.clear()
        #expect(SkyConditionsCacheStore.read() == nil)

        let sample = SkyConditions(
            kind: .rain,
            isPrecipitating: true,
            windBand: .breezy,
            cloudBand: .overcast,
            fetchedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        SkyConditionsCacheStore.write(sample)
        #expect(SkyConditionsCacheStore.read() == sample)

        SkyConditionsCacheStore.clear()
        #expect(SkyConditionsCacheStore.read() == nil)
    }

    @Test("Every condition kind survives an encode-decode round trip")
    func kindRoundTrip() throws {
        for kind in SkyConditions.Kind.allCases {
            let sample = conditions(kind: kind)
            let data = try JSONEncoder().encode(sample)
            let decoded = try JSONDecoder().decode(SkyConditions.self, from: data)
            #expect(decoded == sample)
        }
    }

    @Test("Kinds that are precipitation by definition say so")
    func impliedPrecipitation() {
        let wet: Set<SkyConditions.Kind> = [
            .drizzle, .rain, .heavyRain, .sunShowers,
            .freezingDrizzle, .freezingRain, .sleet, .wintryMix, .hail,
            .snow, .heavySnow, .flurries, .blowingSnow, .sunFlurries, .blizzard,
            .isolatedThunderstorms, .scatteredThunderstorms, .thunderstorms,
            .strongStorms, .hurricane, .tropicalStorm,
        ]
        for kind in SkyConditions.Kind.allCases {
            #expect(kind.impliesPrecipitation == wet.contains(kind), "\(kind)")
        }
    }

    @Test("An unrecognized stored kind decodes as unknown rather than failing")
    func unknownKindDecodes() throws {
        let json = """
        {"kind":"plasmaStorm","isPrecipitating":false,"windBand":"calm","cloudBand":"clear","fetchedAt":0}
        """
        let decoded = try JSONDecoder().decode(SkyConditions.self, from: Data(json.utf8))
        #expect(decoded.kind == .unknown)
    }
}
