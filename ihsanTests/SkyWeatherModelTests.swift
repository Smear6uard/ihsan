import Foundation
import Testing
import IhsanCore
import IhsanPrayerTimes
@testable import ihsan

/// Counts fetches and returns whatever it was seeded with.
private actor FakeSkyProvider: SkyWeatherProviding {
    private(set) var fetchCount = 0
    private let result: Result<SkyConditions, Error>

    init(_ result: Result<SkyConditions, Error>) {
        self.result = result
    }

    func currentConditions(at coordinates: Coordinates, asOf now: Date) async throws -> SkyConditions {
        fetchCount += 1
        return try result.get()
    }
}

private struct FetchRefused: Error {}

/// Serialized: every test drives the one real cache suite.
@MainActor
@Suite("Sky weather refresh", .serialized)
struct SkyWeatherModelTests {
    private static let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func sample(age: TimeInterval) -> SkyConditions {
        SkyConditions(
            kind: .rain,
            isPrecipitating: true,
            windBand: .calm,
            cloudBand: .overcast,
            fetchedAt: Self.now.addingTimeInterval(-age)
        )
    }

    private func makeModel(provider: FakeSkyProvider) -> SkyWeatherModel {
        SkyWeatherModel(
            provider: provider,
            locate: { Coordinates(latitude: 41.88, longitude: -87.63) }
        )
    }

    @Test("A failed fetch keeps serving the cached reading, silently")
    func failureKeepsCache() async {
        let cached = sample(age: SkyConditions.refreshInterval + 60)
        SkyConditionsCacheStore.write(cached)
        defer { SkyConditionsCacheStore.clear() }

        let provider = FakeSkyProvider(.failure(FetchRefused()))
        let model = makeModel(provider: provider)
        await model.refresh(interested: true, now: Self.now)

        #expect(await provider.fetchCount == 1)
        #expect(model.current(at: Self.now) == cached)
    }

    @Test("A failed fetch with nothing cached leaves no conditions at all")
    func failureWithEmptyCacheIsSilent() async {
        SkyConditionsCacheStore.clear()

        let provider = FakeSkyProvider(.failure(FetchRefused()))
        let model = makeModel(provider: provider)
        await model.refresh(interested: true, now: Self.now)

        #expect(model.current(at: Self.now) == nil)
    }

    @Test("A fresh cached reading is served without fetching")
    func freshCacheSkipsFetch() async {
        let cached = sample(age: 60)
        SkyConditionsCacheStore.write(cached)
        defer { SkyConditionsCacheStore.clear() }

        let provider = FakeSkyProvider(.failure(FetchRefused()))
        let model = makeModel(provider: provider)
        await model.refresh(interested: true, now: Self.now)

        #expect(await provider.fetchCount == 0)
        #expect(model.current(at: Self.now) == cached)
    }

    @Test("A stale reading is refetched and the cache rewritten")
    func staleCacheRefetches() async {
        SkyConditionsCacheStore.write(sample(age: SkyConditions.refreshInterval + 60))
        defer { SkyConditionsCacheStore.clear() }

        let fresh = SkyConditions(
            kind: .clear,
            isPrecipitating: false,
            windBand: .calm,
            cloudBand: .clear,
            fetchedAt: Self.now
        )
        let provider = FakeSkyProvider(.success(fresh))
        let model = makeModel(provider: provider)
        await model.refresh(interested: true, now: Self.now)

        #expect(await provider.fetchCount == 1)
        #expect(model.current(at: Self.now) == fresh)
        #expect(SkyConditionsCacheStore.read() == fresh)
    }

    @Test("An expired reading is not served while the refetch runs")
    func expiredCacheIsNotServed() async {
        SkyConditionsCacheStore.write(sample(age: SkyConditions.expiryInterval + 60))
        defer { SkyConditionsCacheStore.clear() }

        let provider = FakeSkyProvider(.failure(FetchRefused()))
        let model = makeModel(provider: provider)
        await model.refresh(interested: true, now: Self.now)

        #expect(await provider.fetchCount == 1)
        #expect(model.current(at: Self.now) == nil)
    }

    @Test("No interested consumer means no fetch")
    func noInterestNoFetch() async {
        SkyConditionsCacheStore.clear()

        let provider = FakeSkyProvider(.success(sample(age: 0)))
        let model = makeModel(provider: provider)
        await model.refresh(interested: false, now: Self.now)

        #expect(await provider.fetchCount == 0)
        #expect(model.current(at: Self.now) == nil)
    }
}
