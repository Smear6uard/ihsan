import Foundation
import IhsanCore
import IhsanPrayerTimes
import Testing
@testable import IhsanNotifications

@Suite("Wake anchors")
struct WakeAnchorTests {

    private static func zone(_ identifier: String) -> TimeZone {
        TimeZone(identifier: identifier)!
    }

    private static func instant(
        _ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int,
        in timeZone: TimeZone
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(
            from: DateComponents(
                year: year, month: month, day: day, hour: hour, minute: minute
            )
        )!
    }

    /// One ordinary day, built by hand so the arithmetic under test is the
    /// planner's and not the solar model's.
    private static func events(
        dayOffsetHours: Double = 0,
        base: Date = Date(timeIntervalSince1970: 1_780_000_000)
    ) -> WakeEvents {
        let shifted = base.addingTimeInterval(dayOffsetHours * 3_600)
        return WakeEvents(
            lastThirdStart: shifted.addingTimeInterval(2 * 3_600),
            fajrStart: shifted.addingTimeInterval(5 * 3_600),
            sunrise: shifted.addingTimeInterval(6 * 3_600),
            maghrib: shifted.addingTimeInterval(19 * 3_600)
        )
    }

    // MARK: - The identity

    /// The whole feature in one assertion: a wake fires exactly its offset
    /// before the moment it is anchored to, for every anchor and every
    /// offset. Anything else is a bug in the arithmetic.
    @Test("Every anchor fires exactly its offset before its own instant")
    func fireTimeIsTheEventMinusTheOffset() {
        let day = Self.events()
        let now = day.lastThirdStart.addingTimeInterval(-12 * 3_600)

        for anchor in WakeAnchor.allCases {
            for offset in [0, 1, 5, 15, 45, 90] {
                let plan = WakeAnchorPlanner.plan(
                    events: day,
                    config: WakeAnchorConfig(
                        anchor: anchor, isEnabled: true, offsetMinutes: offset
                    ),
                    isPaused: false,
                    now: now
                )

                #expect(
                    plan?.fireDate
                        == day.instant(for: anchor)
                            .addingTimeInterval(TimeInterval(-offset * 60))
                )
                #expect(plan?.anchor == anchor)
            }
        }
    }

    @Test("A disabled anchor plans nothing")
    func disabledAnchorPlansNothing() {
        let day = Self.events()
        for anchor in WakeAnchor.allCases {
            let plan = WakeAnchorPlanner.plan(
                events: day,
                config: WakeAnchorConfig(anchor: anchor, isEnabled: false, offsetMinutes: 10),
                isPaused: false,
                now: day.lastThirdStart.addingTimeInterval(-12 * 3_600)
            )
            #expect(plan == nil)
        }
    }

    /// Rest is rest, and nothing rings through it — every anchor, not just
    /// the one that existed first.
    @Test("A pause suppresses every anchor")
    func pauseSuppressesEveryAnchor() {
        let day = Self.events()
        for anchor in WakeAnchor.allCases {
            let plan = WakeAnchorPlanner.plan(
                events: day,
                config: WakeAnchorConfig(anchor: anchor, isEnabled: true, offsetMinutes: 10),
                isPaused: true,
                now: day.lastThirdStart.addingTimeInterval(-12 * 3_600)
            )
            #expect(plan == nil)
        }
    }

    @Test("A moment already behind us plans nothing")
    func aPastMomentPlansNothing() {
        let day = Self.events()
        let plan = WakeAnchorPlanner.plan(
            events: day,
            config: WakeAnchorConfig(anchor: .fajrStart, isEnabled: true, offsetMinutes: 0),
            isPaused: false,
            now: day.fajrStart.addingTimeInterval(60)
        )
        #expect(plan == nil)
    }

    @Test("The next day's instant is chosen once today's has passed")
    func rollsForwardToTheNextDay() {
        let today = Self.events()
        let tomorrow = Self.events(dayOffsetHours: 24)
        let now = today.fajrStart.addingTimeInterval(60)

        let plan = WakeAnchorPlanner.nextPlan(
            days: [today, tomorrow],
            config: WakeAnchorConfig(anchor: .fajrStart, isEnabled: true, offsetMinutes: 0),
            isPaused: false,
            now: now
        )

        #expect(plan?.fireDate == tomorrow.fajrStart)
    }

    // MARK: - DST

    /// The events are absolute instants, so a clock shift inside the span
    /// cannot move a fire time relative to its anchor. This test is what
    /// proves no local-time arithmetic crept into the planner.
    @Test("The identity holds across a spring-forward boundary")
    func identityHoldsAcrossSpringForward() {
        let chicago = Self.zone("America/Chicago")
        // 2026-03-08: clocks jump 02:00 -> 03:00 local.
        let day = WakeEvents(
            lastThirdStart: Self.instant(2026, 3, 8, 1, 30, in: chicago),
            fajrStart: Self.instant(2026, 3, 8, 5, 40, in: chicago),
            sunrise: Self.instant(2026, 3, 8, 7, 0, in: chicago),
            maghrib: Self.instant(2026, 3, 8, 18, 0, in: chicago)
        )
        let now = Self.instant(2026, 3, 7, 12, 0, in: chicago)

        for anchor in WakeAnchor.allCases {
            let plan = WakeAnchorPlanner.plan(
                events: day,
                config: WakeAnchorConfig(anchor: anchor, isEnabled: true, offsetMinutes: 30),
                isPaused: false,
                now: now
            )
            #expect(
                plan?.fireDate == day.instant(for: anchor).addingTimeInterval(-30 * 60)
            )
        }
    }

    @Test("The identity holds across a fall-back boundary")
    func identityHoldsAcrossFallBack() {
        let chicago = Self.zone("America/Chicago")
        // 2026-11-01: clocks fall 02:00 -> 01:00 local.
        let day = WakeEvents(
            lastThirdStart: Self.instant(2026, 11, 1, 3, 10, in: chicago),
            fajrStart: Self.instant(2026, 11, 1, 6, 0, in: chicago),
            sunrise: Self.instant(2026, 11, 1, 7, 20, in: chicago),
            maghrib: Self.instant(2026, 11, 1, 17, 50, in: chicago)
        )
        let now = Self.instant(2026, 10, 31, 12, 0, in: chicago)

        for anchor in WakeAnchor.allCases {
            let plan = WakeAnchorPlanner.plan(
                events: day,
                config: WakeAnchorConfig(anchor: anchor, isEnabled: true, offsetMinutes: 20),
                isPaused: false,
                now: now
            )
            #expect(
                plan?.fireDate == day.instant(for: anchor).addingTimeInterval(-20 * 60)
            )
        }
    }

    // MARK: - The coordinator

    @Test("Syncing a plan schedules it once")
    func syncSchedulesOnce() async {
        let client = MockWakeClient()
        let coordinator = WakeAnchorCoordinator(anchor: .fajrStart, client: client)
        let day = Self.events()

        await coordinator.sync(to: WakeAnchorPlan(anchor: .fajrStart, fireDate: day.fajrStart))

        #expect(await client.scheduled == [day.fajrStart])
        #expect(await client.cancelCount == 0)
    }

    /// A recomputation that changes nothing must not churn the alarm.
    @Test("Syncing the same plan twice schedules nothing further")
    func syncIsIdempotent() async {
        let client = MockWakeClient()
        let coordinator = WakeAnchorCoordinator(anchor: .fajrStart, client: client)
        let plan = WakeAnchorPlan(anchor: .fajrStart, fireDate: Self.events().fajrStart)

        await coordinator.sync(to: plan)
        await coordinator.sync(to: plan)

        #expect(await client.scheduled.count == 1)
        #expect(await client.cancelCount == 0)
    }

    /// Moving location moves the night. The old alarm is withdrawn before
    /// the new one is placed, so a shifted window can never leave two
    /// standing — this is the double-fire class, closed.
    @Test("A location change cancels before it reschedules, leaving exactly one")
    func aLocationChangeLeavesExactlyOneWake() async {
        let client = MockWakeClient()
        let coordinator = WakeAnchorCoordinator(anchor: .fajrStart, client: client)
        let here = Self.events()
        let elsewhere = Self.events(dayOffsetHours: 3)

        await coordinator.sync(to: WakeAnchorPlan(anchor: .fajrStart, fireDate: here.fajrStart))
        await coordinator.sync(
            to: WakeAnchorPlan(anchor: .fajrStart, fireDate: elsewhere.fajrStart)
        )

        #expect(await client.scheduled == [here.fajrStart, elsewhere.fajrStart])
        #expect(await client.cancelCount == 1)
        #expect(await coordinator.scheduledFireDate == elsewhere.fajrStart)
    }

    @Test("Syncing to nothing withdraws a standing wake")
    func syncingToNilWithdraws() async {
        let client = MockWakeClient()
        let coordinator = WakeAnchorCoordinator(anchor: .maghrib, client: client)
        await coordinator.sync(
            to: WakeAnchorPlan(anchor: .maghrib, fireDate: Self.events().maghrib)
        )

        await coordinator.sync(to: nil)

        #expect(await client.cancelCount == 1)
        #expect(await coordinator.scheduledFireDate == nil)
    }

    @Test("Each anchor carries its own stable alarm identity")
    func anchorsHaveDistinctStableIdentities() {
        let first = WakeAnchor.allCases.map { WakeAlarmIdentity.alarmID(for: $0) }
        let second = WakeAnchor.allCases.map { WakeAlarmIdentity.alarmID(for: $0) }

        #expect(Set(first).count == WakeAnchor.allCases.count)
        #expect(first == second)

        let identifiers = WakeAnchor.allCases.map {
            WakeAlarmIdentity.notificationIdentifier(for: $0)
        }
        #expect(Set(identifiers).count == WakeAnchor.allCases.count)
    }
}

/// Records what the scheduling layer was actually asked to do.
private actor MockWakeClient: WakeAnchorScheduling {
    private(set) var scheduled: [Date] = []
    private(set) var cancelCount = 0

    func scheduleWake(anchor: WakeAnchor, at date: Date) async throws {
        scheduled.append(date)
    }

    func cancelWake(anchor: WakeAnchor) async {
        cancelCount += 1
    }
}
