import Foundation
import Testing
@testable import IhsanFiqhConfig

@Test
func forceRefreshDoesNotMutateInMemoryConfig() async throws {
    let service = FiqhConfigService()
    let initial = try await service.currentConfig()
    _ = try? await service.forceRefresh()
    let after = try await service.currentConfig()
    #expect(initial.contentVersion == after.contentVersion,
            "Force refresh must not mutate the active in-memory config; it should only update cache.")
    #expect(initial.schemaVersion == after.schemaVersion)
}

@Test
func currentConfigIsStableAcrossCalls() async throws {
    let service = FiqhConfigService()
    let first = try await service.currentConfig()
    let second = try await service.currentConfig()
    let third = try await service.currentConfig()
    #expect(first == second)
    #expect(second == third)
}

@Test
func loadedConfigSnapshotReturnsNilBeforeFirstLoad() async {
    let service = FiqhConfigService()
    let snapshot = await service.loadedConfigSnapshot()
    #expect(snapshot == nil)
}

@Test
func loadedConfigSnapshotReturnsLoadedAfterCurrentConfig() async throws {
    let service = FiqhConfigService()
    _ = try await service.currentConfig()
    let snapshot = await service.loadedConfigSnapshot()
    #expect(snapshot != nil)
}

@Test
func versionExposesSchemaAndContent() async throws {
    let service = FiqhConfigService()
    let config = try await service.currentConfig()
    let version = config.version
    #expect(version.schemaVersion == config.schemaVersion)
    #expect(version.contentVersion == config.contentVersion)
}
