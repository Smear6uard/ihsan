import IhsanCore
@testable import IhsanIntents
import SwiftData
import XCTest

/// Pins the log sheet's commit funnel at the intent layer: a fresh
/// commit creates the PrayerLog in the registered container, and a
/// re-commit edits the same row in place (dedup holds; no duplicate).
final class LogPrayerWithStatusIntentTests: XCTestCase {

    @MainActor
    func testFreshCommitCreatesLogInRegisteredContainer() async throws {
        let context = try await makeContext()

        _ = try await LogPrayerWithStatusIntent(prayer: .dhuhr, status: .onTime).perform()

        let logs = try fetchLogs(in: context)
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs.first?.prayer, .dhuhr)
        XCTAssertEqual(logs.first?.status, .onTime)
    }

    @MainActor
    func testEditingCommitUpdatesExistingLogInPlace() async throws {
        let context = try await makeContext()

        _ = try await LogPrayerWithStatusIntent(prayer: .dhuhr, status: .late).perform()
        _ = try await LogPrayerWithStatusIntent(prayer: .dhuhr, status: .onTime).perform()

        let logs = try fetchLogs(in: context)
        XCTAssertEqual(logs.count, 1, "Editing must update in place, never duplicate.")
        XCTAssertEqual(logs.first?.status, .onTime)
    }

    @MainActor
    func testEditPreservesJamaahFlag() async throws {
        let context = try await makeContext()

        _ = try PrayerLogService().logPrayer(
            .dhuhr,
            status: .late,
            withJamaah: true,
            sourceSurface: .app,
            in: context
        )

        _ = try await LogPrayerWithStatusIntent(prayer: .dhuhr, status: .onTime).perform()

        let logs = try fetchLogs(in: context)
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs.first?.status, .onTime)
        XCTAssertEqual(logs.first?.withJamaah, true, "A status edit must not clear jamāʿah.")
    }

    @MainActor
    func testEachStatusRoundTrips() async throws {
        let context = try await makeContext()

        for (prayer, status) in [
            (Prayer.fajr, PrayerStatus.late),
            (.asr, .qada),
            (.maghrib, .missed),
        ] {
            _ = try await LogPrayerWithStatusIntent(prayer: prayer, status: status).perform()
        }

        let logs = try fetchLogs(in: context)
        XCTAssertEqual(logs.count, 3)
        XCTAssertEqual(logs.first { $0.prayer == .fajr }?.status, .late)
        XCTAssertEqual(logs.first { $0.prayer == .asr }?.status, .qada)
        XCTAssertEqual(logs.first { $0.prayer == .maghrib }?.status, .missed)
    }
}
