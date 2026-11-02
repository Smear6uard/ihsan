import IhsanCore
@testable import IhsanIntents
import SwiftData
import XCTest

/// The funnel's one way back. One-tap recording on the Today card is
/// only safe because a mis-tap can be taken back in one tap; this is
/// the write that taking-back performs.
final class RemovePrayerLogIntentTests: XCTestCase {
    @MainActor
    func testRemovingALoggedPrayerLeavesNoRecord() async throws {
        let context = try await makeContext()
        _ = try await LogPrayerWithStatusIntent(prayer: .dhuhr, status: .onTime).perform()
        XCTAssertEqual(try fetchLogs(in: context).count, 1)

        _ = try await RemovePrayerLogIntent(prayer: .dhuhr).perform()

        XCTAssertTrue(try fetchLogs(in: context).isEmpty)
    }

    @MainActor
    func testRemovingTouchesOnlyThatPrayer() async throws {
        let context = try await makeContext()
        _ = try await LogPrayerWithStatusIntent(prayer: .dhuhr, status: .onTime).perform()
        _ = try await LogPrayerWithStatusIntent(prayer: .asr, status: .late).perform()

        _ = try await RemovePrayerLogIntent(prayer: .dhuhr).perform()

        let logs = try fetchLogs(in: context)
        XCTAssertEqual(logs.map(\.prayer), [.asr])
        XCTAssertEqual(logs.first?.status, .late)
    }

    /// Undo can arrive twice — a double tap, or a tap racing the card's
    /// own state. Removing what is not there is a quiet no-op.
    @MainActor
    func testRemovingWhatIsNotThereIsANoOp() async throws {
        let context = try await makeContext()

        _ = try await RemovePrayerLogIntent(prayer: .fajr).perform()
        _ = try await RemovePrayerLogIntent(prayer: .fajr).perform()

        XCTAssertTrue(try fetchLogs(in: context).isEmpty)
    }

    /// A make-up act shares its prayer's key but is not the cycle's own
    /// record, and a record a make-up points back at is part of the
    /// qadā ledger: removing it would orphan the make-up's link. Both
    /// stay.
    @MainActor
    func testARecordAMakeUpPointsAtIsKept() async throws {
        let context = try await makeContext()
        let original = try PrayerLogService().logPrayer(
            .fajr, status: .missed, sourceSurface: .app, in: context
        )
        _ = try PrayerLogService().markAsQada(
            originalLogID: original.id, sourceSurface: .app, in: context
        )

        _ = try await RemovePrayerLogIntent(prayer: .fajr).perform()

        let logs = try fetchLogs(in: context)
        XCTAssertEqual(logs.count, 2)
        XCTAssertTrue(logs.contains { $0.id == original.id })
        XCTAssertTrue(logs.contains { $0.qadaForPrayerLogID == original.id })
    }
}
