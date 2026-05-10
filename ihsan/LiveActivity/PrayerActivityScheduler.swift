#if canImport(ActivityKit) && os(iOS)
import ActivityKit
import Foundation
import IhsanCore
import IhsanNotifications
import IhsanPrayerTimes
import OSLog

nonisolated public enum PrayerActivityEndReason: Sendable {
    case logged
    case timedOut
    case dismissed
    case replaced
}

nonisolated struct PrayerActivitySnapshot: Equatable, Sendable {
    let id: String
    let attributes: PrayerActivityAttributes
    let state: PrayerActivityAttributes.ContentState
}

nonisolated protocol PrayerActivityClient: Sendable {
    func activeActivities() async -> [PrayerActivitySnapshot]
    func request(
        attributes: PrayerActivityAttributes,
        state: PrayerActivityAttributes.ContentState,
        staleDate: Date?
    ) async throws -> String
    func update(
        activityId: String,
        state: PrayerActivityAttributes.ContentState,
        staleDate: Date?
    ) async
    func end(
        activityId: String,
        state: PrayerActivityAttributes.ContentState?,
        dismissal: PrayerActivityDismissal
    ) async
}

nonisolated enum PrayerActivityDismissal: Equatable, Sendable {
    case immediate
    case `default`
}

public actor PrayerActivityScheduler: PrayerActivityScheduling {
    public static let shared = PrayerActivityScheduler()

    private static let preAdhanLeadTime: TimeInterval = 60 * 60
    private static let postAdhanLifetime: TimeInterval = 30 * 60
    private static let loggedConfirmationDuration: TimeInterval = 5

    private let client: any PrayerActivityClient
    private let now: @Sendable () -> Date
    private let sleep: @Sendable (Duration) async throws -> Void
    private let calendar: Calendar
    private let logger = Logger(subsystem: "com.sameerstudios.ihsan", category: "PrayerActivityScheduler")

    private var scheduledStartTasks: [String: Task<Void, Never>] = [:]
    private var transitionTasks: [String: Task<Void, Never>] = [:]

    public init() {
        self.init(client: SystemPrayerActivityClient())
    }

    init(
        client: any PrayerActivityClient,
        now: @escaping @Sendable () -> Date = { Date() },
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        calendar: Calendar = .current
    ) {
        self.client = client
        self.now = now
        self.sleep = sleep
        self.calendar = calendar
    }

    @discardableResult
    public func startActivity(
        for prayerTime: PrayerTime,
        in dayTimes: DayPrayerTimes
    ) async throws -> String? {
        let currentDate = now()
        let scheduledTime = prayerTime.scheduledTime
        guard currentDate < scheduledTime.addingTimeInterval(Self.postAdhanLifetime) else {
            logger.info("Skipping \(prayerTime.prayer.rawValue) activity because its post-adhan window has passed.")
            return nil
        }

        guard currentDate >= scheduledTime.addingTimeInterval(-Self.preAdhanLeadTime) else {
            logger.info("Skipping \(prayerTime.prayer.rawValue) activity because its pre-adhan window has not started.")
            return nil
        }

        if let existing = await matchingActivity(for: prayerTime.prayer, scheduledTime: scheduledTime) {
            await updateExistingActivity(existing)
            scheduleLocalTransitions(activityId: existing.id, scheduledTime: scheduledTime)
            return existing.id
        }

        await endOverlappingActivityIfNeeded(for: prayerTime, scheduledTime: scheduledTime)

        let attributes = PrayerActivityAttributes(
            prayer: prayerTime.prayer,
            scheduledTime: scheduledTime,
            arabicName: prayerTime.prayer.displayNameArabic,
            englishName: prayerTime.prayer.displayNameEnglish
        )
        let state = PrayerActivityAttributes.ContentState(
            countdownPhase: phase(for: scheduledTime, at: currentDate),
            hasBeenLoggedThisActivity: false
        )
        let staleDate = scheduledTime.addingTimeInterval(Self.postAdhanLifetime)
        let activityId = try await client.request(attributes: attributes, state: state, staleDate: staleDate)
        scheduleLocalTransitions(activityId: activityId, scheduledTime: scheduledTime)
        logger.info("Started \(prayerTime.prayer.rawValue) Live Activity \(activityId, privacy: .public).")
        _ = dayTimes
        return activityId
    }

    public func schedulePrayerActivityStart(
        for prayerTime: PrayerTime,
        in dayTimes: DayPrayerTimes,
        startDate: Date
    ) async throws {
        let currentDate = now()
        let taskKey = startTaskKey(for: prayerTime)

        guard currentDate >= startDate else {
            if scheduledStartTasks[taskKey] != nil {
                return
            }

            scheduledStartTasks[taskKey] = Task { [sleep] in
                do {
                    try await sleep(Self.duration(for: startDate.timeIntervalSince(currentDate)))
                    try await self.startScheduledActivity(
                        for: prayerTime,
                        in: dayTimes,
                        taskKey: taskKey
                    )
                } catch {
                    await self.clearScheduledStartTask(taskKey)
                }
            }
            return
        }
        _ = try await startActivity(for: prayerTime, in: dayTimes)
    }

    public func updateToAdhanWindow(activityId: String) async {
        guard let snapshot = await snapshot(activityId: activityId) else {
            return
        }

        let state = PrayerActivityAttributes.ContentState(
            countdownPhase: .adhanWindow,
            hasBeenLoggedThisActivity: snapshot.state.hasBeenLoggedThisActivity
        )
        await client.update(
            activityId: activityId,
            state: state,
            staleDate: snapshot.attributes.scheduledTime.addingTimeInterval(Self.postAdhanLifetime)
        )
    }

    public func endActivity(activityId: String, reason: PrayerActivityEndReason) async {
        transitionTasks[activityId]?.cancel()
        transitionTasks[activityId] = nil

        guard let snapshot = await snapshot(activityId: activityId) else {
            return
        }

        switch reason {
        case .logged:
            let loggedState = PrayerActivityAttributes.ContentState(
                countdownPhase: .postAdhan,
                hasBeenLoggedThisActivity: true
            )
            await client.update(activityId: activityId, state: loggedState, staleDate: nil)
            do {
                try await sleep(Self.duration(for: Self.loggedConfirmationDuration))
            } catch {
                return
            }
            await client.end(activityId: activityId, state: loggedState, dismissal: .default)
        case .timedOut:
            await client.end(activityId: activityId, state: snapshot.state, dismissal: .immediate)
        case .dismissed, .replaced:
            await client.end(activityId: activityId, state: snapshot.state, dismissal: .immediate)
        }
    }

    public func endActivity(
        for prayer: Prayer,
        on prayerDate: Date,
        reason: PrayerActivityEndReason
    ) async {
        let activities = await client.activeActivities()
        for activity in activities where activity.attributes.prayer == prayer {
            if calendar.isDate(activity.attributes.scheduledTime, inSameDayAs: prayerDate) {
                await endActivity(activityId: activity.id, reason: reason)
            }
        }
    }

    private func updateExistingActivity(_ snapshot: PrayerActivitySnapshot) async {
        let state = PrayerActivityAttributes.ContentState(
            countdownPhase: phase(for: snapshot.attributes.scheduledTime, at: now()),
            hasBeenLoggedThisActivity: snapshot.state.hasBeenLoggedThisActivity
        )
        await client.update(
            activityId: snapshot.id,
            state: state,
            staleDate: snapshot.attributes.scheduledTime.addingTimeInterval(Self.postAdhanLifetime)
        )
    }

    private func startScheduledActivity(
        for prayerTime: PrayerTime,
        in dayTimes: DayPrayerTimes,
        taskKey: String
    ) async throws {
        scheduledStartTasks[taskKey] = nil
        _ = try await startActivity(for: prayerTime, in: dayTimes)
    }

    private func clearScheduledStartTask(_ taskKey: String) {
        scheduledStartTasks[taskKey] = nil
    }

    private func endOverlappingActivityIfNeeded(for prayerTime: PrayerTime, scheduledTime: Date) async {
        let activities = await client.activeActivities()
        for activity in activities where
            activity.attributes.prayer == prayerTime.prayer &&
            calendar.isDate(activity.attributes.scheduledTime, inSameDayAs: scheduledTime)
        {
            await endActivity(activityId: activity.id, reason: .replaced)
        }
    }

    private func matchingActivity(for prayer: Prayer, scheduledTime: Date) async -> PrayerActivitySnapshot? {
        await client.activeActivities().first {
            $0.attributes.prayer == prayer &&
            abs($0.attributes.scheduledTime.timeIntervalSince(scheduledTime)) < 1
        }
    }

    private func startTaskKey(for prayerTime: PrayerTime) -> String {
        "\(prayerTime.prayer.rawValue)-\(Int(prayerTime.scheduledTime.timeIntervalSince1970))"
    }

    private func snapshot(activityId: String) async -> PrayerActivitySnapshot? {
        await client.activeActivities().first { $0.id == activityId }
    }

    private func scheduleLocalTransitions(activityId: String, scheduledTime: Date) {
        transitionTasks[activityId]?.cancel()

        transitionTasks[activityId] = Task { [now, sleep] in
            let currentDate = now()
            if scheduledTime > currentDate {
                do {
                    try await sleep(Self.duration(for: scheduledTime.timeIntervalSince(currentDate)))
                    await self.updateToAdhanWindow(activityId: activityId)
                } catch {
                    return
                }
            } else {
                await self.updateToAdhanWindow(activityId: activityId)
            }

            let timeoutDate = scheduledTime.addingTimeInterval(Self.postAdhanLifetime)
            let afterAdhanDate = now()
            guard timeoutDate > afterAdhanDate else {
                await self.endActivity(activityId: activityId, reason: .timedOut)
                return
            }

            do {
                try await sleep(Self.duration(for: timeoutDate.timeIntervalSince(afterAdhanDate)))
                await self.endActivity(activityId: activityId, reason: .timedOut)
            } catch {
                return
            }
        }
    }

    private func phase(for scheduledTime: Date, at date: Date) -> PrayerActivityAttributes.CountdownPhase {
        if date < scheduledTime {
            return .preAdhan
        }
        if date < scheduledTime.addingTimeInterval(Self.postAdhanLifetime) {
            return .adhanWindow
        }
        return .postAdhan
    }

    private static func duration(for seconds: TimeInterval) -> Duration {
        .milliseconds(Int64(max(0, seconds) * 1_000))
    }
}

nonisolated struct SystemPrayerActivityClient: PrayerActivityClient {
    func activeActivities() async -> [PrayerActivitySnapshot] {
        Activity<PrayerActivityAttributes>.activities.map {
            PrayerActivitySnapshot(
                id: $0.id,
                attributes: $0.attributes,
                state: $0.content.state
            )
        }
    }

    func request(
        attributes: PrayerActivityAttributes,
        state: PrayerActivityAttributes.ContentState,
        staleDate: Date?
    ) async throws -> String {
        let activity = try Activity.request(
            attributes: attributes,
            content: ActivityContent(state: state, staleDate: staleDate),
            pushType: nil
        )
        return activity.id
    }

    func update(
        activityId: String,
        state: PrayerActivityAttributes.ContentState,
        staleDate: Date?
    ) async {
        guard let activity = Activity<PrayerActivityAttributes>.activities.first(where: { $0.id == activityId }) else {
            return
        }
        await activity.update(ActivityContent(state: state, staleDate: staleDate))
    }

    func end(
        activityId: String,
        state: PrayerActivityAttributes.ContentState?,
        dismissal: PrayerActivityDismissal
    ) async {
        guard let activity = Activity<PrayerActivityAttributes>.activities.first(where: { $0.id == activityId }) else {
            return
        }

        let policy: ActivityUIDismissalPolicy = switch dismissal {
        case .immediate:
            .immediate
        case .default:
            .default
        }

        if let state {
            await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: policy)
        } else {
            await activity.end(nil, dismissalPolicy: policy)
        }
    }
}
#endif
