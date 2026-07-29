import IhsanCore
@testable import IhsanIntents
import SwiftData
import XCTest

final class LogNaflIntentTests: XCTestCase {
    private let fixedDay = Date(timeIntervalSinceReferenceDate: 700_000_000)

    @MainActor
    func testLogsNaflWhenTheLayerIsOn() async throws {
        let context = try await makeContext()
        let settings = try UserSettings.fetchOrCreate(in: context)
        settings.sunnahLayerEnabled = true
        try context.save()

        _ = try await LogNaflIntent(kind: .duha, naflDate: fixedDay).perform()

        let logs = try context.fetch(FetchDescriptor<NaflLog>())
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs.first?.kind, .duha)
        XCTAssertNil(logs.first?.rakahCount)
    }

    @MainActor
    func testSecondTapRemovesTheSameDaysLog() async throws {
        let context = try await makeContext()
        let settings = try UserSettings.fetchOrCreate(in: context)
        settings.sunnahLayerEnabled = true
        try context.save()

        _ = try await LogNaflIntent(kind: .rawatibBefore(.fajr), naflDate: fixedDay).perform()
        _ = try await LogNaflIntent(kind: .rawatibBefore(.fajr), naflDate: fixedDay).perform()

        XCTAssertTrue(try context.fetch(FetchDescriptor<NaflLog>()).isEmpty)
    }

    @MainActor
    func testDifferentNightsDoNotCollide() async throws {
        let context = try await makeContext()
        let settings = try UserSettings.fetchOrCreate(in: context)
        settings.sunnahLayerEnabled = true
        try context.save()

        _ = try await LogNaflIntent(kind: .witr, naflDate: fixedDay).perform()
        _ = try await LogNaflIntent(
            kind: .witr,
            naflDate: fixedDay.addingTimeInterval(86_400)
        ).perform()

        XCTAssertEqual(try context.fetch(FetchDescriptor<NaflLog>()).count, 2)
    }

    @MainActor
    func testWritesNothingWhenTheLayerIsOff() async throws {
        let context = try await makeContext()

        _ = try await LogNaflIntent(kind: .qiyam, naflDate: fixedDay).perform()

        XCTAssertTrue(try context.fetch(FetchDescriptor<NaflLog>()).isEmpty)
    }

    @MainActor
    func testRakahCountStoredOnlyWhenGiven() async throws {
        let context = try await makeContext()
        let settings = try UserSettings.fetchOrCreate(in: context)
        settings.sunnahLayerEnabled = true
        try context.save()

        _ = try await LogNaflIntent(kind: .witr, naflDate: fixedDay, rakahCount: 3).perform()

        let logs = try context.fetch(FetchDescriptor<NaflLog>())
        XCTAssertEqual(logs.first?.rakahCount, 3)
    }

    @MainActor
    func testUnknownKindKeyThrows() async throws {
        _ = try await makeContext()
        var intent = LogNaflIntent()
        intent.kindKey = "tarawih"

        do {
            _ = try await intent.perform()
            XCTFail("Expected an invalid-kind error")
        } catch {
            // Any thrown IntentError is the contract; unknown kinds never write.
        }
    }
}
