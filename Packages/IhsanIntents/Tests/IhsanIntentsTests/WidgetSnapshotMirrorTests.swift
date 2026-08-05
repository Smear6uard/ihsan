import IhsanCore
@testable import IhsanIntents
import SwiftData
import XCTest

/// The interactive round-trip, recorded: a widget button runs
/// `LogPrayerIntent`, the funnel writes the store, and the mirror
/// replaces today's logged states on the published snapshot — so the
/// face WidgetKit re-renders immediately afterwards already shows the
/// log. This is the whole loop minus WidgetKit's own reload, which is
/// the system's to perform.
final class WidgetSnapshotMirrorTests: XCTestCase {

    override func tearDown() {
        WidgetSnapshotStore.clear()
        super.tearDown()
    }

    /// A snapshot for the machine's current civil day, so the intent's
    /// log (stamped to today) falls inside the mirrored bracket.
    private func seedSnapshot() {
        let timeZone = TimeZone.current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let dayStart = calendar.startOfDay(for: .now)
        func at(_ day: Int, _ hour: Int, _ minute: Int) -> Date {
            calendar.date(
                byAdding: DateComponents(day: day, hour: hour, minute: minute),
                to: dayStart
            )!
        }
        let today = WidgetSnapshot.DayTable(
            civilDayStart: dayStart,
            fajr: at(0, 4, 10), sunrise: at(0, 5, 42), dhuhr: at(0, 12, 58),
            asr: at(0, 16, 53), maghrib: at(0, 20, 11), isha: at(0, 21, 43)
        )
        let tomorrow = WidgetSnapshot.DayTable(
            civilDayStart: at(1, 0, 0),
            fajr: at(1, 4, 11), sunrise: at(1, 5, 43), dhuhr: at(1, 12, 58),
            asr: at(1, 16, 52), maghrib: at(1, 20, 10), isha: at(1, 21, 41)
        )
        func night(_ start: Date, _ end: Date) -> WidgetSnapshot.NightTable {
            let span = end.timeIntervalSince(start)
            return WidgetSnapshot.NightTable(
                start: start, end: end,
                nisfAlLayl: start.addingTimeInterval(span / 2),
                lastThirdStart: start.addingTimeInterval(span * 2 / 3)
            )
        }
        WidgetSnapshotStore.write(WidgetSnapshot(
            writtenAt: .now,
            timeZoneIdentifier: timeZone.identifier,
            cityName: "Test",
            qiblaBearingDegrees: nil,
            yesterdayIsha: at(-1, 21, 44),
            cycleDayStart: dayStart,
            cycleRollsAt: tomorrow.fajr,
            today: today,
            tomorrow: tomorrow,
            dayAfterTomorrowFajr: at(2, 4, 12),
            tonight: night(today.maghrib, tomorrow.fajr),
            tomorrowNight: night(tomorrow.maghrib, at(2, 4, 12)),
            hijri: [],
            fasting: [],
            loggedStatusByPrayerRaw: [:],
            jamaahByPrayerRaw: [:],
            isPaused: false,
            pauseExpectedEnd: nil
        ))
    }

    @MainActor
    func testWidgetLogRoundTripReachesTheSnapshot() async throws {
        _ = try await makeContext()
        seedSnapshot()

        _ = try await LogPrayerIntent(prayer: .asr).perform()

        let snapshot = try XCTUnwrap(WidgetSnapshotStore.read())
        XCTAssertEqual(
            snapshot.loggedStatusByPrayerRaw[Prayer.asr.rawValue],
            PrayerStatus.onTime.rawValue,
            "The widget button's log must reach the snapshot before the next render"
        )
        // Nothing else moved.
        XCTAssertEqual(snapshot.loggedStatusByPrayerRaw.count, 1)
        XCTAssertFalse(snapshot.isPaused)
    }

    @MainActor
    func testMirrorWithoutASnapshotIsANoOpNotACrash() async throws {
        _ = try await makeContext()
        WidgetSnapshotStore.clear()

        _ = try await LogPrayerIntent(prayer: .maghrib).perform()

        XCTAssertNil(WidgetSnapshotStore.read())
    }
}
