#if canImport(ActivityKit) && os(iOS)
import Foundation
import IhsanCore
import IhsanNotifications
import IhsanPrayerTimes
import Testing
@testable import ihsan

@Test
func startActivityCreatesPreAdhanLiveActivity() async throws {
    let scheduledTime = Date(timeIntervalSince1970: 1_800_000)
    let windowEnd = scheduledTime.addingTimeInterval(2 * 3_600)
    let client = MockPrayerActivityClient()
    let scheduler = PrayerActivityScheduler(
        client: client,
        now: { scheduledTime.addingTimeInterval(-LiveActivityWindow.preAdhanLead + 60) },
        sleep: { _ in throw CancellationError() },
        calendar: Calendar(identifier: .gregorian)
    )

    let activityId = try await scheduler.startActivity(
        for: PrayerTime(prayer: .asr, scheduledTime: scheduledTime),
        in: makeDayPrayerTimes(scheduledTime: scheduledTime),
        windowEnd: windowEnd
    )

    #expect(activityId == "activity-1")
    #expect(client.requests.count == 1)
    #expect(client.requests.first?.attributes.prayer == .asr)
    #expect(client.requests.first?.attributes.windowEnd == windowEnd)
    #expect(client.requests.first?.staleDate == windowEnd)
    #expect(client.requests.first?.state.countdownPhase == .preAdhan)
    #expect(client.requests.first?.state.hasBeenLoggedThisActivity == false)
}

/// The Live Activity is the only surface in the app allowed a lead
/// time, and it is thirty minutes. Pinned here because the value has
/// drifted before: two private copies of the constant lived in two
/// modules, both at an hour.
@Test
func theLiveActivityAppearsExactlyThirtyMinutesAheadAndNotSooner() async throws {
    #expect(LiveActivityWindow.preAdhanLead == 30 * 60)

    let scheduledTime = Date(timeIntervalSince1970: 1_800_000)
    let prayerTime = PrayerTime(prayer: .asr, scheduledTime: scheduledTime)
    let day = makeDayPrayerTimes(scheduledTime: scheduledTime)
    let windowEnd = scheduledTime.addingTimeInterval(2 * 3_600)

    func startedActivity(secondsBefore: TimeInterval) async throws -> String? {
        let client = MockPrayerActivityClient()
        let scheduler = PrayerActivityScheduler(
            client: client,
            now: { scheduledTime.addingTimeInterval(-secondsBefore) },
            sleep: { _ in throw CancellationError() },
            calendar: Calendar(identifier: .gregorian)
        )
        return try await scheduler.startActivity(
            for: prayerTime,
            in: day,
            windowEnd: windowEnd
        )
    }

    // A second inside the window opens it.
    #expect(try await startedActivity(secondsBefore: 30 * 60 - 1) != nil)
    // Exactly at the boundary opens it.
    #expect(try await startedActivity(secondsBefore: 30 * 60) != nil)
    // A minute earlier does not: an hour out, nothing on the lock
    // screen should be counting down to Asr yet.
    #expect(try await startedActivity(secondsBefore: 31 * 60) == nil)
    #expect(try await startedActivity(secondsBefore: 60 * 60) == nil)
}

/// The activity's lifetime is the resolver window captured in the
/// shared schedule snapshot. A long Isha window therefore remains
/// active beyond the old private thirty-minute timeout and closes at
/// next Fajr exactly.
@Test
func activityLifetimeUsesTheSharedWindowBoundary() async throws {
    let scheduledTime = Date(timeIntervalSince1970: 1_800_000)
    let nextFajr = scheduledTime.addingTimeInterval(7 * 3_600)
    let prayerTime = PrayerTime(prayer: .isha, scheduledTime: scheduledTime)
    let day = makeDayPrayerTimes(scheduledTime: scheduledTime)

    let activeClient = MockPrayerActivityClient()
    let activeScheduler = PrayerActivityScheduler(
        client: activeClient,
        now: { scheduledTime.addingTimeInterval(2 * 3_600) },
        sleep: { _ in throw CancellationError() }
    )
    #expect(try await activeScheduler.startActivity(
        for: prayerTime,
        in: day,
        windowEnd: nextFajr
    ) != nil)
    #expect(activeClient.requests.first?.state.countdownPhase == .adhanWindow)
    #expect(activeClient.requests.first?.staleDate == nextFajr)

    let closedClient = MockPrayerActivityClient()
    let closedScheduler = PrayerActivityScheduler(
        client: closedClient,
        now: { nextFajr },
        sleep: { _ in throw CancellationError() }
    )
    #expect(try await closedScheduler.startActivity(
        for: prayerTime,
        in: day,
        windowEnd: nextFajr
    ) == nil)
    #expect(closedClient.requests.isEmpty)
}

@Test
func updateToAdhanWindowPreservesLoggedFlag() async {
    let scheduledTime = Date(timeIntervalSince1970: 1_800_000)
    let client = MockPrayerActivityClient(activities: [
        makeSnapshot(
            id: "activity-1",
            prayer: .maghrib,
            scheduledTime: scheduledTime,
            state: PrayerActivityAttributes.ContentState(
                countdownPhase: .preAdhan,
                hasBeenLoggedThisActivity: true
            )
        )
    ])
    let scheduler = PrayerActivityScheduler(client: client)

    await scheduler.updateToAdhanWindow(activityId: "activity-1")

    #expect(client.updates.last?.activityId == "activity-1")
    #expect(client.updates.last?.state.countdownPhase == .adhanWindow)
    #expect(client.updates.last?.state.hasBeenLoggedThisActivity == true)
}

@Test
func loggedEndShowsConfirmationThenEndsWithDefaultDismissal() async {
    let scheduledTime = Date(timeIntervalSince1970: 1_800_000)
    let client = MockPrayerActivityClient(activities: [
        makeSnapshot(
            id: "activity-1",
            prayer: .fajr,
            scheduledTime: scheduledTime,
            state: PrayerActivityAttributes.ContentState(countdownPhase: .adhanWindow)
        )
    ])
    let scheduler = PrayerActivityScheduler(
        client: client,
        sleep: { _ in }
    )

    await scheduler.endActivity(activityId: "activity-1", reason: .logged)

    #expect(client.updates.last?.state.hasBeenLoggedThisActivity == true)
    #expect(client.updates.last?.state.countdownPhase == .postAdhan)
    #expect(client.ends.last?.activityId == "activity-1")
    #expect(client.ends.last?.dismissal == .default)
}

@Test
func timeoutEndDismissesImmediatelyWithoutConfirmation() async {
    let scheduledTime = Date(timeIntervalSince1970: 1_800_000)
    let originalState = PrayerActivityAttributes.ContentState(countdownPhase: .adhanWindow)
    let client = MockPrayerActivityClient(activities: [
        makeSnapshot(id: "activity-1", prayer: .isha, scheduledTime: scheduledTime, state: originalState)
    ])
    let scheduler = PrayerActivityScheduler(client: client)

    await scheduler.endActivity(activityId: "activity-1", reason: .timedOut)

    #expect(client.updates.isEmpty)
    #expect(client.ends.last?.state == originalState)
    #expect(client.ends.last?.dismissal == .immediate)
}

@Test
func excusedPauseCancellationEndsEveryActivePrayerActivity() async {
    let scheduledTime = Date(timeIntervalSince1970: 1_800_000)
    let client = MockPrayerActivityClient(activities: [
        makeSnapshot(
            id: "activity-1",
            prayer: .isha,
            scheduledTime: scheduledTime,
            state: PrayerActivityAttributes.ContentState(countdownPhase: .adhanWindow)
        )
    ])
    let scheduler = PrayerActivityScheduler(client: client)

    await scheduler.cancelAllPrayerActivities()

    #expect(await client.activeActivities().isEmpty)
    #expect(client.ends.last?.activityId == "activity-1")
    #expect(client.ends.last?.dismissal == .immediate)
}

private final class MockPrayerActivityClient: PrayerActivityClient, @unchecked Sendable {
    struct Request {
        let attributes: PrayerActivityAttributes
        let state: PrayerActivityAttributes.ContentState
        let staleDate: Date?
    }

    struct Update: Equatable {
        let activityId: String
        let state: PrayerActivityAttributes.ContentState
        let staleDate: Date?
    }

    struct End: Equatable {
        let activityId: String
        let state: PrayerActivityAttributes.ContentState?
        let dismissal: PrayerActivityDismissal
    }

    private var activities: [PrayerActivitySnapshot]
    private var recordedRequests: [Request] = []
    private var recordedUpdates: [Update] = []
    private var recordedEnds: [End] = []
    private let lock = NSLock()

    init(activities: [PrayerActivitySnapshot] = []) {
        self.activities = activities
    }

    var requests: [Request] { lock.withLock { recordedRequests } }
    var updates: [Update] { lock.withLock { recordedUpdates } }
    var ends: [End] { lock.withLock { recordedEnds } }

    func activeActivities() async -> [PrayerActivitySnapshot] {
        lock.withLock { activities }
    }

    func request(
        attributes: PrayerActivityAttributes,
        state: PrayerActivityAttributes.ContentState,
        staleDate: Date?
    ) async throws -> String {
        lock.withLock {
            let id = "activity-\(recordedRequests.count + 1)"
            recordedRequests.append(Request(attributes: attributes, state: state, staleDate: staleDate))
            activities.append(PrayerActivitySnapshot(id: id, attributes: attributes, state: state))
            return id
        }
    }

    func update(
        activityId: String,
        state: PrayerActivityAttributes.ContentState,
        staleDate: Date?
    ) async {
        lock.withLock {
            recordedUpdates.append(Update(activityId: activityId, state: state, staleDate: staleDate))
            if let index = activities.firstIndex(where: { $0.id == activityId }) {
                let current = activities[index]
                activities[index] = PrayerActivitySnapshot(
                    id: current.id,
                    attributes: current.attributes,
                    state: state
                )
            }
        }
    }

    func end(
        activityId: String,
        state: PrayerActivityAttributes.ContentState?,
        dismissal: PrayerActivityDismissal
    ) async {
        lock.withLock {
            recordedEnds.append(End(activityId: activityId, state: state, dismissal: dismissal))
            activities.removeAll { $0.id == activityId }
        }
    }
}

private func makeSnapshot(
    id: String,
    prayer: Prayer,
    scheduledTime: Date,
    state: PrayerActivityAttributes.ContentState
) -> PrayerActivitySnapshot {
    PrayerActivitySnapshot(
        id: id,
        attributes: PrayerActivityAttributes(
            prayer: prayer,
            scheduledTime: scheduledTime,
            windowEnd: scheduledTime.addingTimeInterval(6 * 3_600),
            timeZoneIdentifier: "America/Chicago",
            arabicName: prayer.displayNameArabic,
            englishName: prayer.displayNameEnglish
        ),
        state: state
    )
}

private func makeDayPrayerTimes(scheduledTime: Date) -> DayPrayerTimes {
    let dayStart = Calendar(identifier: .gregorian).startOfDay(for: scheduledTime)
    return DayPrayerTimes(
        date: dayStart,
        timeZoneIdentifier: TimeZone.current.identifier,
        coordinates: Coordinates(latitude: 41.8781, longitude: -87.6298),
        calculationMethod: .isna,
        madhab: .standard,
        highLatitudeRule: .middleOfNight,
        fajr: PrayerTime(prayer: .fajr, scheduledTime: dayStart.addingTimeInterval(5 * 3_600)),
        dhuhr: PrayerTime(prayer: .dhuhr, scheduledTime: dayStart.addingTimeInterval(12 * 3_600)),
        asr: PrayerTime(prayer: .asr, scheduledTime: scheduledTime),
        maghrib: PrayerTime(prayer: .maghrib, scheduledTime: dayStart.addingTimeInterval(19 * 3_600)),
        isha: PrayerTime(prayer: .isha, scheduledTime: dayStart.addingTimeInterval(21 * 3_600)),
        sunrise: dayStart.addingTimeInterval(6 * 3_600),
        middleOfTheNight: dayStart.addingTimeInterval(24 * 3_600),
        lastThirdOfTheNight: dayStart.addingTimeInterval(26 * 3_600)
    )
}
#endif
