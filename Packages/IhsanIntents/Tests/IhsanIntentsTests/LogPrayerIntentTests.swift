import IhsanCore
@testable import IhsanIntents
import SwiftData
import XCTest

final class LogPrayerIntentTests: XCTestCase {
    @MainActor
    func testLoggingAsrOnTimeInsertsOnePrayerLog() async throws {
        let context = try await makeContext()

        _ = try await LogPrayerIntent(prayer: .asr).perform()

        let logs = try fetchLogs(in: context)
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs.first?.prayer, .asr)
        XCTAssertEqual(logs.first?.status, .onTime)
    }

    @MainActor
    func testLoggingAsrTwiceDedupsAndAdvancesModifiedAt() async throws {
        let context = try await makeContext()

        _ = try await LogPrayerIntent(prayer: .asr).perform()
        let first = try XCTUnwrap(fetchLogs(in: context).first)
        first.modifiedAt = .distantPast
        try context.save()

        _ = try await LogPrayerIntent(prayer: .asr).perform()

        let logs = try fetchLogs(in: context)
        XCTAssertEqual(logs.count, 1)
        XCTAssertGreaterThan(try XCTUnwrap(logs.first?.modifiedAt), .distantPast)
    }

    @MainActor
    func testLoggingAsrOnTimeUpdatesExistingLateLog() async throws {
        let context = try await makeContext()

        _ = try PrayerLogService().logPrayer(
            .asr,
            status: .late,
            prayedAt: .now,
            sourceSurface: .app,
            in: context
        )

        _ = try await LogPrayerIntent(prayer: .asr).perform()

        let logs = try fetchLogs(in: context)
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs.first?.status, .onTime)
    }

    @MainActor
    func testUnknownPrayerThrowsInvalidPrayer() async throws {
        _ = try await makeContext()
        let intent = LogPrayerIntent(prayerEntity: PrayerEntity(id: "unknown"))

        do {
            _ = try await intent.perform()
            XCTFail("Expected invalidPrayer to be thrown.")
        } catch IntentError.invalidPrayer(let raw) {
            XCTAssertEqual(raw, "unknown")
        } catch {
            XCTFail("Expected invalidPrayer, got \(error).")
        }
    }
}

@MainActor
func makeContext() async throws -> ModelContext {
    await ModelContainerAccess.shared.reset()
    let container = try IhsanModelContainerFactory.makeContainer(inMemory: true)
    await ModelContainerAccess.shared.setContainer(container)
    return ModelContext(container)
}

@MainActor
func fetchLogs(in context: ModelContext) throws -> [PrayerLog] {
    try context.fetch(FetchDescriptor<PrayerLog>())
}
