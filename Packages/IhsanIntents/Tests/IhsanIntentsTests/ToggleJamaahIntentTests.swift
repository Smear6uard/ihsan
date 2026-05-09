import IhsanCore
@testable import IhsanIntents
import SwiftData
import XCTest

final class ToggleJamaahIntentTests: XCTestCase {
    @MainActor
    func testTogglingNeverLoggedPrayerCreatesOnTimeJamaahLog() async throws {
        let context = try await makeContext()

        _ = try await ToggleJamaahIntent(prayer: .fajr).perform()

        let logs = try fetchLogs(in: context)
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs.first?.prayer, .fajr)
        XCTAssertEqual(logs.first?.status, .onTime)
        XCTAssertEqual(logs.first?.withJamaah, true)
    }

    @MainActor
    func testTogglingTwiceFlipsBackToFalse() async throws {
        let context = try await makeContext()

        _ = try await ToggleJamaahIntent(prayer: .fajr).perform()
        _ = try await ToggleJamaahIntent(prayer: .fajr).perform()

        let logs = try fetchLogs(in: context)
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs.first?.withJamaah, false)
    }

    @MainActor
    func testTogglingDoesNotChangeExistingStatus() async throws {
        let context = try await makeContext()

        _ = try PrayerLogService().logPrayer(
            .isha,
            status: .late,
            prayedAt: .now,
            sourceSurface: .app,
            in: context
        )

        _ = try await ToggleJamaahIntent(prayer: .isha).perform()

        let logs = try fetchLogs(in: context)
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs.first?.status, .late)
        XCTAssertEqual(logs.first?.withJamaah, true)
    }
}
