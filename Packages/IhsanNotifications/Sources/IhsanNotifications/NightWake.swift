import Foundation
import IhsanPrayerTimes

/// One planned wake: an absolute instant inside a specific night.
public struct NightWakePlan: Sendable, Equatable {
    public let fireDate: Date

    public init(fireDate: Date) {
        self.fireDate = fireDate
    }
}

/// Decides whether — and when — the gentle wake fires. Pure arithmetic on
/// the night the caller computed, so each night's wake is that night's own
/// computation, never a fixed clock time.
///
/// The wake is strictly opt-in and never schedules during an excused
/// pause: rest is rest, and nothing rings through it.
public enum NightWakePlanner {

    /// The wake for one night, or nil when it must not schedule:
    /// disabled, paused, or that night's moment already behind us.
    public static func plan(
        night: NightIntervals,
        offsetMinutes: Int,
        isEnabled: Bool,
        isPaused: Bool,
        now: Date
    ) -> NightWakePlan? {
        guard isEnabled, !isPaused else { return nil }

        let fireDate = night.lastThirdStart.addingTimeInterval(TimeInterval(-offsetMinutes * 60))
        guard fireDate > now else { return nil }
        return NightWakePlan(fireDate: fireDate)
    }

    /// The first still-future wake across the given nights (typically
    /// tonight and tomorrow night, in order).
    public static func nextWake(
        nights: [NightIntervals],
        offsetMinutes: Int,
        isEnabled: Bool,
        isPaused: Bool,
        now: Date
    ) -> NightWakePlan? {
        for night in nights {
            if let plan = plan(
                night: night,
                offsetMinutes: offsetMinutes,
                isEnabled: isEnabled,
                isPaused: isPaused,
                now: now
            ) {
                return plan
            }
        }
        return nil
    }
}

/// What the coordinator drives: one standing wake, scheduled or cancelled.
/// The app supplies an AlarmKit-backed client, falling back to a
/// time-sensitive notification where alarms are unavailable or declined.
public protocol NightWakeScheduling: Sendable {
    func scheduleWake(at date: Date) async throws
    func cancelWake() async
}

/// Keeps the standing wake in step with the current plan: schedules a
/// fresh plan, withdraws it when the plan disappears (pause, disable),
/// reschedules when the night moves (location change), and leaves an
/// unchanged plan alone.
public actor NightWakeCoordinator {
    private let client: any NightWakeScheduling
    private var currentFireDate: Date?

    public init(client: any NightWakeScheduling) {
        self.client = client
    }

    public var scheduledFireDate: Date? {
        currentFireDate
    }

    public func sync(to plan: NightWakePlan?) async {
        guard let plan else {
            if currentFireDate != nil {
                await client.cancelWake()
                currentFireDate = nil
            }
            return
        }

        if plan.fireDate == currentFireDate { return }

        if currentFireDate != nil {
            await client.cancelWake()
        }
        do {
            try await client.scheduleWake(at: plan.fireDate)
            currentFireDate = plan.fireDate
        } catch {
            currentFireDate = nil
        }
    }
}
