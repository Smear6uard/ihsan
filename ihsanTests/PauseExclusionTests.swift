import Foundation
import IhsanCore
import Testing
@testable import ihsan

private var utc: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}

private func day(_ year: Int, _ month: Int, _ dayOfMonth: Int) -> Date {
    utc.date(from: DateComponents(year: year, month: month, day: dayOfMonth, hour: 12))!
}

@Suite("Pause exclusion from Path math")
struct PauseExclusionTests {
    /// A pause-covered day leaves every Path denominator: it is not an
    /// active day, contributes nothing possible, and derives no statuses.
    @Test
    func pausedDaysLeaveEveryDenominator() {
        let now = day(2026, 7, 20)
        let pause = PauseInterval(
            startDate: utc.startOfDay(for: day(2026, 7, 15)).addingTimeInterval(-1),
            endDate: day(2026, 7, 17),
            loggedTimeZoneIdentifier: "UTC"
        )

        let days = TrajectoryAggregator.buildDays(
            period: .sevenDays,
            logs: [],
            pauseIntervals: [pause],
            travelIntervals: [],
            cycleDate: now,
            calendar: utc
        )
        let aggregate = TrajectoryAggregator.aggregate(days: days, qadaLogs: [])

        let pausedDays = days.filter(\.isPaused)
        #expect(!pausedDays.isEmpty)
        #expect(aggregate.totalActiveDays == days.count - pausedDays.count)
        #expect(aggregate.totalPossible == aggregate.totalActiveDays * 5)
        #expect(aggregate.pausedDays == pausedDays.count)
        #expect(aggregate.missedCount == 0)
    }

    /// Paused days render as rests, not gaps: their completion fraction is
    /// nil (the dash glyph), never zero (a missed dot).
    @Test
    func pausedDaysDeriveNoMissedSignal() {
        let now = day(2026, 7, 20)
        let pause = PauseInterval(
            startDate: utc.startOfDay(for: day(2026, 7, 14)).addingTimeInterval(-1),
            endDate: nil,
            loggedTimeZoneIdentifier: "UTC"
        )

        let days = TrajectoryAggregator.buildDays(
            period: .sevenDays,
            logs: [],
            pauseIntervals: [pause],
            travelIntervals: [],
            cycleDate: now,
            calendar: utc
        )

        for pausedDay in days.filter(\.isPaused) {
            #expect(pausedDay.completionFraction == nil)
        }

        let aggregate = TrajectoryAggregator.aggregate(days: days, qadaLogs: [])
        #expect(aggregate.totalActiveDays == days.filter { !$0.isPaused }.count)
    }

    /// Logs on an active day still count normally alongside a pause
    /// elsewhere in the window — exclusion is per-day, not per-window.
    @Test
    func activeDaysKeepTheirCountsBesideAPause() {
        let now = day(2026, 7, 20)
        let pause = PauseInterval(
            startDate: utc.startOfDay(for: day(2026, 7, 15)).addingTimeInterval(-1),
            endDate: day(2026, 7, 16),
            loggedTimeZoneIdentifier: "UTC"
        )
        let log = PrayerLog(
            prayer: .fajr,
            prayerDate: utc.startOfDay(for: day(2026, 7, 18)),
            loggedTimeZoneIdentifier: "UTC",
            scheduledTime: day(2026, 7, 18),
            status: .onTime
        )

        let days = TrajectoryAggregator.buildDays(
            period: .sevenDays,
            logs: [log],
            pauseIntervals: [pause],
            travelIntervals: [],
            cycleDate: now,
            calendar: utc
        )
        let aggregate = TrajectoryAggregator.aggregate(days: days, qadaLogs: [])

        #expect(aggregate.onTimeCount == 1)
        #expect(aggregate.perPrayer.first { $0.prayer == .fajr }?.onTimeCount == 1)
    }
}
