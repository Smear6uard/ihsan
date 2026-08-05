import Foundation
import IhsanCore
import IhsanPrayerTimes
@testable import IhsanIntents
import SwiftData
import XCTest

/// The funnel's half of clock 1: what the single logging path writes
/// down when the wall clock has passed midnight but the cycle has not
/// ended.
///
/// Every one of these went to the wrong day before this corrective — a
/// 1 AM Isha filed under a date whose own Isha was still twenty hours
/// away, and was then measured against that future window and stored as
/// missed.
final class CycleAttributionTests: XCTestCase {

    private static let toronto = Coordinates(latitude: 43.6532, longitude: -79.3832)

    /// The funnel stamps everything in `TimeZone.current` — it has no
    /// place to read a zone from, since coordinates are never stored.
    /// The test lives in the same zone so its expectations describe the
    /// code rather than the machine.
    private static let timeZone = TimeZone.current

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    private static func at(day: Int, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(
            from: DateComponents(year: 2026, month: 8, day: day, hour: hour, minute: minute)
        )!
    }

    private func service(at instant: Date) -> PrayerLogService {
        PrayerLogService(
            prayerTimesProvider: AdhanPrayerTimesProvider(),
            clock: NowProvider(overrideStart: instant, systemStart: .now)
        )
    }

    private func dayTimes(for date: Date) throws -> DayPrayerTimes {
        try AdhanPrayerTimesProvider().dayTimes(
            for: date,
            coordinates: Self.toronto,
            timeZone: Self.timeZone,
            calculationMethod: .isna,
            madhab: .standard,
            highLatitudeRule: .middleOfNight
        )
    }

    // MARK: - Post-midnight Isha

    @MainActor
    func testOneAmIshaBelongsToTheEveningCycle() async throws {
        let context = try await makeContext()
        let oneAm = Self.at(day: 5, 1, 0)

        let log = try service(at: oneAm).logPrayer(
            .isha,
            status: .onTime,
            coordinates: Self.toronto,
            sourceSurface: .app,
            in: context
        )

        XCTAssertEqual(
            log.prayerDate, Self.at(day: 4, 0, 0),
            "a 1 AM Isha must file under the evening it belongs to"
        )
        XCTAssertEqual(
            log.scheduledTime, try dayTimes(for: Self.at(day: 4, 12, 0)).isha.scheduledTime,
            "a 1 AM Isha must be measured against the Isha that is still open"
        )
        XCTAssertEqual(log.dedupKey, "isha-2026-08-04")
    }

    /// The property the corrective is named for.
    @MainActor
    func testMidnightIsNotABoundary() async throws {
        let beforeContext = try await makeContext()
        let afterContext = try await makeContext()

        let before = try service(at: Self.at(day: 4, 23, 59)).logPrayer(
            .isha, status: .onTime, coordinates: Self.toronto, sourceSurface: .app,
            in: beforeContext
        )
        let after = try service(at: Self.at(day: 5, 0, 1)).logPrayer(
            .isha, status: .onTime, coordinates: Self.toronto, sourceSurface: .app,
            in: afterContext
        )

        XCTAssertEqual(before.prayerDate, after.prayerDate)
        XCTAssertEqual(before.scheduledTime, after.scheduledTime)
        XCTAssertEqual(before.dedupKey, after.dedupKey)
    }

    /// Two taps either side of midnight are the SAME record, not two.
    @MainActor
    func testATapEitherSideOfMidnightUpdatesOneRow() async throws {
        let context = try await makeContext()

        _ = try service(at: Self.at(day: 4, 23, 50)).logPrayer(
            .isha, status: .late, coordinates: Self.toronto, sourceSurface: .app, in: context
        )
        _ = try service(at: Self.at(day: 5, 0, 10)).logPrayer(
            .isha, status: .onTime, coordinates: Self.toronto, sourceSurface: .app, in: context
        )

        let logs = try fetchLogs(in: context).filter { $0.prayer == .isha }
        XCTAssertEqual(logs.count, 1, "midnight split one Isha into two rows")
        XCTAssertEqual(logs.first?.status, PrayerStatus.onTime)
    }

    // MARK: - The rest of the cycle before dawn

    /// Before Fajr the whole cycle is still yesterday's, so a
    /// pre-dawn correction to any prayer lands on yesterday's row and
    /// is measured against yesterday's window — not against one that
    /// has yet to open.
    @MainActor
    func testPreDawnLogOfAnEarlierPrayerUsesYesterdaysWindow() async throws {
        let context = try await makeContext()
        let threeAm = Self.at(day: 5, 3, 0)

        let log = try service(at: threeAm).logPrayer(
            .asr, status: .late, prayedAt: Self.at(day: 4, 18, 30),
            coordinates: Self.toronto, sourceSurface: .app, in: context
        )

        XCTAssertEqual(log.prayerDate, Self.at(day: 4, 0, 0))
        XCTAssertEqual(
            log.scheduledTime, try dayTimes(for: Self.at(day: 4, 12, 0)).asr.scheduledTime
        )
        // And the lateness is measured from a start that really did
        // precede the act.
        XCTAssertNotNil(log.lateBySeconds)
        XCTAssertGreaterThan(try XCTUnwrap(log.lateBySeconds), 0)
    }

    /// After Fajr the tracker has rolled: the same clock hour on the
    /// other side of dawn belongs to the new cycle.
    @MainActor
    func testAfterFajrTheCycleHasRolled() async throws {
        let context = try await makeContext()
        let fajr = try dayTimes(for: Self.at(day: 5, 12, 0)).fajr.scheduledTime

        let log = try service(at: fajr.addingTimeInterval(60)).logPrayer(
            .fajr, status: .onTime, coordinates: Self.toronto, sourceSurface: .app, in: context
        )

        XCTAssertEqual(log.prayerDate, Self.at(day: 5, 0, 0))
    }

    // MARK: - Retroactive entries are untouched

    /// A day passed explicitly from Path IS the cycle key. Nothing
    /// re-derives it, and its schedule comes from that day's own table.
    @MainActor
    func testAnExplicitDayIsTakenAsTheCycle() async throws {
        let context = try await makeContext()

        let log = try service(at: Self.at(day: 5, 1, 0)).logPrayer(
            .isha,
            status: .onTime,
            prayerDate: Self.at(day: 1, 0, 0),
            coordinates: Self.toronto,
            sourceSurface: .app,
            in: context
        )

        XCTAssertEqual(log.prayerDate, Self.at(day: 1, 0, 0))
        XCTAssertEqual(
            log.scheduledTime, try dayTimes(for: Self.at(day: 1, 12, 0)).isha.scheduledTime
        )
    }
}
