import Foundation
import IhsanCore
import IhsanLocation
import IhsanNotifications
import IhsanPrayerTimes
import SwiftData
import SwiftUI
import UserNotifications
#if canImport(AlarmKit)
import AlarmKit
import ActivityKit
#endif

/// Orchestrates the four wake anchors: computes each day's instants from
/// that day's own solar arithmetic, schedules each enabled anchor as a true
/// AlarmKit alarm where the user permits one, and falls back to a
/// time-sensitive notification otherwise — saying so plainly in Set.
///
/// No anchor schedules during an excused pause, every anchor recomputes
/// when the location moves the day, and each disappears entirely with its
/// own switch off.
@MainActor
final class WakeAnchorService {
    static let shared = WakeAnchorService()

    /// True when alarms are unavailable or declined and wakes will arrive
    /// as time-sensitive notifications. Set reads this for its plain note.
    private(set) var usesNotificationFallback = false

    private let provider = AdhanPrayerTimesProvider()
    private var notificationCoordinators: [WakeAnchor: WakeAnchorCoordinator] = [:]
    #if canImport(AlarmKit)
    private var alarmCoordinators: [WakeAnchor: WakeAnchorCoordinator] = [:]
    #endif

    private init() {
        for anchor in WakeAnchor.allCases {
            notificationCoordinators[anchor] = WakeAnchorCoordinator(
                anchor: anchor, client: NotificationWakeClient()
            )
            #if canImport(AlarmKit)
            alarmCoordinators[anchor] = WakeAnchorCoordinator(
                anchor: anchor, client: AlarmKitWakeClient()
            )
            #endif
        }
    }

    /// Asks for alarm permission when the state is still undetermined.
    /// Called from Set when the user turns an anchor on — the request
    /// belongs to that explicit choice, never to app launch.
    func requestAlarmAuthorizationIfNeeded() async {
        #if canImport(AlarmKit)
        if AlarmManager.shared.authorizationState == .notDetermined {
            _ = try? await AlarmManager.shared.requestAuthorization()
        }
        #endif
    }

    /// Recomputes and re-syncs every anchor from current state: settings,
    /// an active excused pause, and the most recent place. Callers:
    /// snapshot refreshes (foreground + significant location change), pause
    /// toggles, and the Set controls.
    func refresh(using modelContext: ModelContext) async {
        guard let settings = try? UserSettings.fetchOrCreate(in: modelContext) else {
            await syncAll(plans: [:])
            return
        }

        let pauseDescriptor = FetchDescriptor<PauseInterval>(
            predicate: #Predicate { $0.endDate == nil }
        )
        let isPaused = ((try? modelContext.fetch(pauseDescriptor))?.isEmpty == false)

        guard !isPaused,
              let place = CoreLocationCoordinator.shared.mostRecentResolvedPlace()
        else {
            await syncAll(plans: [:])
            return
        }

        let now = Date.now
        let days = candidateDays(now: now, place: place, settings: settings)

        var plans: [WakeAnchor: WakeAnchorPlan] = [:]
        for anchor in WakeAnchor.allCases {
            guard isAvailable(anchor, settings: settings) else { continue }
            if let plan = WakeAnchorPlanner.nextPlan(
                days: days,
                config: settings.wakeAnchorConfig(for: anchor),
                isPaused: false,
                now: now
            ) {
                plans[anchor] = plan
            }
        }
        await syncAll(plans: plans)
    }

    /// The last third keeps the gate it has always had: it belongs to the
    /// night-prayer layer, and someone who never turned that layer on has
    /// not asked to be woken for it. The other three are peers of their own
    /// and depend on nothing but their own switch.
    private func isAvailable(_ anchor: WakeAnchor, settings: UserSettings) -> Bool {
        switch anchor {
        case .lastThird:
            settings.sunnahLayerEnabled && settings.sunnahNightEnabled
        case .fajrStart, .sunrise, .maghrib:
            true
        }
    }

    /// Yesterday, today, and tomorrow, in firing order.
    ///
    /// Each day's four instants are gathered so they fall on the same civil
    /// day: the last third that precedes a given dawn belongs to the night
    /// that began the evening before, so it is read from that night.
    private func candidateDays(
        now: Date,
        place: LocatedPlace,
        settings: UserSettings
    ) -> [WakeEvents] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = place.timeZone

        func events(for date: Date) -> WakeEvents? {
            guard
                let day = try? provider.dayTimes(
                    for: date,
                    coordinates: place.coordinates,
                    timeZone: place.timeZone,
                    calculationMethod: settings.calculationMethod,
                    madhab: settings.madhab,
                    highLatitudeRule: settings.highLatitudeRule,
                    tuning: settings.calculationTuning
                ),
                let previousEvening = calendar.date(byAdding: .day, value: -1, to: date),
                let night = try? provider.nightIntervals(
                    for: previousEvening,
                    coordinates: place.coordinates,
                    timeZone: place.timeZone,
                    calculationMethod: settings.calculationMethod,
                    madhab: settings.madhab,
                    highLatitudeRule: settings.highLatitudeRule,
                    tuning: settings.calculationTuning
                )
            else {
                return nil
            }

            return WakeEvents(
                lastThirdStart: night.lastThirdStart,
                fajrStart: day.fajr.scheduledTime,
                sunrise: day.sunrise,
                maghrib: day.maghrib.scheduledTime
            )
        }

        return (0...2).compactMap { offset in
            calendar.date(byAdding: .day, value: offset - 1, to: now).flatMap(events)
        }
    }

    /// Routes each anchor's plan to whichever channel the user's
    /// permissions allow, and withdraws any wake standing on the other
    /// channel so exactly one — or none — exists per anchor.
    private func syncAll(plans: [WakeAnchor: WakeAnchorPlan]) async {
        #if canImport(AlarmKit)
        let alarmAuthorized = AlarmManager.shared.authorizationState == .authorized
        usesNotificationFallback = !alarmAuthorized
        for anchor in WakeAnchor.allCases {
            if alarmAuthorized {
                await notificationCoordinators[anchor]?.sync(to: nil)
                await alarmCoordinators[anchor]?.sync(to: plans[anchor])
            } else {
                await alarmCoordinators[anchor]?.sync(to: nil)
                await notificationCoordinators[anchor]?.sync(to: plans[anchor])
            }
        }
        #else
        usesNotificationFallback = true
        for anchor in WakeAnchor.allCases {
            await notificationCoordinators[anchor]?.sync(to: plans[anchor])
        }
        #endif
    }
}

// MARK: - What each anchor says when it arrives

/// One line per anchor, naming the moment rather than instructing the
/// person. The last third keeps the words it has always had.
enum WakeAnchorCopy {
    nonisolated static func alertTitle(for anchor: WakeAnchor) -> String {
        switch anchor {
        case .lastThird: "The last third of the night"
        case .fajrStart: "Fajr begins soon"
        case .sunrise: "Fajr's window is closing"
        case .maghrib: "Maghrib"
        }
    }

    nonisolated static func notificationBody(for anchor: WakeAnchor) -> String {
        switch anchor {
        case .lastThird: "The night's quietest hour has begun."
        case .fajrStart: "Suhoor ends when Fajr begins."
        case .sunrise: "Fajr's window closes at sunrise."
        case .maghrib: "The fast opens at Maghrib."
        }
    }

    nonisolated static func stopButtonTitle(for anchor: WakeAnchor) -> String {
        anchor == .lastThird ? "Rise" : "Stop"
    }

    nonisolated static func stopButtonImage(for anchor: WakeAnchor) -> String {
        switch anchor {
        case .lastThird, .fajrStart: "moon.stars"
        case .sunrise: "sunrise"
        case .maghrib: "sunset"
        }
    }
}

// MARK: - AlarmKit client

#if canImport(AlarmKit)
/// A true user-scheduled alarm at the wake instant — the route that can
/// actually wake someone. One stable identifier per anchor, so there is
/// never more than one standing wake for any of them.
struct AlarmKitWakeClient: WakeAnchorScheduling {
    struct Metadata: AlarmMetadata {}

    func scheduleWake(anchor: WakeAnchor, at date: Date) async throws {
        let attributes = AlarmAttributes<Metadata>(
            presentation: AlarmPresentation(
                alert: AlarmPresentation.Alert(
                    title: LocalizedStringResource(
                        stringLiteral: WakeAnchorCopy.alertTitle(for: anchor)
                    ),
                    stopButton: AlarmButton(
                        text: LocalizedStringResource(
                            stringLiteral: WakeAnchorCopy.stopButtonTitle(for: anchor)
                        ),
                        textColor: .white,
                        systemImageName: WakeAnchorCopy.stopButtonImage(for: anchor)
                    )
                )
            ),
            tintColor: Color(red: 0.788, green: 0.663, blue: 0.416)
        )
        let configuration = AlarmManager.AlarmConfiguration.alarm(
            schedule: .fixed(date),
            attributes: attributes,
            sound: .named(WakeSound.assetName(for: anchor))
        )
        _ = try await AlarmManager.shared.schedule(
            id: WakeAlarmIdentity.alarmID(for: anchor),
            configuration: configuration
        )
    }

    func cancelWake(anchor: WakeAnchor) async {
        try? AlarmManager.shared.cancel(id: WakeAlarmIdentity.alarmID(for: anchor))
    }
}
#endif

// MARK: - Notification fallback

/// Where alarms are unavailable or declined: a time-sensitive notification
/// with the same soft tone. Identifiers sit outside the `ihsan.prayer.`
/// prefix so schedule rebuilds never sweep one away.
struct NotificationWakeClient: WakeAnchorScheduling {
    func scheduleWake(anchor: WakeAnchor, at date: Date) async throws {
        let content = UNMutableNotificationContent()
        content.title = WakeAnchorCopy.alertTitle(for: anchor)
        content.body = WakeAnchorCopy.notificationBody(for: anchor)
        content.interruptionLevel = .timeSensitive
        content.sound = UNNotificationSound(
            named: UNNotificationSoundName(WakeSound.assetName(for: anchor))
        )

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
        let request = UNNotificationRequest(
            identifier: WakeAlarmIdentity.notificationIdentifier(for: anchor),
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
        try await UNUserNotificationCenter.current().add(request)
    }

    func cancelWake(anchor: WakeAnchor) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [WakeAlarmIdentity.notificationIdentifier(for: anchor)]
        )
    }
}
