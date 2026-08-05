import Foundation
import IhsanCore
import IhsanPrayerTimes
import Testing
@testable import ihsan

/// Tests the exact composition path consumed by Today: shared resolver
/// -> selected prayer instance -> card phase / marker state / sheet
/// availability. This closes the gap where package properties passed
/// while a view rebuilt temporal state independently.
@Suite("Prayer resolver UI integration")
@MainActor
struct PrayerStateResolverIntegrationTests {
    private let chicago = TimeZone(identifier: "America/Chicago")!

    private struct UISurfaceState {
        let resolution: PrayerResolution
        let windowState: PrayerWindowState
        let cardPhase: FocusedCardModel.Phase
        let availableStatuses: Set<PrayerStatus>

        var markerIsCurrent: Bool { windowState.isCurrent }
    }

    private func uiState(
        prayerTime: PrayerTime,
        schedule: PrayerStateSchedule,
        now: Date
    ) throws -> UISurfaceState {
        let resolution = PrayerStateResolver.resolve(prayerTimes: schedule, now: now)
        let windowState = try #require(resolution.state(for: prayerTime))
        return UISurfaceState(
            resolution: resolution,
            windowState: windowState,
            cardPhase: FocusedCardModel.resolve(
                windowState: windowState,
                isLogged: false
            ),
            availableStatuses: TimingAvailability.allowedStatuses(
                now: now,
                dayBeingLogged: now,
                windowState: windowState,
                currentStatus: nil,
                calendar: calendar(in: schedule.timeZoneIdentifier)
            )
        )
    }

    // MARK: - Both edges, at the level the UI consumes

    @Test
    func everyPrayerFlipsAtItsExactStartAndEnd() throws {
        let schedule = reproducedSchedule()
        let instances: [(PrayerTime, Date)] = [
            (schedule.fajr, schedule.sunrise),
            (schedule.dhuhr, schedule.asr.scheduledTime),
            (schedule.asr, schedule.maghrib.scheduledTime),
            (schedule.maghrib, schedule.isha.scheduledTime),
            (schedule.isha, schedule.tomorrowFajr.scheduledTime)
        ]

        for (prayerTime, end) in instances {
            // Property sweep: every sampled instant before the exact
            // start is upcoming on the card, non-current on the plate,
            // and unavailable in the log sheet.
            for secondsBefore in stride(from: 1, through: 6 * 3600, by: 137) {
                let before = try uiState(
                    prayerTime: prayerTime,
                    schedule: schedule,
                    now: prayerTime.scheduledTime.addingTimeInterval(-Double(secondsBefore))
                )
                #expect(before.resolution.currentPrayer != prayerTime)
                #expect(before.cardPhase == .upcoming(opensAt: prayerTime.scheduledTime))
                #expect(!before.markerIsCurrent)
                #expect(before.availableStatuses.isEmpty)
            }

            let atStart = try uiState(
                prayerTime: prayerTime,
                schedule: schedule,
                now: prayerTime.scheduledTime
            )
            #expect(atStart.resolution.currentPrayer == prayerTime)
            #expect(atStart.cardPhase == .active(until: end))
            #expect(atStart.markerIsCurrent)
            #expect(atStart.availableStatuses == [.onTime, .late])

            let beforeEnd = try uiState(
                prayerTime: prayerTime,
                schedule: schedule,
                now: end.addingTimeInterval(-1)
            )
            #expect(beforeEnd.resolution.currentPrayer == prayerTime)
            #expect(beforeEnd.cardPhase == .active(until: end))
            #expect(beforeEnd.markerIsCurrent)

            let atEnd = try uiState(
                prayerTime: prayerTime,
                schedule: schedule,
                now: end
            )
            #expect(atEnd.resolution.currentPrayer != prayerTime)
            #expect(atEnd.cardPhase == .windowClosed(at: end))
            #expect(!atEnd.markerIsCurrent)
            #expect(atEnd.availableStatuses == [.onTime, .late, .qada, .missed])
        }
    }

    // MARK: - Reproduced cases, pinned verbatim

    @Test("12:36 PM, Dhuhr starts 1:03 PM — Dhuhr is not current")
    func dhuhrTwentySevenMinutesEarlyRegression() throws {
        let schedule = reproducedSchedule()
        let now = date(2026, 7, 30, 12, 36, in: chicago)
        let state = try uiState(prayerTime: schedule.dhuhr, schedule: schedule, now: now)

        #expect(schedule.dhuhr.scheduledTime == date(2026, 7, 30, 13, 3, in: chicago))
        #expect(schedule.asr.scheduledTime == date(2026, 7, 30, 16, 57, in: chicago))
        #expect(state.resolution.currentPrayer == nil)
        #expect(state.resolution.nextPrayer == schedule.dhuhr)
        #expect(state.cardPhase == .upcoming(opensAt: schedule.dhuhr.scheduledTime))
        #expect(!state.markerIsCurrent)
    }

    @Test("9:22 PM, Isha starts 9:44 PM — Isha is not current")
    func ishaTwentyTwoMinutesEarlyRegression() throws {
        let schedule = reproducedSchedule()
        let now = date(2026, 7, 30, 21, 22, in: chicago)
        let state = try uiState(prayerTime: schedule.isha, schedule: schedule, now: now)

        #expect(schedule.isha.scheduledTime == date(2026, 7, 30, 21, 44, in: chicago))
        #expect(state.resolution.currentPrayer == schedule.maghrib)
        #expect(state.resolution.nextPrayer == schedule.isha)
        #expect(state.cardPhase == .upcoming(opensAt: schedule.isha.scheduledTime))
        #expect(!state.markerIsCurrent)
    }

    @Test("5:31 AM, Fajr ends 5:51 AM — Fajr remains current")
    func fajrExitTwentyMinutesEarlyRegression() throws {
        let schedule = reproducedSchedule()
        let now = date(2026, 7, 30, 5, 31, in: chicago)
        let state = try uiState(prayerTime: schedule.fajr, schedule: schedule, now: now)

        #expect(schedule.sunrise == date(2026, 7, 30, 5, 51, in: chicago))
        #expect(state.resolution.currentPrayer == schedule.fajr)
        #expect(state.cardPhase == .active(until: schedule.sunrise))
        #expect(state.markerIsCurrent)
        #expect(state.availableStatuses == [.onTime, .late])
    }

    // MARK: - Countdown instant arithmetic

    @Test("Countdown target is prayer.start across spring-forward DST")
    func countdownAcrossDSTUsesExactInstants() {
        let newYork = TimeZone(identifier: "America/New_York")!
        let now = date(2026, 3, 8, 1, 30, in: newYork)
        let start = date(2026, 3, 8, 3, 30, in: newYork)
        let schedule = scheduleWithNextFajr(
            now: now,
            fajr: start,
            timeZone: newYork
        )
        let resolution = PrayerStateResolver.resolve(prayerTimes: schedule, now: now)

        #expect(resolution.nextPrayer == schedule.fajr)
        #expect(resolution.countdownTarget == start)
        #expect(resolution.countdownTarget.timeIntervalSince(now) == 3_600)
    }

    @Test("Countdown is independent of the device's local timezone")
    func countdownInNonLocalTimezoneUsesExactInstants() {
        let karachi = TimeZone(identifier: "Asia/Karachi")!
        let now = date(2026, 7, 30, 12, 36, in: karachi)
        let start = date(2026, 7, 30, 13, 3, in: karachi)
        let schedule = scheduleWithNextFajr(now: now, fajr: start, timeZone: karachi)
        let resolution = PrayerStateResolver.resolve(prayerTimes: schedule, now: now)

        #expect(resolution.countdownTarget == start)
        #expect(resolution.countdownTarget.timeIntervalSince(now) == 27 * 60)
    }

    private func reproducedSchedule() -> PrayerStateSchedule {
        PrayerStateSchedule(
            yesterdayIsha: PrayerTime(
                prayer: .isha,
                scheduledTime: date(2026, 7, 29, 21, 45, in: chicago)
            ),
            fajr: PrayerTime(
                prayer: .fajr,
                scheduledTime: date(2026, 7, 30, 4, 16, in: chicago)
            ),
            sunrise: date(2026, 7, 30, 5, 51, in: chicago),
            dhuhr: PrayerTime(
                prayer: .dhuhr,
                scheduledTime: date(2026, 7, 30, 13, 3, in: chicago)
            ),
            asr: PrayerTime(
                prayer: .asr,
                scheduledTime: date(2026, 7, 30, 16, 57, in: chicago)
            ),
            maghrib: PrayerTime(
                prayer: .maghrib,
                scheduledTime: date(2026, 7, 30, 20, 12, in: chicago)
            ),
            isha: PrayerTime(
                prayer: .isha,
                scheduledTime: date(2026, 7, 30, 21, 44, in: chicago)
            ),
            tomorrowFajr: PrayerTime(
                prayer: .fajr,
                scheduledTime: date(2026, 7, 31, 4, 17, in: chicago)
            ),
            timeZoneIdentifier: chicago.identifier
        )
    }

    private func scheduleWithNextFajr(
        now: Date,
        fajr: Date,
        timeZone: TimeZone
    ) -> PrayerStateSchedule {
        PrayerStateSchedule(
            yesterdayIsha: PrayerTime(prayer: .isha, scheduledTime: now.addingTimeInterval(-4 * 3600)),
            fajr: PrayerTime(prayer: .fajr, scheduledTime: fajr),
            sunrise: fajr.addingTimeInterval(90 * 60),
            dhuhr: PrayerTime(prayer: .dhuhr, scheduledTime: fajr.addingTimeInterval(7 * 3600)),
            asr: PrayerTime(prayer: .asr, scheduledTime: fajr.addingTimeInterval(11 * 3600)),
            maghrib: PrayerTime(prayer: .maghrib, scheduledTime: fajr.addingTimeInterval(15 * 3600)),
            isha: PrayerTime(prayer: .isha, scheduledTime: fajr.addingTimeInterval(16.5 * 3600)),
            tomorrowFajr: PrayerTime(prayer: .fajr, scheduledTime: fajr.addingTimeInterval(24 * 3600)),
            timeZoneIdentifier: timeZone.identifier
        )
    }

    private func calendar(in identifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier) ?? .current
        return calendar
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        _ minute: Int,
        in timeZone: TimeZone
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }
}
