import IhsanCore
@testable import IhsanIntents
import SwiftData
import XCTest

/// Pins the retroactive path: an explicit prayer date attaches the
/// log to THAT civil day, dedup holds per (prayer, day), and the
/// jamāʿah toggle edits the same day's row.
final class RetroactiveLogTests: XCTestCase {

    private var yesterday: Date {
        Calendar.current.date(
            byAdding: .day, value: -1,
            to: Calendar.current.startOfDay(for: .now)
        )!
    }

    @MainActor
    func testExplicitDateAttachesLogToThatDay() async throws {
        let context = try await makeContext()

        _ = try await LogPrayerWithStatusIntent(
            prayer: .dhuhr, status: .qada, date: yesterday
        ).perform()

        let logs = try fetchLogs(in: context)
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs.first?.prayerDate, Calendar.current.startOfDay(for: yesterday))
        XCTAssertEqual(logs.first?.status, .qada)
    }

    @MainActor
    func testRetroAndTodayEntriesDedupIndependently() async throws {
        let context = try await makeContext()

        _ = try await LogPrayerWithStatusIntent(prayer: .dhuhr, status: .onTime).perform()
        _ = try await LogPrayerWithStatusIntent(
            prayer: .dhuhr, status: .missed, date: yesterday
        ).perform()

        let logs = try fetchLogs(in: context)
        XCTAssertEqual(logs.count, 2, "Different days are different entries.")

        // Editing yesterday's entry rewrites it in place.
        _ = try await LogPrayerWithStatusIntent(
            prayer: .dhuhr, status: .qada, date: yesterday
        ).perform()
        let after = try fetchLogs(in: context)
        XCTAssertEqual(after.count, 2)
        let yesterdayRow = after.first {
            $0.prayerDate == Calendar.current.startOfDay(for: yesterday)
        }
        XCTAssertEqual(yesterdayRow?.status, .qada)
    }

    @MainActor
    func testToggleJamaahWithDateEditsThatDaysRow() async throws {
        let context = try await makeContext()

        _ = try await LogPrayerWithStatusIntent(
            prayer: .fajr, status: .late, date: yesterday
        ).perform()
        _ = try await ToggleJamaahIntent(prayer: .fajr, date: yesterday).perform()

        let logs = try fetchLogs(in: context)
        XCTAssertEqual(logs.count, 1, "The toggle must edit, not create.")
        XCTAssertEqual(logs.first?.withJamaah, true)
        XCTAssertEqual(logs.first?.status, .late)
    }

    @MainActor
    func testNilDateStillMeansToday() async throws {
        let context = try await makeContext()

        _ = try await LogPrayerWithStatusIntent(prayer: .asr, status: .onTime).perform()

        let logs = try fetchLogs(in: context)
        XCTAssertEqual(logs.first?.prayerDate, Calendar.current.startOfDay(for: .now))
    }
}
