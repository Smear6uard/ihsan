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

    // MARK: - Logged-timestamp integrity (corrective E item 6)

    /// `loggedAt` derives from the injected clock at commit time —
    /// never from the wall clock. Under a flowing now-override (the
    /// device-review configuration that surfaced "ON TIME · 3:33 PM"
    /// at 3:22) the stamp must follow the override, and can never
    /// exceed the clock's current reading.
    @MainActor
    func testLoggedAtDerivesFromTheClockAndNeverExceedsItsNow() async throws {
        let context = try await makeContext()
        // A clock running one hour behind the wall clock.
        let clock = NowProvider(
            overrideStart: Date.now.addingTimeInterval(-3600),
            systemStart: .now
        )
        let service = PrayerLogService(clock: clock)

        let log = try service.logPrayer(
            .asr, status: .onTime, sourceSurface: .app, in: context
        )

        XCTAssertLessThanOrEqual(
            log.loggedAt, clock.now(),
            "loggedAt must never exceed the clock's current time"
        )
        // And it is the CLOCK's time, not the wall clock's: an hour
        // in the past, give or take test scheduling slop.
        let wallSkew = Date.now.timeIntervalSince(log.loggedAt)
        XCTAssertGreaterThan(wallSkew, 3590, "loggedAt was stamped from the wall clock")
        // The record files under the clock's civil day, so the Today
        // surface querying by its own clock always finds it.
        XCTAssertEqual(log.prayerDate, Calendar.current.startOfDay(for: clock.now()))
        XCTAssertEqual(log.modifiedAt, log.loggedAt)
    }

    /// A re-commit clamps any stored future stamp back to the clock —
    /// records created before a clock correction cannot keep a
    /// timestamp from the future.
    @MainActor
    func testRecommitClampsAFutureLoggedAtBackToTheClock() async throws {
        let context = try await makeContext()
        let service = PrayerLogService()

        let log = try service.logPrayer(
            .dhuhr, status: .late, sourceSurface: .app, in: context
        )
        log.loggedAt = Date.now.addingTimeInterval(660)
        try context.save()

        let updated = try service.logPrayer(
            .dhuhr, status: .onTime, sourceSurface: .app, in: context
        )
        XCTAssertLessThanOrEqual(updated.loggedAt, Date.now.addingTimeInterval(1))
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
