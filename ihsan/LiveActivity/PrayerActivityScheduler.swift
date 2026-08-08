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
        in dayTimes: DayPrayerTimes,
        windowEnd: Date
    ) async throws -> String? {
        guard !Self.isDebugFixtureCapture else { return nil }
        let currentDate = now()
        let scheduledTime = prayerTime.scheduledTime
        guard currentDate < windowEnd else {
            logger.info("Skipping \(prayerTime.prayer.rawValue) activity because its resolver window has closed.")
            return nil
        }

        guard currentDate >= scheduledTime.addingTimeInterval(-LiveActivityWindow.preAdhanLead) else {
            logger.info("Skipping \(prayerTime.prayer.rawValue) activity because its pre-adhan window has not started.")
            return nil
        }

        if let existing = await matchingActivity(
            for: prayerTime.prayer,
            scheduledTime: scheduledTime,
            windowEnd: windowEnd
        ) {
            await updateExistingActivity(existing)
            scheduleLocalTransitions(
                activityId: existing.id,
                scheduledTime: scheduledTime,
                windowEnd: windowEnd
            )
            return existing.id
        }

        await endOverlappingActivityIfNeeded(for: prayerTime, scheduledTime: scheduledTime)

        let attributes = PrayerActivityAttributes(
            prayer: prayerTime.prayer,
            scheduledTime: scheduledTime,
            windowEnd: windowEnd,
            timeZoneIdentifier: dayTimes.timeZoneIdentifier,
            arabicName: prayerTime.prayer.displayNameArabic,
            englishName: prayerTime.prayer.displayNameEnglish
        )
        let state = PrayerActivityAttributes.ContentState(
            countdownPhase: phase(
                for: scheduledTime,
                windowEnd: windowEnd,
                at: currentDate
            ),
            hasBeenLoggedThisActivity: false
        )
        let staleDate = windowEnd
        let activityId = try await client.request(attributes: attributes, state: state, staleDate: staleDate)
        scheduleLocalTransitions(
            activityId: activityId,
            scheduledTime: scheduledTime,
            windowEnd: windowEnd
        )
        logger.info("Started \(prayerTime.prayer.rawValue) Live Activity \(activityId, privacy: .public).")
        return activityId
    }

    public func schedulePrayerActivityStart(
        for prayerTime: PrayerTime,
        in dayTimes: DayPrayerTimes,
        windowEnd: Date,
        startDate: Date
    ) async throws {
        guard !Self.isDebugFixtureCapture else { return }
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
                        windowEnd: windowEnd,
                        taskKey: taskKey
                    )
                } catch {
                    self.clearScheduledStartTask(taskKey)
                }
            }
            return
        }
        _ = try await startActivity(for: prayerTime, in: dayTimes, windowEnd: windowEnd)
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
            staleDate: snapshot.attributes.windowEnd
        )
    }

    public func cancelAllPrayerActivities() async {
        guard !Self.isDebugFixtureCapture else { return }
        scheduledStartTasks.values.forEach { $0.cancel() }
        scheduledStartTasks.removeAll()
        transitionTasks.values.forEach { $0.cancel() }
        transitionTasks.removeAll()

        for activity in await client.activeActivities() {
            await client.end(
                activityId: activity.id,
                state: activity.state,
                dismissal: .immediate
            )
        }
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
            countdownPhase: phase(
                for: snapshot.attributes.scheduledTime,
                windowEnd: snapshot.attributes.windowEnd,
                at: now()
            ),
            hasBeenLoggedThisActivity: snapshot.state.hasBeenLoggedThisActivity
        )
        await client.update(
            activityId: snapshot.id,
            state: state,
            staleDate: snapshot.attributes.windowEnd
        )
    }

    private func startScheduledActivity(
        for prayerTime: PrayerTime,
        in dayTimes: DayPrayerTimes,
        windowEnd: Date,
        taskKey: String
    ) async throws {
        scheduledStartTasks[taskKey] = nil
        _ = try await startActivity(for: prayerTime, in: dayTimes, windowEnd: windowEnd)
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

    private func matchingActivity(
        for prayer: Prayer,
        scheduledTime: Date,
        windowEnd: Date
    ) async -> PrayerActivitySnapshot? {
        await client.activeActivities().first {
            $0.attributes.prayer == prayer &&
            abs($0.attributes.scheduledTime.timeIntervalSince(scheduledTime)) < 1 &&
            abs($0.attributes.windowEnd.timeIntervalSince(windowEnd)) < 1
        }
    }

    private func startTaskKey(for prayerTime: PrayerTime) -> String {
        "\(prayerTime.prayer.rawValue)-\(Int(prayerTime.scheduledTime.timeIntervalSince1970))"
    }

    private func snapshot(activityId: String) async -> PrayerActivitySnapshot? {
        await client.activeActivities().first { $0.id == activityId }
    }

    private func scheduleLocalTransitions(
        activityId: String,
        scheduledTime: Date,
        windowEnd: Date
    ) {
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

            let afterAdhanDate = now()
            guard windowEnd > afterAdhanDate else {
                await self.endActivity(activityId: activityId, reason: .timedOut)
                return
            }

            do {
                try await sleep(Self.duration(for: windowEnd.timeIntervalSince(afterAdhanDate)))
                await self.endActivity(activityId: activityId, reason: .timedOut)
            } catch {
                return
            }
        }
    }

    private func phase(
        for scheduledTime: Date,
        windowEnd: Date,
        at date: Date
    ) -> PrayerActivityAttributes.CountdownPhase {
        if date < scheduledTime {
            return .preAdhan
        }
        if date < windowEnd {
            return .adhanWindow
        }
        return .postAdhan
    }

    private static func duration(for seconds: TimeInterval) -> Duration {
        .milliseconds(Int64(max(0, seconds) * 1_000))
    }

    /// The screenshot fixture owns ActivityKit while its explicit debug
    /// launch argument is present. Ordinary schedule rebuilds can race a
    /// cold launch, so suppressing them here keeps the system captures
    /// deterministic without changing release behavior.
    private static var isDebugFixtureCapture: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-IhsanDebugLiveActivity")
        #else
        false
        #endif
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
