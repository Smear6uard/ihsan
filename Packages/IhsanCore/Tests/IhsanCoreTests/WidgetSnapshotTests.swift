import Foundation
import Testing
@testable import IhsanCore

/// The widget data spine's contract: a snapshot survives its
/// round-trip exactly, stales on the 36-hour rule and at its terminal
/// boundary, resolves its stamps by civil day in the place timezone,
/// and the store rejects payloads it does not understand rather than
/// letting a widget render a guess.
@Suite("Widget snapshot spine")
struct WidgetSnapshotTests {

    // MARK: - Fixture

    /// The repo's canonical gallery day — Chicago, 2026-07-30.
    static let timeZone = TimeZone(identifier: "America/Chicago")!

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    static func at(day: Int, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(
            year: 2026, month: 7, day: day, hour: hour, minute: minute
        ))!
    }

    static func makeSnapshot(
        writtenAt: Date = at(day: 30, 5, 0),
        loggedStatusByPrayerRaw: [String: String] = [:],
        isPaused: Bool = false
    ) -> WidgetSnapshot {
        let today = WidgetSnapshot.DayTable(
            civilDayStart: at(day: 30, 0, 0),
            fajr: at(day: 30, 4, 10),
            sunrise: at(day: 30, 5, 42),
            dhuhr: at(day: 30, 12, 58),
            asr: at(day: 30, 16, 53),
            maghrib: at(day: 30, 20, 11),
            isha: at(day: 30, 21, 43)
        )
        let tomorrow = WidgetSnapshot.DayTable(
            civilDayStart: at(day: 31, 0, 0),
            fajr: at(day: 31, 4, 11),
            sunrise: at(day: 31, 5, 43),
            dhuhr: at(day: 31, 12, 58),
            asr: at(day: 31, 16, 52),
            maghrib: at(day: 31, 20, 10),
            isha: at(day: 31, 21, 41)
        )
        let dayAfterFajr = at(day: 1 + 31, 4, 12) // Aug 1 via day overflow
        func night(from maghrib: Date, to fajr: Date) -> WidgetSnapshot.NightTable {
            let span = fajr.timeIntervalSince(maghrib)
            return WidgetSnapshot.NightTable(
                start: maghrib,
                end: fajr,
                nisfAlLayl: maghrib.addingTimeInterval(span / 2),
                lastThirdStart: maghrib.addingTimeInterval(span * 2 / 3)
            )
        }
        return WidgetSnapshot(
            writtenAt: writtenAt,
            timeZoneIdentifier: timeZone.identifier,
            cityName: "Chicago",
            qiblaBearingDegrees: 48.5,
            yesterdayIsha: at(day: 29, 21, 44),
            today: today,
            tomorrow: tomorrow,
            dayAfterTomorrowFajr: dayAfterFajr,
            tonight: night(from: today.maghrib, to: tomorrow.fajr),
            tomorrowNight: night(from: tomorrow.maghrib, to: dayAfterFajr),
            hijri: [
                WidgetSnapshot.HijriStamp(
                    civilDayStart: today.civilDayStart,
                    day: 13,
                    monthName: "Safar",
                    year: 1448,
                    significantLine: "White day · Safar 13",
                    isRamadan: false
                ),
                WidgetSnapshot.HijriStamp(
                    civilDayStart: tomorrow.civilDayStart,
                    day: 14,
                    monthName: "Safar",
                    year: 1448,
                    significantLine: "White day · Safar 14",
                    isRamadan: false
                ),
            ],
            fasting: [
                WidgetSnapshot.FastingStamp(
                    civilDayStart: today.civilDayStart, isFasting: true, isRamadan: false
                ),
                WidgetSnapshot.FastingStamp(
                    civilDayStart: tomorrow.civilDayStart, isFasting: false, isRamadan: false
                ),
            ],
            loggedStatusByPrayerRaw: loggedStatusByPrayerRaw,
            jamaahByPrayerRaw: [:],
            isPaused: isPaused,
            pauseExpectedEnd: nil
        )
    }

    // MARK: - Round-trip

    @Test
    func roundTripPreservesEveryField() throws {
        let snapshot = Self.makeSnapshot(
            loggedStatusByPrayerRaw: [
                Prayer.fajr.rawValue: PrayerStatus.onTime.rawValue,
                Prayer.dhuhr.rawValue: PrayerStatus.late.rawValue,
            ]
        )
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(WidgetSnapshot.self, from: data)
        // Decoded VALUES, never encoded strings — JSONEncoder key
        // order is process-unstable in this repo's history.
        #expect(decoded == snapshot)
    }

    // MARK: - Freshness

    @Test
    func freshWithinCoverageAndAge() {
        let snapshot = Self.makeSnapshot()
        #expect(snapshot.freshness(at: Self.at(day: 30, 12, 0)) == .fresh)
        #expect(snapshot.freshness(at: Self.at(day: 31, 12, 0)) == .fresh)
    }

    @Test
    func staleBeyondThirtySixHours() {
        let snapshot = Self.makeSnapshot(writtenAt: Self.at(day: 30, 5, 0))
        let justInside = Self.at(day: 30, 5, 0).addingTimeInterval(WidgetSnapshot.maximumAge - 1)
        let justBeyond = Self.at(day: 30, 5, 0).addingTimeInterval(WidgetSnapshot.maximumAge + 1)
        #expect(snapshot.freshness(at: justInside) == .fresh)
        #expect(snapshot.freshness(at: justBeyond) == .stale)
    }

    @Test
    func staleAtTerminalFajrEvenWhenYoung() {
        // Written late, so age alone would still be fresh at the
        // terminal boundary — coverage must stale it independently.
        let snapshot = Self.makeSnapshot(writtenAt: Self.at(day: 31, 23, 0))
        let terminal = snapshot.dayAfterTomorrowFajr
        #expect(snapshot.freshness(at: terminal.addingTimeInterval(-1)) == .fresh)
        #expect(snapshot.freshness(at: terminal) == .stale)
    }

    @Test
    func staleWhenClockMovesBehindItsDay() {
        let snapshot = Self.makeSnapshot()
        #expect(snapshot.freshness(at: Self.at(day: 29, 12, 0)) == .stale)
    }

    // MARK: - Brackets and stamps

    @Test
    func dayTableBracketsFollowTomorrowFajrNotMidnight() {
        let snapshot = Self.makeSnapshot(writtenAt: Self.at(day: 30, 22, 0))
        // 1 am on the 31st still belongs to the 30th's bracket —
        // Isha's window runs to tomorrow's Fajr.
        #expect(snapshot.dayTable(containing: Self.at(day: 31, 1, 0)) == snapshot.today)
        // After tomorrow's Fajr the bracket flips.
        #expect(snapshot.dayTable(containing: Self.at(day: 31, 4, 30)) == snapshot.tomorrow)
    }

    @Test
    func nightContainmentIsHalfOpenAtFajr() {
        let snapshot = Self.makeSnapshot()
        #expect(snapshot.night(containing: Self.at(day: 30, 23, 0)) == snapshot.tonight)
        #expect(snapshot.night(containing: snapshot.tonight.end) == nil)
        #expect(snapshot.night(containing: Self.at(day: 31, 12, 0)) == nil)
        #expect(snapshot.night(containing: Self.at(day: 31, 21, 0)) == snapshot.tomorrowNight)
    }

    @Test
    func stampsResolveByCivilDayInPlaceTimeZone() {
        let snapshot = Self.makeSnapshot()
        #expect(snapshot.hijriStamp(at: Self.at(day: 30, 23, 59))?.day == 13)
        #expect(snapshot.hijriStamp(at: Self.at(day: 31, 0, 1))?.day == 14)
        #expect(snapshot.fastingStamp(at: Self.at(day: 30, 12, 0))?.isFasting == true)
        #expect(snapshot.fastingStamp(at: Self.at(day: 31, 12, 0))?.isFasting == false)
    }

    // MARK: - Store

    /// A unique suite per test — Swift Testing runs these in
    /// parallel, and a shared name lets one test read another's write.
    private func scratchDefaults() throws -> UserDefaults {
        let name = "ihsan-widget-snapshot-tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test
    func storeRoundTrips() throws {
        let defaults = try scratchDefaults()
        let snapshot = Self.makeSnapshot()
        WidgetSnapshotStore.write(snapshot, defaults: defaults)
        #expect(WidgetSnapshotStore.read(defaults: defaults) == snapshot)
        WidgetSnapshotStore.clear(defaults: defaults)
        #expect(WidgetSnapshotStore.read(defaults: defaults) == nil)
    }

    @Test
    func storeRejectsForeignSchemaVersions() throws {
        let defaults = try scratchDefaults()
        let snapshot = Self.makeSnapshot()
        let foreign = WidgetSnapshot(
            schemaVersion: WidgetSnapshot.currentSchemaVersion + 1,
            writtenAt: snapshot.writtenAt,
            timeZoneIdentifier: snapshot.timeZoneIdentifier,
            cityName: snapshot.cityName,
            qiblaBearingDegrees: snapshot.qiblaBearingDegrees,
            yesterdayIsha: snapshot.yesterdayIsha,
            today: snapshot.today,
            tomorrow: snapshot.tomorrow,
            dayAfterTomorrowFajr: snapshot.dayAfterTomorrowFajr,
            tonight: snapshot.tonight,
            tomorrowNight: snapshot.tomorrowNight,
            hijri: snapshot.hijri,
            fasting: snapshot.fasting,
            loggedStatusByPrayerRaw: [:],
            jamaahByPrayerRaw: [:],
            isPaused: false,
            pauseExpectedEnd: nil
        )
        WidgetSnapshotStore.write(foreign, defaults: defaults)
        #expect(WidgetSnapshotStore.read(defaults: defaults) == nil)
    }

    @Test
    func storeRejectsUndecodablePayloads() throws {
        let defaults = try scratchDefaults()
        defaults.set(Data("not a snapshot".utf8), forKey: WidgetSnapshotStore.key)
        #expect(WidgetSnapshotStore.read(defaults: defaults) == nil)
    }

    @Test
    func mirrorLogsReplacesTodaysStatesInPlace() throws {
        let defaults = try scratchDefaults()
        WidgetSnapshotStore.write(Self.makeSnapshot(), defaults: defaults)
        WidgetSnapshotStore.mirrorLogs(
            loggedStatusByPrayerRaw: [Prayer.asr.rawValue: PrayerStatus.onTime.rawValue],
            jamaahByPrayerRaw: [Prayer.asr.rawValue: true],
            defaults: defaults
        )
        let read = try #require(WidgetSnapshotStore.read(defaults: defaults))
        #expect(read.loggedStatusByPrayerRaw == [Prayer.asr.rawValue: PrayerStatus.onTime.rawValue])
        #expect(read.jamaahByPrayerRaw == [Prayer.asr.rawValue: true])
        // Everything else survives untouched.
        #expect(read.today == Self.makeSnapshot().today)
        #expect(read.writtenAt == Self.makeSnapshot().writtenAt)
    }

    // MARK: - The countdown trap (D1)

    /// The blank-widget crash, pinned: an inverted `ClosedRange` traps
    /// the render process, so the interval builder must be total.
    @Test
    func countdownIntervalNeverInverts() {
        let entry = Self.at(day: 30, 12, 0)
        let passed = Self.at(day: 30, 4, 10)
        let clamped = WidgetTimerInterval.countdown(from: entry, to: passed)
        #expect(clamped == entry...entry)

        let future = Self.at(day: 30, 16, 53)
        #expect(WidgetTimerInterval.countdown(from: entry, to: future) == entry...future)
    }
}

// MARK: - The relevant night

extension WidgetSnapshotTests {
    /// The night a face speaks about: in progress wins, otherwise the
    /// one ahead — tonight through the day, tomorrow night late in
    /// day two.
    @Test
    func relevantNightIsInProgressOrAhead() {
        let snapshot = Self.makeSnapshot(writtenAt: Self.at(day: 30, 22, 0))
        // Mid-afternoon: tonight lies ahead.
        #expect(snapshot.relevantNight(at: Self.at(day: 30, 15, 0)) == snapshot.tonight)
        // In the night: the night in progress.
        #expect(snapshot.relevantNight(at: Self.at(day: 30, 23, 0)) == snapshot.tonight)
        #expect(snapshot.relevantNight(at: Self.at(day: 31, 2, 0)) == snapshot.tonight)
        // Day two afternoon: tomorrow night.
        #expect(snapshot.relevantNight(at: Self.at(day: 31, 15, 0)) == snapshot.tomorrowNight)
        #expect(snapshot.relevantNight(at: Self.at(day: 31, 22, 0)) == snapshot.tomorrowNight)
    }
}
