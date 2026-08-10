import Foundation
import IhsanCore
import IhsanPrayerTimes

/// One day's four anchor instants, already computed.
///
/// Absolute instants, every one. That is why nothing in this file does
/// local-time arithmetic and why DST needs no special case: a clock shift
/// inside the span cannot move a fire time relative to its anchor.
public struct WakeEvents: Sendable, Equatable {
    public let lastThirdStart: Date
    public let fajrStart: Date
    public let sunrise: Date
    public let maghrib: Date

    public init(lastThirdStart: Date, fajrStart: Date, sunrise: Date, maghrib: Date) {
        self.lastThirdStart = lastThirdStart
        self.fajrStart = fajrStart
        self.sunrise = sunrise
        self.maghrib = maghrib
    }

    public func instant(for anchor: WakeAnchor) -> Date {
        switch anchor {
        case .lastThird: lastThirdStart
        case .fajrStart: fajrStart
        case .sunrise: sunrise
        case .maghrib: maghrib
        }
    }
}

/// One planned wake: an absolute instant, and which anchor asked for it.
public struct WakeAnchorPlan: Sendable, Equatable {
    public let anchor: WakeAnchor
    public let fireDate: Date

    public init(anchor: WakeAnchor, fireDate: Date) {
        self.anchor = anchor
        self.fireDate = fireDate
    }
}

/// Decides whether — and when — each anchor fires.
///
/// Pure arithmetic on the day the caller computed, so every day's wake is
/// that day's own computation and never a fixed clock time. Wakes are
/// strictly opt-in and never schedule during an excused pause: rest is
/// rest, and nothing rings through it.
public enum WakeAnchorPlanner {

    /// The wake for one anchor on one day, or nil when it must not
    /// schedule: disabled, paused, or that day's moment already behind us.
    public static func plan(
        events: WakeEvents,
        config: WakeAnchorConfig,
        isPaused: Bool,
        now: Date
    ) -> WakeAnchorPlan? {
        guard config.isEnabled, !isPaused else { return nil }

        let fireDate = events
            .instant(for: config.anchor)
            .addingTimeInterval(TimeInterval(-config.offsetMinutes * 60))
        guard fireDate > now else { return nil }
        return WakeAnchorPlan(anchor: config.anchor, fireDate: fireDate)
    }

    /// The first still-future wake across the given days, in order.
    public static func nextPlan(
        days: [WakeEvents],
        config: WakeAnchorConfig,
        isPaused: Bool,
        now: Date
    ) -> WakeAnchorPlan? {
        for day in days {
            if let plan = plan(events: day, config: config, isPaused: isPaused, now: now) {
                return plan
            }
        }
        return nil
    }
}

/// Stable identities, one per anchor.
///
/// This is what forecloses the double-fire class: a recomputation
/// cancels and reschedules exactly one alarm, because each anchor owns
/// one identifier for the life of the app. Regenerating these would
/// orphan alarms already standing on someone's device, so they are
/// literals and must stay literals.
public enum WakeAlarmIdentity {
    public static func alarmID(for anchor: WakeAnchor) -> UUID {
        switch anchor {
        case .lastThird: UUID(uuidString: "5A1A7E00-1A57-4213-9A0D-000000000001")!
        case .fajrStart: UUID(uuidString: "5A1A7E00-1A57-4213-9A0D-000000000002")!
        case .sunrise:   UUID(uuidString: "5A1A7E00-1A57-4213-9A0D-000000000003")!
        case .maghrib:   UUID(uuidString: "5A1A7E00-1A57-4213-9A0D-000000000004")!
        }
    }

    /// Outside the `ihsan.prayer.` prefix so a schedule rebuild never
    /// sweeps a wake away. The last third keeps the identifier it has
    /// always had, so an upgrade does not strand one already pending.
    public static func notificationIdentifier(for anchor: WakeAnchor) -> String {
        switch anchor {
        case .lastThird: "ihsan.nightwake"
        default: "ihsan.wake.\(anchor.rawValue)"
        }
    }
}

/// What the coordinator drives: one standing wake per anchor, scheduled or
/// cancelled. The app supplies an AlarmKit-backed client, falling back to a
/// time-sensitive notification where alarms are unavailable or declined.
public protocol WakeAnchorScheduling: Sendable {
    func scheduleWake(anchor: WakeAnchor, at date: Date) async throws
    func cancelWake(anchor: WakeAnchor) async
}

/// Keeps one anchor's standing wake in step with its current plan:
/// schedules a fresh plan, withdraws it when the plan disappears (pause,
/// disable), reschedules when the day moves (location change), and leaves
/// an unchanged plan alone.
public actor WakeAnchorCoordinator {
    private let anchor: WakeAnchor
    private let client: any WakeAnchorScheduling
    private var currentFireDate: Date?

    public init(anchor: WakeAnchor, client: any WakeAnchorScheduling) {
        self.anchor = anchor
        self.client = client
    }

    public var scheduledFireDate: Date? {
        currentFireDate
    }

    public func sync(to plan: WakeAnchorPlan?) async {
        guard let plan else {
            if currentFireDate != nil {
                await client.cancelWake(anchor: anchor)
                currentFireDate = nil
            }
            return
        }

        // An unchanged plan is left alone: a refresh that computes the
        // same instant must not churn a standing alarm.
        if plan.fireDate == currentFireDate { return }

        if currentFireDate != nil {
            await client.cancelWake(anchor: anchor)
        }
        do {
            try await client.scheduleWake(anchor: anchor, at: plan.fireDate)
            currentFireDate = plan.fireDate
        } catch {
            currentFireDate = nil
        }
    }
}
