import Foundation
import IhsanPrayerTimes
import Testing
@testable import IhsanNotifications

private func makeNight(
    maghrib: TimeInterval = 700_000_000,
    span: TimeInterval = 9 * 3600
) throws -> NightIntervals {
    try NightIntervals(
        maghrib: Date(timeIntervalSinceReferenceDate: maghrib),
        nextFajr: Date(timeIntervalSinceReferenceDate: maghrib + span)
    )
}

// MARK: - Planner

@Test
func wakeFiresAtTheLastThirdsStartByDefault() throws {
    let night = try makeNight()
    let plan = NightWakePlanner.plan(
        night: night,
        offsetMinutes: 0,
        isEnabled: true,
        isPaused: false,
        now: night.start
    )

    #expect(plan?.fireDate == night.lastThirdStart)
}

@Test
func offsetMovesTheWakeEarlier() throws {
    let night = try makeNight()
    let plan = NightWakePlanner.plan(
        night: night,
        offsetMinutes: 20,
        isEnabled: true,
        isPaused: false,
        now: night.start
    )

    #expect(plan?.fireDate == night.lastThirdStart.addingTimeInterval(-20 * 60))
}

@Test
func excusedPauseNeverSchedules() throws {
    let night = try makeNight()
    let plan = NightWakePlanner.plan(
        night: night,
        offsetMinutes: 0,
        isEnabled: true,
        isPaused: true,
        now: night.start
    )

    #expect(plan == nil)
}

@Test
func disabledNeverSchedules() throws {
    let night = try makeNight()
    let plan = NightWakePlanner.plan(
        night: night,
        offsetMinutes: 0,
        isEnabled: false,
        isPaused: false,
        now: night.start
    )

    #expect(plan == nil)
}

@Test
func aWakeAlreadyPassedYieldsNil() throws {
    let night = try makeNight()
    let plan = NightWakePlanner.plan(
        night: night,
        offsetMinutes: 0,
        isEnabled: true,
        isPaused: false,
        now: night.lastThirdStart.addingTimeInterval(60)
    )

    #expect(plan == nil)
}

@Test
func nextWakePicksTonightThenFallsToTomorrow() throws {
    let tonight = try makeNight()
    let tomorrow = try makeNight(maghrib: 700_000_000 + 86_400)

    let early = NightWakePlanner.nextWake(
        nights: [tonight, tomorrow],
        offsetMinutes: 0,
        isEnabled: true,
        isPaused: false,
        now: tonight.start
    )
    #expect(early?.fireDate == tonight.lastThirdStart)

    let late = NightWakePlanner.nextWake(
        nights: [tonight, tomorrow],
        offsetMinutes: 0,
        isEnabled: true,
        isPaused: false,
        now: tonight.lastThirdStart.addingTimeInterval(300)
    )
    #expect(late?.fireDate == tomorrow.lastThirdStart)
}

@Test
func eachNightsWakeIsThatNightsComputation() throws {
    // A location change reshapes the night; the plan must follow the
    // night it is given, never a fixed clock time.
    let homeNight = try makeNight(span: 9 * 3600)
    let travelNight = try makeNight(span: 11 * 3600)

    let home = NightWakePlanner.plan(
        night: homeNight, offsetMinutes: 0, isEnabled: true, isPaused: false, now: homeNight.start
    )
    let travel = NightWakePlanner.plan(
        night: travelNight, offsetMinutes: 0, isEnabled: true, isPaused: false, now: travelNight.start
    )

    #expect(home?.fireDate != travel?.fireDate)
    #expect(travel?.fireDate == travelNight.lastThirdStart)
}

// MARK: - Coordinator

private actor RecordingWakeClient: NightWakeScheduling {
    private(set) var scheduledDates: [Date] = []
    private(set) var cancelCount = 0

    func scheduleWake(at date: Date) async throws {
        scheduledDates.append(date)
    }

    func cancelWake() async {
        cancelCount += 1
    }

    func snapshot() -> (dates: [Date], cancels: Int) {
        (scheduledDates, cancelCount)
    }
}

@Test
func coordinatorSchedulesAFreshPlan() async throws {
    let client = RecordingWakeClient()
    let coordinator = NightWakeCoordinator(client: client)
    let night = try makeNight()

    await coordinator.sync(to: NightWakePlan(fireDate: night.lastThirdStart))

    let recorded = await client.snapshot()
    #expect(recorded.dates == [night.lastThirdStart])
}

@Test
func coordinatorCancelsWhenThePlanDisappears() async throws {
    // The pause path: an excused pause yields a nil plan, and any
    // standing wake must be withdrawn.
    let client = RecordingWakeClient()
    let coordinator = NightWakeCoordinator(client: client)
    let night = try makeNight()

    await coordinator.sync(to: NightWakePlan(fireDate: night.lastThirdStart))
    await coordinator.sync(to: nil)

    let recorded = await client.snapshot()
    #expect(recorded.dates.count == 1)
    #expect(recorded.cancels >= 1)
}

@Test
func coordinatorReschedulesWhenTheNightMoves() async throws {
    // The location path: new coordinates → new night → new fire date.
    let client = RecordingWakeClient()
    let coordinator = NightWakeCoordinator(client: client)
    let homeNight = try makeNight(span: 9 * 3600)
    let travelNight = try makeNight(span: 11 * 3600)

    await coordinator.sync(to: NightWakePlan(fireDate: homeNight.lastThirdStart))
    await coordinator.sync(to: NightWakePlan(fireDate: travelNight.lastThirdStart))

    let recorded = await client.snapshot()
    #expect(recorded.dates == [homeNight.lastThirdStart, travelNight.lastThirdStart])
    #expect(recorded.cancels >= 1)
}

@Test
func coordinatorLeavesAnUnchangedPlanAlone() async throws {
    let client = RecordingWakeClient()
    let coordinator = NightWakeCoordinator(client: client)
    let night = try makeNight()

    await coordinator.sync(to: NightWakePlan(fireDate: night.lastThirdStart))
    await coordinator.sync(to: NightWakePlan(fireDate: night.lastThirdStart))

    let recorded = await client.snapshot()
    #expect(recorded.dates.count == 1)
    #expect(recorded.cancels == 0)
}
