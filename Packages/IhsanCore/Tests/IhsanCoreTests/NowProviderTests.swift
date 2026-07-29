import Foundation
import Testing
@testable import IhsanCore

@Suite("NowProvider")
struct NowProviderTests {

    // MARK: - System clock

    @Test
    func systemProviderPassesTimelineDatesThrough() {
        let provider = NowProvider.system
        let tick = Date(timeIntervalSinceReferenceDate: 800_000_123)
        #expect(provider.resolve(tick) == tick)
    }

    @Test
    func systemProviderNowTracksTheRealClock() {
        let provider = NowProvider.system
        let before = Date()
        let now = provider.now()
        let after = Date()
        #expect(now >= before && now <= after)
    }

    // MARK: - Flowing override

    @Test
    func overrideFlowsAtRealRateFromItsAnchor() {
        let anchor = Date(timeIntervalSinceReferenceDate: 100_000)
        let launchedAt = Date(timeIntervalSinceReferenceDate: 900_000)
        let provider = NowProvider(overrideStart: anchor, systemStart: launchedAt)

        // At the moment of launch the override reads exactly its anchor.
        #expect(provider.resolve(launchedAt) == anchor)

        // 90 seconds of real time later, 90 seconds of override time
        // have passed — countdowns tick and boundaries fire.
        let later = launchedAt.addingTimeInterval(90)
        #expect(provider.resolve(later) == anchor.addingTimeInterval(90))
    }

    @Test
    func overrideIsEquatableByItsAnchors() {
        let anchor = Date(timeIntervalSinceReferenceDate: 100_000)
        let start = Date(timeIntervalSinceReferenceDate: 900_000)
        #expect(
            NowProvider(overrideStart: anchor, systemStart: start)
                == NowProvider(overrideStart: anchor, systemStart: start)
        )
        #expect(NowProvider(overrideStart: anchor, systemStart: start) != .system)
    }

    // MARK: - Launch-argument parsing

    @Test
    func parsesISO8601OverrideArgument() throws {
        let provider = NowProvider.fromLaunchArguments(
            ["ihsan", "-IhsanNowOverride", "2026-07-29T10:30:00Z"],
            systemStart: Date(timeIntervalSinceReferenceDate: 0)
        )
        let expected = try #require(
            ISO8601DateFormatter().date(from: "2026-07-29T10:30:00Z")
        )
        #expect(provider.resolve(Date(timeIntervalSinceReferenceDate: 0)) == expected)
    }

    @Test
    func missingOrMalformedArgumentFallsBackToSystem() {
        #expect(NowProvider.fromLaunchArguments(["ihsan"]) == .system)
        #expect(
            NowProvider.fromLaunchArguments(["ihsan", "-IhsanNowOverride"]) == .system
        )
        #expect(
            NowProvider.fromLaunchArguments(
                ["ihsan", "-IhsanNowOverride", "not-a-date"]
            ) == .system
        )
    }
}
