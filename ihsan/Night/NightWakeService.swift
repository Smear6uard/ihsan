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

/// The wake tone is the app's chime — one tone, one constant, named in
/// `AdhanAsset`. The wake and the prayer notification cannot drift
/// apart, and replacing the placeholder replaces both.
enum NightWakeSound {
    static var assetName: String { AdhanAsset.nightWake }
}

/// Orchestrates the gentle wake: computes each night's plan from that
/// night's own span, schedules it as a true AlarmKit alarm where the user
/// permits one, and falls back to a time-sensitive notification otherwise
/// — saying so plainly in Set.
///
/// The wake never schedules during an excused pause, recomputes when the
/// location moves the night, and disappears entirely with the layer off.
@MainActor
final class NightWakeService {
    static let shared = NightWakeService()

    /// True when alarms are unavailable or declined and the wake will
    /// arrive as a time-sensitive notification. Set reads this for its
    /// plain-spoken note.
    private(set) var usesNotificationFallback = false

    private let provider = AdhanPrayerTimesProvider()
    private let notificationCoordinator = NightWakeCoordinator(client: NotificationWakeClient())
    #if canImport(AlarmKit)
    private let alarmCoordinator = NightWakeCoordinator(client: AlarmKitWakeClient())
    #endif

    private init() {}

    /// Asks for alarm permission when the state is still undetermined.
    /// Called from Set when the user turns the wake on — the request
    /// belongs to that explicit choice, never to app launch.
    func requestAlarmAuthorizationIfNeeded() async {
        #if canImport(AlarmKit)
        if AlarmManager.shared.authorizationState == .notDetermined {
            _ = try? await AlarmManager.shared.requestAuthorization()
        }
        #endif
    }

    /// Recomputes and re-syncs the standing wake from current state:
    /// settings, an active excused pause, and the most recent place.
    /// Callers: snapshot refreshes (foreground + significant location
    /// change), pause toggles, and the Set controls.
    func refresh(using modelContext: ModelContext) async {
        guard let settings = try? UserSettings.fetchOrCreate(in: modelContext) else {
            await sync(plan: nil)
            return
        }

        let enabled = settings.sunnahLayerEnabled
            && settings.sunnahNightEnabled
            && settings.nightWakeEnabled

        let pauseDescriptor = FetchDescriptor<PauseInterval>(
            predicate: #Predicate { $0.endDate == nil }
        )
        let isPaused = ((try? modelContext.fetch(pauseDescriptor))?.isEmpty == false)

        guard enabled, !isPaused,
              let place = CoreLocationCoordinator.shared.mostRecentResolvedPlace()
        else {
            await sync(plan: nil)
            return
        }

        let now = Date.now
        let plan = NightWakePlanner.nextWake(
            nights: candidateNights(now: now, place: place, settings: settings),
            offsetMinutes: settings.nightWakeOffsetMinutes,
            isEnabled: true,
            isPaused: false,
            now: now
        )
        await sync(plan: plan)
    }

    /// Tonight's night (which may have started yesterday evening) and
    /// tomorrow's, in firing order.
    private func candidateNights(
        now: Date,
        place: LocatedPlace,
        settings: UserSettings
    ) -> [NightIntervals] {
        func night(for date: Date) -> NightIntervals? {
            try? provider.nightIntervals(
                for: date,
                coordinates: place.coordinates,
                timeZone: place.timeZone,
                calculationMethod: settings.calculationMethod,
                madhab: settings.madhab,
                highLatitudeRule: settings.highLatitudeRule
            )
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = place.timeZone
        var nights: [NightIntervals] = []
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           let previous = night(for: yesterday),
           previous.contains(now) {
            nights.append(previous)
        }
        if let today = night(for: now) {
            nights.append(today)
        }
        if let tomorrowDate = calendar.date(byAdding: .day, value: 1, to: now),
           let tomorrow = night(for: tomorrowDate) {
            nights.append(tomorrow)
        }
        return nights
    }

    /// Routes the plan to whichever channel the user's permissions allow,
    /// and withdraws any wake standing on the other channel so exactly
    /// one — or none — exists.
    private func sync(plan: NightWakePlan?) async {
        #if canImport(AlarmKit)
        let alarmAuthorized = AlarmManager.shared.authorizationState == .authorized
        usesNotificationFallback = !alarmAuthorized
        if alarmAuthorized {
            await notificationCoordinator.sync(to: nil)
            await alarmCoordinator.sync(to: plan)
        } else {
            await alarmCoordinator.sync(to: nil)
            await notificationCoordinator.sync(to: plan)
        }
        #else
        usesNotificationFallback = true
        await notificationCoordinator.sync(to: plan)
        #endif
    }
}

// MARK: - AlarmKit client

#if canImport(AlarmKit)
/// A true user-scheduled alarm at the wake instant — the route that can
/// actually wake someone. One stable identifier, so there is never more
/// than one standing wake.
struct AlarmKitWakeClient: NightWakeScheduling {
    static let alarmID = UUID(uuidString: "5A1A7E00-1A57-4213-9A0D-000000000001")!

    struct Metadata: AlarmMetadata {}

    func scheduleWake(at date: Date) async throws {
        let attributes = AlarmAttributes<Metadata>(
            presentation: AlarmPresentation(
                alert: AlarmPresentation.Alert(
                    title: "The last third of the night",
                    stopButton: AlarmButton(
                        text: "Rise",
                        textColor: .white,
                        systemImageName: "moon.stars"
                    )
                )
            ),
            tintColor: Color(red: 0.788, green: 0.663, blue: 0.416)
        )
        let configuration = AlarmManager.AlarmConfiguration.alarm(
            schedule: .fixed(date),
            attributes: attributes,
            sound: .named(NightWakeSound.assetName)
        )
        _ = try await AlarmManager.shared.schedule(id: Self.alarmID, configuration: configuration)
    }

    func cancelWake() async {
        try? AlarmManager.shared.cancel(id: Self.alarmID)
    }
}
#endif

// MARK: - Notification fallback

/// Where alarms are unavailable or declined: a time-sensitive
/// notification with the same soft tone. Identifier sits outside the
/// `ihsan.prayer.` prefix so schedule rebuilds never sweep it away.
struct NotificationWakeClient: NightWakeScheduling {
    static let identifier = "ihsan.nightwake"

    func scheduleWake(at date: Date) async throws {
        let content = UNMutableNotificationContent()
        content.title = "The last third of the night"
        content.body = "The night's quietest hour has begun."
        content.interruptionLevel = .timeSensitive
        content.sound = UNNotificationSound(
            named: UNNotificationSoundName(NightWakeSound.assetName)
        )

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
        let request = UNNotificationRequest(
            identifier: Self.identifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
        try await UNUserNotificationCenter.current().add(request)
    }

    func cancelWake() async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [Self.identifier]
        )
    }
}
