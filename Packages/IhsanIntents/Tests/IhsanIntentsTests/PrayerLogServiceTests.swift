import Foundation
import IhsanCore
@testable import IhsanIntents
import SwiftData
import XCTest

final class PrayerLogServiceTests: XCTestCase {
    @MainActor
    func testLatePrayerProducesLateBySeconds() async throws {
        let context = try await makeContext()
        let prayedAt = Date.now.addingTimeInterval(120)

        let log = try PrayerLogService().logPrayer(
            .dhuhr,
            status: .late,
            prayedAt: prayedAt,
            sourceSurface: .app,
            in: context
        )

        XCTAssertNotNil(log.lateBySeconds)
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(log.lateBySeconds), 0)
    }

    @MainActor
    func testOnTimePrayerProducesNilLateBySeconds() async throws {
        let context = try await makeContext()

        let log = try PrayerLogService().logPrayer(
            .dhuhr,
            status: .onTime,
            prayedAt: .now,
            sourceSurface: .app,
            in: context
        )

        XCTAssertNil(log.lateBySeconds)
    }

    @MainActor
    func testMarkAsQadaCreatesLinkedQadaLogAndPreservesOriginalMissedLog() async throws {
        let context = try await makeContext()
        let service = PrayerLogService()

        let original = try service.logPrayer(
            .maghrib,
            status: .missed,
            sourceSurface: .app,
            in: context
        )

        let qada = try service.markAsQada(
            originalLogID: original.id,
            sourceSurface: .app,
            in: context
        )

        let logs = try fetchLogs(in: context)
        XCTAssertEqual(logs.count, 2)
        XCTAssertEqual(qada.status, PrayerStatus.qada)
        XCTAssertEqual(qada.qadaForPrayerLogID, original.id)
        XCTAssertEqual(original.status, PrayerStatus.missed)
    }

    @MainActor
    func testDedupKeyFormatUsesPrayerRawAndUTCDate() async throws {
        let date = try XCTUnwrap(Calendar(identifier: .gregorian).date(from: DateComponents(
            timeZone: TimeZone(secondsFromGMT: 0),
            year: 2026,
            month: 5,
            day: 9,
            hour: 23,
            minute: 59
        )))

        let key = PrayerLogService.makeDedupKey(prayer: .isha, prayerDate: date)

        XCTAssertEqual(key, "isha-2026-05-09")
    }
}
