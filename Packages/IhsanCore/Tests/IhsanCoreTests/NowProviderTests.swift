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

    // MARK: - Wall-time anchoring (the dawn-review countdown bug)
    //
    // A review override means a WALL CLOCK moment. Anchoring "5:27 AM"
    // through a UTC or standard-zone offset during daylight-saving
    // time landed the anchor an hour ahead: Fajr looked closed before
    // sunrise, the card advanced to Dhuhr, the closed tense rendered
    // twenty minutes early, and "opens in" ran an hour short. The
    // suffix-less form pins the anchor to the wall clock of the
    // anchored DATE, in any zone, on both sides of a DST boundary.

    @Test
    func suffixlessOverrideAnchorsToTheLocalWallClock() throws {
        let chicago = try #require(TimeZone(identifier: "America/Chicago"))
        let provider = NowProvider.fromLaunchArguments(
            ["ihsan", "-IhsanNowOverride", "2026-07-30T05:27:00"],
            systemStart: Date(timeIntervalSinceReferenceDate: 0),
            timeZone: chicago
        )
        let resolved = provider.resolve(Date(timeIntervalSinceReferenceDate: 0))

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = chicago
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: resolved
        )
        #expect(components.hour == 5 && components.minute == 27 && components.second == 0)
        #expect(components.year == 2026 && components.month == 7 && components.day == 30)
    }

    /// The wall-clock guarantee holds across the DST boundary: the
    /// same suffix-less form lands on the named wall moment in winter
    /// (CST, -06:00) and in summer (CDT, -05:00) — the two anchors
    /// differ by exactly the offset change, never by a stale offset.
    @Test
    func wallTimeAnchorSurvivesDSTBoundaries() throws {
        let chicago = try #require(TimeZone(identifier: "America/Chicago"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = chicago

        for day in ["2026-01-15", "2026-07-30", "2026-03-08", "2026-11-01"] {
            let instant = try #require(
                NowProvider.parseOverrideInstant("\(day)T05:27:00", timeZone: chicago),
                "failed to parse \(day)"
            )
            let components = calendar.dateComponents([.hour, .minute], from: instant)
            #expect(
                components.hour == 5 && components.minute == 27,
                "\(day) anchored off the wall clock"
            )
        }
    }

    /// A non-local zone behaves identically — the anchor is the wall
    /// moment of the zone asked for, not of the machine running the
    /// tests.
    @Test
    func wallTimeAnchorRespectsANonLocalZone() throws {
        let karachi = try #require(TimeZone(identifier: "Asia/Karachi"))
        let instant = try #require(
            NowProvider.parseOverrideInstant("2026-07-30T05:27:00", timeZone: karachi)
        )
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = karachi
        let components = calendar.dateComponents([.hour, .minute], from: instant)
        #expect(components.hour == 5 && components.minute == 27)
    }

    /// Explicit offsets remain explicit — a `Z` or `+03:00` suffix is
    /// taken exactly as written.
    @Test
    func explicitOffsetsAreHonored() throws {
        let zulu = try #require(NowProvider.parseOverrideInstant("2026-07-30T05:27:00Z"))
        #expect(zulu == ISO8601DateFormatter().date(from: "2026-07-30T05:27:00Z"))

        let offset = try #require(NowProvider.parseOverrideInstant("2026-07-30T05:27:00+03:00"))
        #expect(offset == ISO8601DateFormatter().date(from: "2026-07-30T05:27:00+03:00"))
    }

    @Test
    func malformedWallTimesAreRejected() {
        #expect(NowProvider.parseOverrideInstant("2026-07-30") == nil)
        #expect(NowProvider.parseOverrideInstant("2026-07-30T") == nil)
        #expect(NowProvider.parseOverrideInstant("2026-07-30T05") == nil)
        #expect(NowProvider.parseOverrideInstant("yesterday") == nil)
        #expect(NowProvider.parseOverrideInstant("2026-13-40T05:27:00") == nil)
    }
}
